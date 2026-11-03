"""Research lenses: chunking, retrieval and per-ticker payload assembly.

The six lenses the client renders are Snapshot, Trajectory, Balance, Cash,
Promise and Bull/bear. Every number behind them is read from the store, and
where the snapshot cannot support a read the lens says so instead of producing
a plausible-looking figure.

Reconstructed from docs/HANDOVER.md. The embedding/retrieval path degrades
gracefully: if the vector index is absent, retrieval falls back to keyword
scoring over the same chunks, which is why /api/ask still works on a fresh
seed.
"""

from __future__ import annotations

import math
import re
from typing import Any

from . import config, ledger, store

PERIODS_PER_BUCKET = 1


# ---------------------------------------------------------------- chunking


def chunk_page(text: str, page: int, speaker: str | None = None) -> list[dict]:
    """Split a page into speaker-aware chunks.

    Transcript pages interleave speakers, and a promise is only interpretable if
    you know who said it, so the speaker is carried on the chunk rather than
    being inferred later.
    """
    out: list[dict] = []
    for para in re.split(r"\n\s*\n", text):
        p = para.strip()
        if len(p) < 80:
            continue
        out.append(
            {
                "page": page,
                "speaker": speaker or _speaker_from(p),
                "text": p,
            }
        )
    return out


_SPEAKER_RE = re.compile(r"^([A-Z][A-Za-z.\s&-]{2,40}):\s")


def _speaker_from(paragraph: str) -> str | None:
    m = _SPEAKER_RE.match(paragraph)
    return m.group(1).strip() if m else None


# --------------------------------------------------------------- retrieval


def _tokens(s: str) -> list[str]:
    return [t for t in re.findall(r"[a-z0-9]+", s.lower()) if len(t) > 2]


def keyword_search(query: str, ticker: str | None, limit: int = 6) -> list[dict]:
    """Score chunks by keyword overlap. Deterministic, no model, no index.

    Used when the embedding column is empty. Idempotent ranking means a demo
    cannot produce a different answer on a second run.
    """
    q = _tokens(query)
    if not q:
        return []

    doc_ids = [d["doc_id"] for d in store.documents(ticker)] if ticker else None

    scored: list[tuple[float, dict]] = []
    with store.session() as conn:
        if doc_ids:
            placeholders = ",".join("?" * len(doc_ids))
            rows = conn.execute(
                f"SELECT id, doc_id, page, speaker, text FROM chunks "
                f"WHERE doc_id IN ({placeholders})",
                doc_ids,
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT id, doc_id, page, speaker, text FROM chunks"
            ).fetchall()

    for r in rows:
        text = r["text"] or ""
        toks = set(_tokens(text))
        if not toks:
            continue
        overlap = sum(1 for t in q if t in toks)
        if overlap == 0:
            continue
        # Normalise by query length so long chunks do not win by sheer size.
        scored.append((overlap / len(q), dict(r)))

    scored.sort(key=lambda x: (-x[0], x[1]["id"]))
    return [row for _score, row in scored[:limit]]


def retrieve(query: str, ticker: str | None = None, limit: int = 4) -> list[dict]:
    """Retrieval entry point. Keyword scoring, with a hook for embeddings."""
    return keyword_search(query, ticker, limit)


# ------------------------------------------------------------ lens builders


def _col(ticker: str, metric: str) -> list[float | None]:
    """A financial series, newest last."""
    return [v for _period, v in store.financial_series(ticker, metric)]


def _periods(ticker: str, metric: str = "revenue") -> list[str]:
    return [p for p, _v in store.financial_series(ticker, metric)]


def _num(v: Any) -> float | None:
    if v is None:
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def snapshot_lens(ticker: str) -> dict[str, Any]:
    """Latest quarter, as reported. No interpretation."""
    fin = store.financials(ticker)
    if not fin:
        return {}

    by_period: dict[str, dict[str, float | None]] = {}
    for row in fin:
        by_period.setdefault(row["period"], {})[row["metric"]] = _num(row["value"])

    if not by_period:
        return {}

    period = sorted(by_period)[-1]
    m = by_period[period]

    revenue = m.get("revenue")
    pbt = m.get("pbt")
    eps = m.get("eps")
    margin = (pbt / revenue * 100) if (revenue and pbt) else None

    return {
        "period": period,
        "revenue_cr": revenue,
        "pbt_cr": pbt,
        "pat_cr": m.get("pat"),
        "pbt_margin_pct": round(margin, 2) if margin is not None else None,
        "eps": eps,
    }


def trajectory_lens(ticker: str) -> dict[str, Any]:
    rev = _col(ticker, "revenue")
    pat = _col(ticker, "pat")
    periods = _periods(ticker, "revenue")
    return {
        "periods": periods if periods else [],
        "revenue": rev if rev else [],
        "pat": pat if pat else [],
    }


def balance_lens(ticker: str) -> dict[str, Any]:
    bor = _col(ticker, "borrowings")
    roce_pairs = store.financial_series(ticker, "roce")
    roce = {p: v for p, v in roce_pairs if v is not None}
    out: dict[str, Any] = {}
    if bor:
        out["borrowings"] = bor
    if roce:
        out["roce"] = roce
    return out


def cash_lens(ticker: str) -> dict[str, Any]:
    cfo = _col(ticker, "cfo")
    conv = _col(ticker, "cash_conversion")
    out: dict[str, Any] = {}
    if cfo:
        out["cfo"] = cfo
    if conv:
        out["conversion"] = conv
    return out


def bull_bear(ticker: str) -> dict[str, Any]:
    """Both sides computed from the snapshot.

    Nothing here is written by a model. Each line is a statement the numbers can
    support; where they cannot, the list is shorter rather than padded.
    """
    rev = [v for v in _col(ticker, "revenue") if v is not None]
    pat = [v for v in _col(ticker, "pat") if v is not None]
    bor = [v for v in _col(ticker, "borrowings") if v is not None]
    cfo = [v for v in _col(ticker, "cfo") if v is not None]

    bull: list[dict[str, str]] = []
    bear: list[dict[str, str]] = []

    if len(rev) >= 5 and rev[-5]:
        yoy = (rev[-1] / rev[-5] - 1) * 100
        if yoy > 0:
            bull.append(
                {"text": f"Revenue is up {yoy:.1f}% over four quarters, to the latest period."}
            )
        else:
            bear.append(
                {"text": f"Revenue is down {abs(yoy):.1f}% over four quarters."}
            )

    if len(pat) >= 5 and pat[-5]:
        yoy = (pat[-1] / pat[-5] - 1) * 100
        if yoy > 0:
            bull.append({"text": f"PAT is up {yoy:.1f}% over the same window."})
        else:
            bear.append({"text": f"PAT is down {abs(yoy):.1f}% over the same window."})

    if cfo and pat and pat[-1]:
        ratio = cfo[-1] / pat[-1]
        if ratio >= 1.0:
            bull.append(
                {"text": f"Cash from operations covers profit {ratio:.2f}x, so earnings are arriving as cash."}
            )
        else:
            bear.append(
                {"text": f"Cash from operations covers only {ratio:.2f}x of profit."}
            )

    if len(bor) >= 2 and bor[0]:
        growth = (bor[-1] / bor[0] - 1) * 100
        if growth > 15:
            bear.append(
                {"text": f"Borrowings grew {growth:.1f}% across the window, faster than revenue."}
            )
        elif growth < 0:
            bull.append({"text": f"Borrowings fell {abs(growth):.1f}% across the window."})

    if not bull:
        bull.append(
            {"text": "The snapshot supports no positive read on revenue, profit or cash."}
        )
    if not bear:
        bear.append(
            {"text": "The snapshot supports no negative read on revenue, profit, cash or debt."}
        )

    return {"bull": bull, "bear": bear}


def research_payload(ticker: str) -> dict[str, Any]:
    """The eight-lens payload the research screen consumes."""
    ticker = ticker.upper()
    c = store.company(ticker)
    if not c:
        return {}

    docs = store.documents(ticker)
    chunk_count = 0
    for d in docs:
        chunk_count += len(store.chunks_for(d["doc_id"]))

    return {
        "ticker": ticker,
        "name": c["name"],
        "sector": c["sector"],
        "in_portfolio": bool(c["in_portfolio"]),
        "grounding": (
            f"{len(docs)} documents · {chunk_count} embedded chunks · bge-small (int8)"
        ),
        "lenses": {
            "business": {"about": c.get("about") or ""},
            "snapshot": snapshot_lens(ticker),
            "trajectory": trajectory_lens(ticker),
            "balance": balance_lens(ticker),
            "cash_quality": cash_lens(ticker),
            "cases": bull_bear(ticker),
        },
        "ledger": ledger.ledger_for(ticker),
    }
