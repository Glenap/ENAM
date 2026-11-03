"""Configuration for the FINN backend.

Everything here is a constant that either a route or the seeding pipeline
needs. Keeping the portfolio definition in one place is deliberate: the
materiality model and the briefing both score against it, so a portfolio
change must not be able to mean two different things in two modules.

Reconstructed from docs/HANDOVER.md. The original backend was not present in
the project archive; this module preserves the documented behaviour and data
contract, and is explicit where it cannot reproduce the original.
"""

from __future__ import annotations

import os
from pathlib import Path

# --------------------------------------------------------------------- paths

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = Path(os.environ.get("FINN_DATA_DIR", BASE_DIR / "data"))
DOCS_DIR = DATA_DIR / "docs"
DB_PATH = Path(os.environ.get("FINN_DB", DATA_DIR / "finn.db"))

CORS_ORIGINS = [
    o.strip()
    for o in os.environ.get(
        "FINN_CORS_ORIGINS",
        "http://localhost:5060,http://localhost:8080,http://localhost:3000,"
        "https://magnificent-licorice-fb28bb.netlify.app",
    ).split(",")
    if o.strip()
]

# Any *.netlify.app preview URL should also be allowed; Netlify mints a new
# subdomain per deploy preview, so an exact-match list is not enough.
CORS_ORIGIN_REGEX = os.environ.get(
    "FINN_CORS_ORIGIN_REGEX", r"https://.*\.netlify\.app"
)

# ----------------------------------------------------------------- portfolio

# 18 portfolio holdings. ticker -> (display name, sector)
PORTFOLIO: dict[str, tuple[str, str]] = {
    "TCS": ("Tata Consultancy Services", "IT services"),
    "INFY": ("Infosys", "IT services"),
    "HDFCBANK": ("HDFC Bank", "Private bank"),
    "RELIANCE": ("Reliance Industries", "Conglomerate"),
    "POLYCAB": ("Polycab India", "Electricals"),
    "DIXON": ("Dixon Technologies", "Electronics mfg"),
    "APOLLOHOSP": ("Apollo Hospitals", "Healthcare"),
    "MARUTI": ("Maruti Suzuki", "Autos"),
    "HCLTECH": ("HCL Technologies", "IT services"),
    "ICICIBANK": ("ICICI Bank", "Private bank"),
    "LT": ("Larsen & Toubro", "Capital goods"),
    "ASIANPAINT": ("Asian Paints", "Paints"),
    "TITAN": ("Titan Company", "Consumer"),
    "SUNPHARMA": ("Sun Pharmaceutical", "Pharma"),
    "BAJFINANCE": ("Bajaj Finance", "NBFC"),
    "ULTRACEMCO": ("UltraTech Cement", "Cement"),
    "NESTLEIND": ("Nestle India", "FMCG"),
    "POWERGRID": ("Power Grid Corp", "Utilities"),
}

# Four names covered for research but not held.
RESEARCH_ONLY: dict[str, tuple[str, str]] = {
    "SBIN": ("State Bank of India", "Public sector bank"),
    "WIPRO": ("Wipro", "IT services"),
    "DRREDDY": ("Dr. Reddy's Laboratories", "Pharma"),
    "TATAMOTORS": ("Tata Motors", "Autos"),
}

ALL_COMPANIES: dict[str, tuple[str, str]] = {**PORTFOLIO, **RESEARCH_ONLY}

# Banks do not report an EBITDA line. The extractor detects the
# financing-Profit layout and says so rather than printing a meaningless number.
BANK_TICKERS = {"HDFCBANK", "ICICIBANK", "SBIN"}

# ------------------------------------------------------------ materiality

# Four weighted inputs that sum to 1.0. The score is explainable line by line,
# which is the point: a user can interrogate every contribution.
MATERIALITY_WEIGHTS: dict[str, float] = {
    "category": 0.35,
    "holding": 0.25,
    "size": 0.22,
    "reaction": 0.18,
}

# Category weight in [0, 1], multiplied into the category component.
CATEGORY_WEIGHT: dict[str, float] = {
    "results": 1.00,
    "management_change": 0.87,
    "order": 0.72,
    "disclosure": 0.34,
}

TIERS: dict[str, float] = {
    "needs_you": 70.0,
    "worth_a_glance": 40.0,
}

# ---------------------------------------------------------------- snapshot

# The snapshot is frozen on purpose: a blocked exchange or a rate limit must
# not be able to break a demo. Nothing is generated on the fly.
SNAPSHOT_ASOF = "31 Oct 2026"
SNAPSHOT_FRESHNESS = (
    "Snapshot built from the frozen store. No live fetch at request time."
)

BRIEFING_WINDOWS = [24, 72, 168, 720]  # 24h, 3d, 7d, 30d

# ------------------------------------------------------------------ requests

HTTP_TIMEOUT = 20.0
HTTP_RETRIES = 3
HTTP_BACKOFF = 0.6
USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
)

# NSE is network-blocked from the build host and BSE's JSON API answers 403
# behind Akamai. Announcements therefore come from the screener mirror, which
# serves the real BSE filings, dates and PDFs behind an adapter.
SCREENER_BASE = "https://www.screener.in"
YAHOO_CHART = "https://query1.finance.yahoo.com/v8/finance/chart/{ticker}"

# ---------------------------------------------------------------------- LLM

# One provider interface, three backends. The pipeline ships on the
# deterministic tier because the hosted proxy has no credits here and the local
# 1.5B model hallucinated a margin target that appears nowhere in a transcript.
LLM_TIER = os.environ.get("FINN_LLM_TIER", "deterministic")  # deterministic|local|hosted
LLM_CACHE_ENABLED = True
