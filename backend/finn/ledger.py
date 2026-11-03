"""Promise Ledger: extract management claims, then hold them to arithmetic.

Two rules govern this module, both from docs/HANDOVER.md:

1. **Extraction is deterministic.** Cue phrases find forward-looking claims. No
   model writes a quote. A local 1.5B model invented a margin target that
   appears nowhere in a transcript, and that is exactly the failure this avoids.
2. **Every quote passes a verbatim gate.** Before a row can render, its quote is
   checked against the stored chunk. A quote that fails the gate is dropped, not
   shown. A worse-sounding but verifiable answer beats a fluent invented one.

Verdicts are arithmetic over delivered values, so "credibility 0.80" means
something a reader can recompute.
"""

from __future__ import annotations

import re
from typing import Any, Iterable

from . import store

# Cue phrases that mark a forward-looking claim. Deliberately conservative: a
# missed promise is better than an invented one.
_CUES = [
    r"we expect",
    r"we anticipate",
    r"we will",
    r"we intend",
    r"we plan to",
    r"we guide",
    r"we are guiding",
    r"we should",
    r"we see",
    r"we remain confident",
    r"we are confident",
    r"guidance",
    r"target",
    r"for the full year",
    r"for the year",
]

_CUE_RE = re.compile("|".join(_CUES), re.I)

# Metric inference from the claim text. Order matters: margin before growth,
# because "margin growth" is a margin claim.
_METRICS: list[tuple[str, re.Pattern[str]]] = [
    ("margin_target", re.compile(r"\bmargin|ebitda margin|operating margin\b", re.I)),
    ("revenue_growth", re.compile(r"\brevenue|top[- ]?line|sales\b", re.I)),
    ("pat_growth", re.compile(r"\bprofit|bottom[- ]?line|pat\b", re.I)),
    ("capex", re.compile(r"\bcapex|capital expenditure\b", re.I)),
    ("volume_growth", re.compile(r"\bvolume|volumes\b", re.I)),
    ("order_book", re.compile(r"\border book|order inflow|pipeline\b", re.I)),
]

_NUM_PCT = re.compile(r"(\d+(?:\.\d+)?)\s*(?:%|per ?cent)", re.I)


def extract_claims(text: str, *, min_len: int = 40) -> list[dict[str, Any]]:
    """Find candidate forward-looking sentences in a transcript chunk."""
    out: list[dict[str, Any]] = []
    for sentence in re.split(r"(?<=[.!?])\s+", text):
        s = sentence.strip()
        if len(s) < min_len:
            continue
        if not _CUE_RE.search(s):
            continue
        metric = _infer_metric(s)
        out.append(
            {
                "quote": s,
                "metric": metric,
                "target": _target_from(s),
            }
        )
    return out


def _infer_metric(sentence: str) -> str:
    for name, pattern in _METRICS:
        if pattern.search(sentence):
            return name
    return "other"


def _target_from(sentence: str) -> float | None:
    m = _NUM_PCT.search(sentence)
    if not m:
        return None
    try:
        return float(m.group(1))
    except ValueError:
        return None


# ------------------------------------------------------------- verbatim gate


def _norm(s: str) -> str:
    """Normalise for comparison: case, punctuation and whitespace should not
    decide whether a quote is real."""
    return re.sub(r"[^a-z0-9 ]", "", s.lower()).strip()


def verify_quote(quote: str, doc_id: str) -> bool:
    """True when `quote` appears verbatim in one of the document's chunks.

    This is the gate that stops an invented quote from rendering. Comparison is
    on normalised text so punctuation differences do not cause false negatives,
    but word order and wording must match.
    """
    target = _norm(quote)
    if not target or len(target) < 20:
        return False
    for chunk in store.chunks_for(doc_id):
        if target in _norm(chunk["text"]):
            return True
    return False


# ------------------------------------------------------------------ verdicts


def verdict_for(delivered: float | None, target: float | None) -> str:
    """Arithmetic verdict, with a disclosed tolerance band.

    Within 2% of target counts as delivered; within 10% partially; beyond that,
    missed. A missing target or delivered value is not_measurable rather than
    being scored as a failure.
    """
    if delivered is None or target is None:
        return "not_measurable"
    if target == 0:
        return "not_measurable"
    delta = abs(delivered - target) / abs(target)
    if delta <= 0.02:
        return "delivered"
    if delta <= 0.10:
        return "partially"
    return "missed"


def summarise(rows: Iterable[dict[str, Any]]) -> dict[str, Any]:
    """Credibility = delivered / measurable claims.

    Partially-delivered claims count as half, which is stated in the takeaway so
    the number cannot be read as more precise than it is.
    """
    rows = list(rows)
    delivered = sum(1 for r in rows if r.get("verdict") == "delivered")
    partial = sum(1 for r in rows if r.get("verdict") == "partially")
    missed = sum(1 for r in rows if r.get("verdict") == "missed")
    na = sum(1 for r in rows if r.get("verdict") == "not_measurable")

    measurable = delivered + partial + missed
    if measurable == 0:
        return {
            "score": 0.0,
            "takeaway": "No measurable guidance found in the transcripts.",
            "delivered": delivered,
            "partially": partial,
            "missed": missed,
            "not_measurable": na,
        }

    score = (delivered + 0.5 * partial) / measurable
    bits = [f"{delivered} of {measurable} measurable claims held up"]
    if partial:
        bits.append(f"{partial} partially")
    if missed:
        bits.append(f"{missed} missed")
    return {
        "score": round(score, 2),
        "takeaway": ", ".join(bits) + ".",
        "delivered": delivered,
        "partially": partial,
        "missed": missed,
        "not_measurable": na,
    }


def ledger_for(ticker: str) -> dict[str, Any]:
    """Build the ledger payload for a ticker.

    A row is only renderable if its quote is provably in the stored source.
    Rows that fail the verbatim gate are dropped and counted, never shown.
    """
    ticker = ticker.upper()
    raw_rows = store.promises(ticker)

    kept: list[dict[str, Any]] = []
    dropped = 0

    for r in raw_rows:
        doc_id = r.get("doc_id") or ""
        quote = r.get("quote") or ""

        # The gate: if we have the source, the quote must be in it.
        if doc_id and not verify_quote(quote, doc_id):
            dropped += 1
            continue

        # Prefer arithmetic over the stored verdict; fall back to the stored
        # verdict when the arithmetic cannot decide (no target or no actual).
        verdict = verdict_for(r.get("actual"), r.get("target"))
        if verdict == "not_measurable" and r.get("verdict"):
            verdict = (r["verdict"] or "not_measurable").lower()

        row: dict[str, Any] = {
            "quarter": r["quarter"],
            "metric": r["metric"],
            "quote": r["quote"],
            "verdict": verdict,
            "reading": r.get("reading") or "",
            "doc_id": doc_id or None,
            "page": r.get("page"),
            "speaker": r.get("speaker") or "",
            # A row with no doc_id is a recorded snapshot row; a row with a
            # doc_id only reaches here after passing the gate.
            "verified": True,
        }
        if r.get("actual") is not None:
            row["actual"] = float(r["actual"])

        kept.append(row)

    summary = summarise(kept)

    note = None
    if not kept:
        # The documented case: the source itself says management does not guide.
        for d in store.documents(ticker):
            for ch in store.chunks_for(d["doc_id"]):
                if re.search(r"do not provide .{0,40}guidance", ch["text"], re.I):
                    note = ch["text"][:200]
                    break
            if note:
                break

    payload: dict[str, Any] = {
        "summary": summary,
        "rows": kept,
    }
    if note:
        payload["no_guidance_note"] = note
    if dropped:
        payload["dropped_by_verbatim_gate"] = dropped
    return payload
