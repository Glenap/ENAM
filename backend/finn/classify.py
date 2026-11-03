"""Filing classification.

Rules first, cached by filing hash. The local model is only an escalation path
for text the rules cannot place, and it is deliberately not trusted for numbers
— the local 1.5B model invented a margin target that appears nowhere in a
Maruti transcript, which is why promise extraction is deterministic plus a
verbatim gate rather than model-generated.

Reconstructed from docs/HANDOVER.md. The original classifier was not in the
project archive.
"""

from __future__ import annotations

import hashlib
import re
from typing import Final

CATEGORIES: Final = ("results", "management_change", "order", "disclosure")

# Ordered: the first matching rule wins, so put the most specific first.
_RULES: Final[list[tuple[str, re.Pattern[str]]]] = [
    (
        "management_change",
        re.compile(
            r"\b(resignation|resign|appoint|appointment|cessation|"
            r"chief financial officer|cfo|managing director|whole[- ]time director|"
            r"company secretary|kmp|key managerial)\b",
            re.I,
        ),
    ),
    (
        "results",
        re.compile(
            r"\b(financial results|unaudited results|audited results|"
            r"quarterly results|half[- ]yearly results|"
            r"statement of (?:standalone|consolidated) |"
            r"profit and loss|earnings)\b",
            re.I,
        ),
    ),
    (
        "order",
        re.compile(
            r"\b(order|orders|contract|award|letter of award|loa|"
            r"work order|purchase order|bagging|new project)\b",
            re.I,
        ),
    ),
]


def hash_filing(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", "ignore")).hexdigest()[:32]


def classify(title: str, body: str = "") -> tuple[str, str]:
    """Return (category, reason). reason says which rule fired."""
    blob = f"{title} {body}"
    for name, pattern in _RULES:
        m = pattern.search(blob)
        if m:
            return name, f"rule:{name} matched '{m.group(0)}'"
    return "disclosure", "rule:default, no specific rule matched"
