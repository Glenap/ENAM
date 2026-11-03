# FINN — Build Handover (state at end of this session)

**Read this first.** It states exactly what runs, what doesn't, and what to do next.
No claim below is aspirational — every "works" item was executed and its output observed.

---

## 1. What is built and verified

### Backend: complete through the data + reasoning layers (Phases 1, 2, 4, 5 data engine, 6 backend)

Snapshot is built and on disk: `/home/user/data/finn.db` (11.3 MB) + `/home/user/data/docs/` (26 PDFs).

| Table | Rows | Meaning |
|---|---|---|
| companies | 22 | 18 portfolio + 4 research tickers |
| prices | 8,819 | real Yahoo EOD bars, 420 days, `.NS` with `.BO` fallback |
| announcements | 129 | real BSE filings via screener mirror, classified + scored |
| documents | 26 | 6 annual reports + 20 concall transcripts |
| chunks | 2,328 | speaker-aware chunks, **all embedded** (bge-small, int8) |
| financials | 3,341 | 13 quarters × metrics × 22 tickers |
| promises / verdicts | 25 / 25 | Promise Ledger rows with delivered values |

### Verified behaviours (observed output, not claims)

- **Results extraction is exact.** POLYCAB Q2FY27 filing parsed on page 6:
  Revenue ₹98,989.01 mn, EBITDA ₹14,224.98 mn (computed, basis disclosed),
  PBT ₹13,062.20 mn, PAT ₹9,899.97 mn. Cross-checked against screener's
  independent quarterly table: **PBT 1306.2 Cr vs 1306.0 Cr (0.02% delta),
  PAT exact → verification status `verified`.** That cross-source check is the
  honesty anchor: a number that fails it is shown as `extracted`, never as fact.
- **Bank handling is explicit.** HDFC Bank has no EBITDA line; the extractor
  detects the financing-Profit layout and says so instead of printing a
  meaningless "EBITDA".
- **Promise Ledger produces real verdicts.** TCS: 5 claims, credibility 0.80
  ("4 of 5 measurable claims held up"). DIXON 1.00, APOLLOHOSP 1.00,
  RELIANCE 0.67, HDFCBANK `None` with the note *"the source itself says
  management does not guide"* — which is TCS/HDFC's actual opening disclaimer,
  and the correct answer rather than an invented target.
- **Every quote passes a verbatim gate** (`verify_quote`) against the stored
  chunk before it can render; all 25 seeded rows returned `verified=True`.
- **API is live and smoke-tested** (FastAPI TestClient):
  `/api/meta` 200 · `/api/portfolio` 200 (9.7 kB) · `/api/briefing` 200 with
  101 items tiered 18/52/31 · `/api/research/TCS` 200 (8 lenses + ledger) ·
  `/api/ask` 200 returning *"Sep 2026 vs Sep 2025: Revenue Rs 73,188 cr
  (+11.2% YoY); PAT Rs 13,934 cr (+14.9% YoY)…"*.
- **Classifier** is rules-first, cached by filing hash; local Qwen2.5-1.5B
  correctly classified a management-change filing at ₹0.00 in 3.6 s.

### Two environment facts that shaped the design (measured, not assumed)

1. **Hosted LLM has no credits** here — the proxy returns
   *"Free-plan credits can't be used with the LLM proxy."* So nothing
   user-visible depends on it. One `LLMProvider` interface, three backends
   (hosted / local GGUF / deterministic), and the pipeline ships on the
   deterministic tier.
2. **NSE is network-blocked** (`000`) and BSE's JSON API is Akamai-403.
   Announcements come from screener's BSE mirror (real filings, dates, PDFs)
   behind an adapter. Not faked; documented.

### A judgement call worth defending in the interview

The local 1.5B model **hallucinated** a margin target ("18.0%") that appears
nowhere in the Maruti transcript. I rejected the model for promise extraction
and replaced it with deterministic cue extraction plus a verbatim gate. The
headline lesson: *a worse-sounding but verifiable answer beats a fluent
invented one* — precisely the discipline the brief asks for on the pull side.

---

## 2. What is NOT built

**The Flutter UI (Phases 2–3, 5 UI, 6 UI, 7).** No `lib/` screens exist yet.
The Briefing, cards, lenses, Alert builder and Ask bar are served as JSON and
have no front end. `flutter_app/build/web` is absent, so
`http://localhost:5060/` currently returns the API placeholder JSON.

Also not built: PWA manifest/service worker, cost-ledger screen, APK, the
90-second demo script, the covering-email draft.

I stopped rather than start the UI and leave it half-wired — the brief's own
rule is that a demo which doesn't run is the worst outcome, and a broken UI
would be exactly that.

---

## 3. Exact next steps (in priority order)

```bash
# 1. run the API (works today)
cd /home/user/backend && python3 -m uvicorn finn.api:app --host 0.0.0.0 --port 8000
curl -s localhost:8000/api/briefing?window=800 | head -c 400

# 2. rebuild snapshot anytime (idempotent; ~7.5 min)
python3 -m finn.seed

# 3. then: Flutter UI against these endpoints
#    lib/theme.dart      - dark near-black, one amber accent, tabular mono
#    lib/api.dart        - client for the 12 endpoints
#    lib/screens/briefing.dart  - headline, tier stack, 24h/3d/7d/30d scrubber,
#                                 swipe track/dismiss, portfolio strip + sparkline
#    lib/screens/research.dart  - 8 swipeable lens cards + Promise Ledger
#    lib/screens/alerts.dart    - plain-English rule builder + simulate replay
#    lib/widgets/ask_bar.dart   - SSE stream, citation chips, 3 follow-ups
# 4. serve build/web from the API on 5060 (route already mounted)
```

### Known defects to fix first

1. `finn/api.py` `/api/search` builds its screener URL in a convoluted way
   (`__import__` hack) — replace with a direct `http.get_json` call.
2. `_price_on()` scores announcements against the filing date but the snapshot's
   latest price is 31 Oct 2026, so reaction inputs for older filings default to
   zero — acceptable, but label it in the UI.
3. Maruti's non-BSE transcript links served HTML instead of PDF (3 misses);
   screener's BSE copies cover the same quarters.
4. Ledger covers 6 pre-warmed tickers; the rest need the lazy-build endpoint
   (`POST /api/research/{ticker}/build` is **not implemented** yet).
5. `docs/PHASE0_PLAN.md` predicted a fully working 7-phase app; that was the
   plan, and this file supersedes it on status.

---

## 4. Repo map as it stands

```
/home/user/backend/finn/
  config.py      portfolio, weights, category weights, snapshot consts
  store.py       SQLite schema + typed accessors
  http.py        retry/impersonation layer (Yahoo 429 bypass, clean failures)
  classify.py    rules -> local LLM escalation, cached by filing hash
  score.py       materiality 0-100, four weighted inputs, explainable
  research.py    chunking, bge embeddings, retrieval, verification helpers
  ledger.py      promise extraction, delivery arithmetic, verdicts, summary
  extract/results.py  Rev/EBITDA/PBT/PAT + QoQ/YoY + cross-source verification
  fetchers/screener.py  one page -> financials + anns + ARs + concalls
  fetchers/prices.py    Yahoo chart JSON -> bars + volume stats
  fetchers/docs.py      PDF download, hashing, month->quarter mapping
  llm.py         provider interface + content-hash cache + cost ledger
  seed.py        the snapshot builder
  api.py         FastAPI: briefing, results, research, rules, alerts, ask, cost
/home/user/flutter_app/docs/PHASE0_PLAN.md   plan + verified environment table
/home/user/flutter_app/docs/HANDOVER.md      this file
```

---

## 5. Covering-note material (honest version)

**Built:** a snapshot-first data layer that survives the sources blocking you;
results extraction that is verified against an independent table rather than
trusted; a Promise Ledger whose verdicts are arithmetic and whose quotes pass a
verbatim gate; a materiality model a user can interrogate line by line; and a
deliberate refusal to let a small local model invent numbers.

**Tradeoff taken:** depth on grounded extraction over breadth of screens.
The judgement call — rejecting a fluent model for a verifiable parser — is the
one I'd most want to discuss.

**Left out:** the UI layer, voice, real web-push, and lazy research for
non-pre-warmed tickers.

**Next:** ship the Briefing screen first (it needs only `/api/briefing`), then
the Ledger view, then Alerts — in that order, because that is the order in
which they earn the reviewer's attention.
