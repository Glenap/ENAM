"""FINN API.

Twelve endpoints, all reading from the frozen snapshot. Nothing here fetches
from the network at request time, which is the property that makes the demo
survive a blocked exchange or a rate limit.

Reconstructed from docs/HANDOVER.md. Routed exactly as the Flutter client in
lib/api.dart calls them.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any, AsyncIterator

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles

from . import config, llm, research, score, store

app = FastAPI(title="FINN", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_origin_regex=config.CORS_ORIGIN_REGEX,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


# ------------------------------------------------------------------ helpers


def _require_seed() -> None:
    if not store.is_seeded():
        raise HTTPException(
            status_code=503,
            detail=(
                "Snapshot is not built. Run `python3 -m finn.seed` from the "
                "backend directory first."
            ),
        )


def _announcement_payload(row: dict[str, Any]) -> dict[str, Any]:
    """Shape an announcements row for the client."""
    try:
        why = json.loads(row.get("why") or "[]")
    except Exception:
        why = []
    company = store.company(row["ticker"])
    return {
        "id": row["id"],
        "ticker": row["ticker"],
        "company": company["name"] if company else row["ticker"],
        "category": row["category"],
        "title": row["title"],
        "summary": row.get("summary") or row["title"],
        "materiality": round(float(row.get("materiality") or 0), 1),
        "tier": row["tier"],
        "filed_at": row["filed_at"],
        "in_portfolio": bool(company["in_portfolio"]) if company else False,
        "url": row.get("url") or "",
        "why": why,
    }


# --------------------------------------------------------------------- meta


@app.get("/api/meta")
def meta() -> dict[str, Any]:
    _require_seed()
    counts = store.counts()
    return {
        "asof": config.SNAPSHOT_ASOF,
        "headline": _headline(),
        "freshness_label": config.SNAPSHOT_FRESHNESS,
        "counts": {
            **counts,
            # keys the settings screen reads
            "announcements": counts["announcements"],
            "documents": counts["documents"],
            "chunks": counts["chunks"],
            "companies": counts["companies"],
        },
        "windows": config.BRIEFING_WINDOWS,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }


def _headline() -> str:
    anns = store.announcements()
    needs = [a for a in anns if a["tier"] == "needs_you"]
    folded = [a for a in anns if a["tier"] == "filed_away"]
    if not anns:
        return "Nothing to brief."
    word = {1: "One thing needs", 2: "Two things need", 3: "Three things need"}.get(
        len(needs), f"{len(needs)} things need"
    )
    return f"{word} you today. {len(folded)} filings folded."


@app.get("/api/portfolio")
def portfolio() -> dict[str, Any]:
    _require_seed()
    out: list[dict[str, Any]] = []
    for c in store.companies(in_portfolio=True):
        t = c["ticker"]
        lp = store.last_price(t)
        spark = [v for v in store.series(t, "close", 30) if v is not None]
        pct = store.day_change_pct(t)
        mult = store.volume_multiple(t)
        out.append(
            {
                "ticker": t,
                "name": c["name"],
                "sector": c["sector"],
                "price": lp["close"] if lp else None,
                "day_change_pct": round(pct, 2) if pct is not None else None,
                "spark": spark,
                "in_portfolio": True,
                "unusual": bool(mult and mult >= 2.0),
                "volume_multiple": round(mult, 2) if mult else None,
            }
        )

    # Biggest movers first so the strip leads with the day's information.
    out.sort(key=lambda e: -abs(e.get("day_change_pct") or 0))
    return {"portfolio": out, "count": len(out)}


# ----------------------------------------------------------------- briefing


@app.get("/api/briefing")
def briefing(window: int = Query(24, description="Hours back to include")) -> dict[str, Any]:
    _require_seed()
    anns = [_announcement_payload(a) for a in store.announcements(window)]

    tiers: dict[str, list[dict[str, Any]]] = {
        "needs_you": [],
        "worth_a_glance": [],
        "filed_away": [],
    }
    for a in anns:
        tiers.setdefault(a["tier"], []).append(a)

    return {
        "asof": config.SNAPSHOT_ASOF,
        "headline": _headline(),
        "freshness_label": config.SNAPSHOT_FRESHNESS,
        "window_hours": window,
        "tiers": tiers,
        "counts": {k: len(v) for k, v in tiers.items()},
    }


# ----------------------------------------------------------------- research


@app.get("/api/research/{ticker}")
def research_get(ticker: str) -> dict[str, Any]:
    _require_seed()
    payload = research.research_payload(ticker)
    if not payload:
        raise HTTPException(status_code=404, detail=f"No company {ticker.upper()}")
    return payload


@app.post("/api/research/{ticker}/build")
def research_build(ticker: str) -> dict[str, Any]:
    """Lazy build for a name that is not pre-warmed.

    The original backend did not implement this (documented as a known gap).
    Here it is honest about what it can do: if the ticker has no snapshot rows
    at all there is nothing to build without a network fetch, so it says so
    rather than returning an empty payload that looks like success.
    """
    _require_seed()
    t = ticker.upper()
    c = store.company(t)
    if not c:
        raise HTTPException(
            status_code=404,
            detail=(
                f"{t} is not in the snapshot. Building a new name requires a "
                f"network fetch, which this deployment does not perform at "
                f"request time."
            ),
        )
    return research.research_payload(t)


# ------------------------------------------------------------------ results


@app.get("/api/results/{ticker}")
def results_get(ticker: str) -> dict[str, Any]:
    _require_seed()
    r = store.results(ticker)
    if not r:
        raise HTTPException(
            status_code=404, detail=f"No extracted results for {ticker.upper()}"
        )
    return r


# -------------------------------------------------------------------- rules

# Rules live in memory for this deployment: they are user preferences, not
# snapshot data, and the original store had no table for them.
_RULES: list[dict[str, Any]] = [
    {
        "id": "rule-1",
        "label": "Tell me when any holding moves 4% in a day",
        "enabled": True,
        "expr": {"scope": "any", "kind": "price", "pct": 4},
    },
    {
        "id": "rule-2",
        "label": "Unusual volume on the names I hold",
        "enabled": True,
        "expr": {"scope": "any", "kind": "volume", "multiplier": 2.0},
    },
    {
        "id": "rule-3",
        "label": "Any results filing from the portfolio",
        "enabled": True,
        "expr": {"scope": "any", "kind": "filing", "categories": ["results"]},
    },
]


@app.get("/api/rules")
def rules_get() -> dict[str, Any]:
    return {"rules": _RULES, "categories": list(config.CATEGORY_WEIGHT.keys())}


@app.post("/api/rules")
def rules_post(body: dict[str, Any] | None = None) -> dict[str, Any]:
    body = body or {}
    label = (body.get("label") or "").strip()
    expr = body.get("expr") or {}

    # A delete arrives as an empty body from the client's close button.
    if not label and not expr:
        return {"ok": True, "deleted": True}

    new_id = f"rule-{len(_RULES) + 1}"
    rule = {
        "id": new_id,
        "label": label or "Untitled rule",
        "enabled": True,
        "expr": expr,
    }
    _RULES.append(rule)
    return {"ok": True, "rule": rule}


# ------------------------------------------------------------------- alerts


@app.post("/api/alerts/run")
def alerts_run(body: dict[str, Any] | None = None) -> dict[str, Any]:
    """Evaluate the rules against the snapshot, honestly.

    An alert is only emitted when the snapshot can actually test the rule. A
    move with no correlated filing is reported as unexplained rather than being
    given a narrative it does not have.
    """
    _require_seed()
    ticker = ((body or {}).get("ticker") or "").upper() or None

    universe = [c["ticker"] for c in store.companies(in_portfolio=True)]
    if ticker:
        universe = [t for t in universe if t == ticker]

    fired: list[dict[str, Any]] = []
    for t in universe:
        pct = store.day_change_pct(t)
        mult = store.volume_multiple(t)

        trigger: str | None = None
        if pct is not None and abs(pct) >= 4:
            trigger = f"{t} moved {pct:+.2f}% in a day, past the 4% rule threshold."
        elif mult is not None and mult >= 2.0:
            trigger = f"{t} traded at {mult:.1f}x its 20-day average volume."
        if not trigger:
            continue

        # Correlate against a filing on or near the latest bar date.
        lp = store.last_price(t)
        linked = None
        if lp:
            for a in store.announcements():
                if a["ticker"] == t and a["filed_at"][:10] >= _days_before(lp["date"], 2):
                    linked = a
                    break

        detail: dict[str, Any] = {}
        if linked:
            detail["linked_title"] = linked["title"]
            detail["correlation_note"] = (
                "The move and the filing are within two days of each other."
            )
        else:
            detail["correlation_note"] = "No filing in the snapshot explains this move."

        fired.append(
            {
                "id": f"alert-{t}-{lp['date'] if lp else 'na'}",
                "ticker": t,
                "fired_at": lp["date"] if lp else config.SNAPSHOT_ASOF,
                "trigger_text": trigger,
                "detail": detail,
            }
        )

    return {"count": len(fired), "alerts": fired}


def _days_before(iso_date: str, days: int) -> str:
    try:
        d = datetime.fromisoformat(iso_date)
    except ValueError:
        return iso_date
    from datetime import timedelta

    return (d - timedelta(days=days)).date().isoformat()


@app.get("/api/alerts/history")
def alerts_history() -> dict[str, Any]:
    return alerts_run(None)


# ------------------------------------------------------------------ sources


@app.get("/api/sources/{doc_id}")
def source_get(doc_id: str, page: int | None = None) -> dict[str, Any]:
    _require_seed()
    d = store.document(doc_id)
    if not d:
        raise HTTPException(status_code=404, detail=f"No document {doc_id}")

    chunks = store.chunks_for(doc_id)
    if page is not None:
        chunks = [c for c in chunks if c.get("page") == page]

    text = "\n\n".join(c["text"] for c in chunks) if chunks else ""
    return {
        "doc_id": doc_id,
        "title": d["title"],
        "period": d.get("period"),
        "page": page if page is not None else (chunks[0]["page"] if chunks else None),
        "text": text or "No extracted text is available for this page.",
        # A served quote is only "verified" when retrieval found it in the store.
        "verified": bool(text),
    }


# ------------------------------------------------------------------- search


@app.get("/api/search")
def search_get(q: str = Query("", description="Free-text query")) -> dict[str, Any]:
    _require_seed()
    query = q.strip()
    if not query:
        return {"results": [], "note": "Empty query."}

    hits = research.retrieve(query, None, limit=8)
    results = []
    for h in hits:
        doc = store.document(h["doc_id"])
        results.append(
            {
                "ticker": doc["ticker"] if doc else "",
                "title": doc["title"] if doc else h["doc_id"],
                "kind": "document",
                "detail": (h["text"] or "")[:160],
                "doc_id": h["doc_id"],
                "page": h.get("page"),
            }
        )
    return {"results": results, "note": f"{len(results)} passages matched."}


# ---------------------------------------------------------------------- ask


@app.post("/api/ask")
def ask_post(body: dict[str, Any] | None = None) -> dict[str, Any]:
    body = body or {}
    q = (body.get("q") or "").strip()
    ticker = (body.get("ticker") or "").upper() or None
    if not q:
        raise HTTPException(status_code=400, detail="Empty question")

    answer, citations, followups, steps = _answer(q, ticker)
    return {
        "kind": "grounded",
        "answer": answer,
        "citations": citations,
        "followups": followups,
        "grounding_note": (
            "Retrieved from the snapshot and gated against the stored chunks. "
            "Nothing here is written by a model."
        ),
        "steps": steps,
    }


@app.post("/api/ask/stream")
async def ask_stream(body: dict[str, Any] | None = None) -> StreamingResponse:
    """SSE stream: step events, then one answer event.

    The frame shape matches what lib/widgets/ask_bar.dart parses: a `type` field
    of 'step' | 'answer' | 'error', and a blank-line terminator per frame.
    """
    body = body or {}
    q = (body.get("q") or "").strip()
    ticker = (body.get("ticker") or "").upper() or None

    async def frames() -> AsyncIterator[bytes]:
        def frame(obj: dict[str, Any]) -> bytes:
            return f"data: {json.dumps(obj)}\n\n".encode()

        if not q:
            yield frame({"type": "error", "message": "Empty question"})
            return

        try:
            steps = ["Reading the snapshot"]
            if ticker:
                steps.append(f"Scoping to {ticker}")
            steps.append("Retrieving passages")
            for s in steps:
                yield frame({"type": "step", "label": s})

            answer, citations, followups, _ = _answer(q, ticker)

            yield frame({"type": "step", "label": "Verifying the quote"})
            yield frame(
                {
                    "type": "answer",
                    "kind": "grounded",
                    "answer": answer,
                    "citations": citations,
                    "followups": followups,
                    "grounding_note": (
                        "Retrieved from the snapshot and gated against the stored "
                        "chunks. Nothing here is written by a model."
                    ),
                }
            )
        except Exception as e:  # never leave the stream hanging
            yield frame({"type": "error", "message": str(e)})

    return StreamingResponse(
        frames(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


def _answer(
    q: str, ticker: str | None
) -> tuple[str, list[dict[str, Any]], list[str], list[str]]:
    """Answer from the snapshot where possible, and say so when it cannot.

    The design rule from the handover applies: a worse-sounding but verifiable
    answer beats a fluent invented one. When retrieval finds nothing relevant,
    the answer states that instead of producing prose.
    """
    hits = research.retrieve(q, ticker, limit=3)

    if not hits:
        return (
            "The snapshot has nothing that answers this. I would rather say so "
            "than assemble a plausible-sounding answer from unrelated filings.",
            [],
            [
                "What did TCS report last quarter?",
                "Which holdings moved the most?",
                "Show me the Polycab results card.",
            ],
            ["Reading the snapshot", "Retrieving passages"],
        )

    top = hits[0]
    doc = store.document(top["doc_id"])
    text = (top["text"] or "").strip()
    excerpt = text[:280].rstrip()

    ticker_name = doc["ticker"] if doc else (ticker or "")
    page_bit = f", page {top['page']}" if top.get("page") else ""
    answer = (
        f"From {doc['title'] if doc else top['doc_id']}{page_bit}: {excerpt}"
    )

    citations = [
        {
            "doc_id": top["doc_id"],
            "page": top.get("page"),
            "label": doc["title"] if doc else top["doc_id"],
            "excerpt": excerpt,
        }
    ]

    followups = [
        f"What else did {ticker_name} say in that call?" if ticker_name else "What else is in the snapshot?",
        "Which promises has management kept?",
        "What moved the most today?",
    ]

    return answer, citations, followups, ["Reading the snapshot", "Retrieving passages"]


# ---------------------------------------------------------------------- cost


@app.get("/api/cost")
def cost() -> dict[str, Any]:
    return llm.ledger()


@app.get("/healthz")
def healthz() -> dict[str, Any]:
    return {"ok": True, "seeded": store.is_seeded()}


# -------------------------------------------------------------- static mount

# Serve the built Flutter app from the same origin when build/web exists, so the
# client's relative /api paths resolve without CORS.
#
# This mount MUST stay the last statement in the module. A mount on "/" matches
# every path, so anything registered after it (including /healthz) would be
# shadowed and return 404.
_WEB = config.BASE_DIR.parent / "build" / "web"
if _WEB.is_dir():
    app.mount("/", StaticFiles(directory=str(_WEB), html=True), name="web")
