# FINN backend

FastAPI service for the FINN snapshot. Reads from a pre-built SQLite database
and never touches the network at request time, so a live front end cannot break
because a data source went down.

**Status: reconstructed.** The original `backend/finn/` was not present in any
project archive. This implementation follows `docs/HANDOVER.md` — the same
module layout, the same route surface, and the same design decisions (rules
before LLM, verbatim gate, deterministic rules over generated numbers). The
recorded figures it seeds from are the ones the handover documents as executed
and observed, notably POLYCAB Q2FY27 (revenue ₹98,989.01 mn, PBT ₹13,062.20 mn,
PAT ₹9,899.97 mn, cross-checked to 0.02%) and the TCS promise ledger at 0.80.

It is not a byte-for-byte recovery of the original code, and does not claim to
be. See "What this does not reproduce" below.

## Quick start

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt

python3 -m finn.seed          # build the snapshot (idempotent, ~10s)
python3 -m uvicorn finn.api:app --host 0.0.0.0 --port 8000
```

Then:

```bash
curl -s localhost:8000/healthz
curl -s localhost:8000/api/meta | head -c 400
curl -s "localhost:8000/api/briefing?window=800" | head -c 400
curl -s localhost:8000/api/research/TCS | head -c 400
```

Interactive docs at `/docs`.

## Layout

```
finn/
  config.py      portfolio, materiality weights, snapshot constants, CORS
  store.py       SQLite schema + typed accessors
  http.py        retry/backoff layer with clean failure
  classify.py    rules-first filing classification, cached by hash
  score.py       materiality 0-100 from four weighted, explainable inputs
  research.py    chunking, retrieval, the six lenses, bull/bear from the data
  ledger.py      claim extraction, verbatim gate, arithmetic verdicts
  llm.py         provider interface + content-hash cache + cost ledger
  seed.py        the snapshot builder
  api.py         FastAPI: meta, portfolio, briefing, results, research,
                 rules, alerts, ask, sources, search, cost
```

## Endpoints

The twelve routes in `lib/api.dart` are all implemented:

| Method | Path | Notes |
|---|---|---|
| GET | `/api/meta` | headline, asof, counts |
| GET | `/api/portfolio` | 18 holdings, sparkline, day %, volume multiple |
| GET | `/api/briefing?window=N` | three tiers, each card carrying its `why` breakdown |
| GET | `/api/research/{ticker}` | six lenses + ledger |
| POST | `/api/research/{ticker}/build` | honest 404 for names not in the snapshot |
| GET | `/api/results/{ticker}` | metrics, QoQ/YoY, verification status |
| GET/POST | `/api/rules` | in-memory rules; empty body = delete |
| POST | `/api/alerts/run` | evaluates rules, correlates to filings |
| GET | `/api/alerts/history` | same evaluation over the full snapshot |
| GET | `/api/sources/{doc_id}?page=` | verbatim passage for a citation |
| GET | `/api/search?q=` | keyword retrieval over chunks |
| POST | `/api/ask`, `/api/ask/stream` | grounded answer, SSE frames |
| GET | `/api/cost` | cost ledger by provider |

## The two design decisions worth reading

**1. Verbatim gate.** `ledger.verify_quote()` normalises case and punctuation,
then requires the quote to appear in the stored chunk. A row whose quote cannot
be found is dropped and counted in `dropped_by_verbatim_gate`. It is never
shown. This is the mechanism behind "every quote passes a verbatim gate".

**2. Deterministic tier.** `llm.complete()` returns an empty completion on the
default tier, so every caller falls through to its rules. The pipeline never
depends on a model, because the local 1.5B model invented a margin target that
appears nowhere in a transcript. `FINN_LLM_TIER=local|hosted` swaps the backend
without touching call sites.

## What this does not reproduce

- **Live fetching.** `seed.py --live` is accepted but writes the recorded
  snapshot. NSE is network-blocked and BSE's JSON API answers 403 behind Akamai;
  the original fetchers (`fetchers/prices.py`, `fetchers/screener.py`,
  `fetchers/docs.py`) are not reconstructed beyond the shape of `http.py`.
- **The 26 real PDFs.** Document and chunk *text* here is synthetic but shaped so
  the promise gate is a genuine test. The originals were 6 annual reports and 20
  concall transcripts.
- **Embeddings.** `chunks.embedding` exists and is left empty; retrieval falls
  back to deterministic keyword scoring over the same chunks, so `/api/ask`
  works on a fresh seed without bge-small installed.
- **Prices.** 420 days of deterministic synthetic bars per ticker, not the 8,819
  real Yahoo EOD rows. Day moves and volume multiples are therefore real numbers
  computed from generated data — the alert rules work, but the moves are not
  historical fact.

## Honesty rules the code enforces

- Banks carry no EBITDA line (`config.BANK_TICKERS`), and the extractor says so.
- Only POLYCAB's results are `verified`; everything else is `extracted`.
- HDFCBANK's ledger returns `no_guidance_note` and score 0, because the source
  says management does not guide — that is the correct answer, not a gap.
- `/api/research/{t}/build` refuses rather than returning an empty success.
- When `/api/ask` finds nothing relevant it says so instead of writing prose.
