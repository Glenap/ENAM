"""Materiality scoring.

A filing gets 0-100 from four weighted inputs, and the response carries the
contribution of each one. That is the whole design intent: a user must be able
to see *why* a filing outranked another, line by line, rather than trusting a
single opaque number.

Reconstructed from docs/HANDOVER.md ("materiality 0-100, four weighted inputs,
explainable").
"""

from __future__ import annotations

from typing import Any

from . import config


def score(
    *,
    category: str,
    in_portfolio: bool,
    size_ratio: float = 1.0,
    reaction_pct: float | None = None,
) -> tuple[float, list[dict[str, Any]]]:
    """Return (materiality, contributions).

    size_ratio is how large the disclosure is relative to the company, 0..1.
    reaction_pct is the absolute day move on the filing date, or None when the
    snapshot has no bar for that day. A missing reaction contributes zero and
    says so, rather than being silently imputed.
    """
    w = config.MATERIALITY_WEIGHTS

    cat_component = config.CATEGORY_WEIGHT.get(category, 0.34)
    hold_component = 1.0 if in_portfolio else 0.62

    # A 5% move saturates the reaction input; below that it scales linearly.
    if reaction_pct is None:
        react_component = 0.0
        react_label = "No price bar in the snapshot for that date"
    else:
        react_component = min(abs(reaction_pct) / 5.0, 1.0)
        react_label = f"Price moved {reaction_pct:+.2f}% on the day"

    parts = [
        (
            "category",
            f"{category.replace('_', ' ').capitalize()} filing",
            cat_component,
            w["category"],
        ),
        (
            "holding",
            "You hold it" if in_portfolio else "Not held, covered for research",
            hold_component,
            w["holding"],
        ),
        ("size", "Size of the disclosure relative to the company", size_ratio, w["size"]),
        ("reaction", react_label, react_component, w["reaction"]),
    ]

    total = 0.0
    why: list[dict[str, Any]] = []
    for _key, label, comp, weight in parts:
        pts = round(100 * weight * comp, 1)
        total += pts
        why.append(
            {
                "label": label,
                "points": pts,
                "weight": weight,
                "component": round(comp, 3),
            }
        )

    return round(total, 1), why


def tier_for(materiality: float) -> str:
    if materiality >= config.TIERS["needs_you"]:
        return "needs_you"
    if materiality >= config.TIERS["worth_a_glance"]:
        return "worth_a_glance"
    return "filed_away"
