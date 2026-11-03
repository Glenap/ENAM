# FINN — Phase 0 Plan

## 0. What I verified before planning (probed live in this environment)

These are measured, not assumed. They changed the architecture.

| Probe | Result | Consequence |
|---|---|---|
| Yahoo chart API (raw) | `429` | Needs TLS impersonation, not plain requests |
| Yahoo chart API via `curl_cffi` impersonate chrome124 | `200`, real OHLCV | ✅ Price/volume layer is LIVE |
| `yfinance` (pandas path) | `TypeError: Cannot convert numpy.ndarray` | Use direct Yahoo chart JSON, not yfinance |
| NSE website / nsearchives | `000` (blocked), `404` | NSE fetch = adapter that fails cleanly, not a dependency |
| BSE `AnnGetData` JSON API | `403` Akamai | Use BSE **public PDF endpoints** instead |
| BSE `AnnPdfOpen.aspx?...pdf` | `200`, 723 KB, 29pp, 52k chars, **85 speaker turns** | ✅ Real concall transcripts downloadable |
| screener.in `/company/<T>/consolidated/` | `200` | ✅ Announcements + 8 quarters of financials |
| screener.in announcements feed | `200`, real dated filings | ✅ Push layer is LIVE (titles + dates + links + summaries) |
| screener.in `/api/company/search/?q=` | `200`, returns ID+name+url | ✅ "Research any ticker" works generically |
| RIL annual report PDF (147 pp) | `200`, 9.7 MB, clean text | ✅ AR grounding is LIVE |
| Hosted LLM (`OPENAI_BASE_URL` proxy) | `400` → *"Free-plan credits can't be used with the LLM proxy"* | ⚠️ **No hosted LLM credits.** Must degrade gracefully |
| Sets 3–5 would need `flask` + raw JSON | Needs `flask` + raw JSON | Flask already present; raw blob storage available |
| Host | 4 vCPU / 7 GB RAM / 20 GB free | Local small models feasible, but RAM-tight |
| `llama-cpp-python` (CPU) | ✅ installs and imports | ✅ Local model path viable |

**Two honest consequences**, both handled explicitly rather than hidden:

1. **Narrative/verification LLM work cannot depend on a paid API here.** Architecture = one `LLMProvider` interface with three implementations: `HostedProvider` (used if `OPENAI_API_KEY` has credit), `LocalProvider` (Qwen2.5-1.5B-Instruct GGUF on CPU), `DeterministicProvider` (regex/NLP extraction + retrieval + template synthesis — zero tokens, always works). The app runs fully on the third; the first two upgrade prose quality. Every LLM output is *verified against the source chunk* by a deterministic checker, so grounding is not dependent on the model behaving.
2. **The Briefing is built on a genuinely frozen snapshot.** "Today" in the demo = **31 Oct 2026**. Live refetch is switched off by design (`FINN_MODE=snapshot`). The UI states freshness on every screen. This is the brief's own rule (3.4) and it's what makes the reviewer's demo work on a plane.

---

## 1. Portfolio — 18 NSE tickers

Chosen so that **every card archetype fires at least once** and the sectors span the economy. Reasons are the "why it's held" one-liners shown in-app.

| # | Ticker | Company | Sector | Cap | One-line reason it's in the book |
|---|---|---|---|---|---|
| 1 | HDFCBANK | HDFC Bank | Private bank | Large | Core compounding; the post-merger deposit story is the whole thesis |
| 2 | ICICIBANK | ICICI Bank | Private bank | Large | Best-in-class margin discipline; the bank I benchmark others against |
| 3 | TCS | Tata Consultancy | IT services | Large | Cash machine; tests whether AI demand shows up in deal wins |
| 4 | INFY | Infosys | IT services | Large | Pair trade vs TCS on margin execution |
| 5 | HINDUNILVR | Hindustan Unilever | FMCG | Large | Rural recovery proxy with pricing power |
| 6 | ITC | ITC | FMCG/conglomerate | Large | Dividend anchor; hotels demerger optionality |
| 7 | MARUTI | Maruti Suzuki | Auto | Large | Volume + mix recovery; SUV share is the swing factor |
| 8 | TATAMOTORS | Tata Motors | Auto | Large | JLR destocking vs India CV cycle — the messy one |
| 9 | SUNPHARMA | Sun Pharma | Pharma | Large | Specialty ramp is the only thing that matters here |
| 10 | CIPLA | Cipla | Pharma | Large | Respiratory franchise; steady, unexciting, useful |
| 11 | LT | Larsen & Toubro | Capital goods | Large | Order-book proxy for the capex cycle |
| 12 | SIEMENS | Siemens India | Capital goods | Large | Purer play on grid/electrification capex |
| 13 | NTPC | NTPC | PSU utilities | Large | Regulated growth + the nuclear/renewables narrative |
| 14 | ONGC | ONGC | PSU energy | Large | Cheap, cyclical, policy-exposed; the value trap test |
| 15 | ASIANPAINT | Asian Paints | Mid | Mid | Share-loss story; competitive intensity is the question |
| 16 | POLYCAB | Polycab | Mid (wires) | Mid | Electrification tailwind with real earnings delivery |
| 17 | APOLLOHOSP | Apollo Hospitals | Mid (healthcare) | Mid | Occupancy + ARPOB; the quality-of-growth debate |
| 18 | YESBANK | Yes Bank | Small (bank) | Small (turnaround) | The turnaround slot: is the recovery real or a base effect? |

**Slot coverage check** (this is why these 18 and not others): large-cap bank ✅ ×2, IT ✅ ×2, FMCG ✅ ×2, auto ✅ ×2, pharma ✅ ×2, capital goods ✅ ×2, PSU ✅ ×2, midcaps ✅ ×3, small-cap turnaround ✅, plus one high-news-flow name (TATAMOTORS) to make the Briefing dense.

## 2. Research tickers — 4 outside the portfolio

Picked to prove the engine generalises across **business models**, not just across tickers:

| Ticker | Why this one |
|---|---|
| RELIANCE | Conglomerate — forces multi-segment handling (energy/digital/retail) |
| ZOMATO→ETERNAL | Loss-to-profit turnaround; tests the ticker-rename trap (symbol changed, engine must resolve) |
| DIXON | Small-cap EMS — high growth, thin margins, very different financial shape |
| DMART (AVENUE SUPERMARTS) | Retail with negative working capital; tests balance-sheet lens weirdness |

`/search` + `research any ticker` input means a reviewer can type any NSE symbol and get the full pipeline. Nothing about these four is hardcoded in the engine.

## 3. Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│ Flutter 3.35.4 · web build served on :5060 · PWA manifest · 390px    │
│                                                                      │
│  BRIEFING (push)      ASK FINN (pull)        RESEARCH (pull)         │
│  · AI headline        · command bar          · 8 lenses              │
│  · materiality stack  · streamed answer      · PROMISE LEDGER (hero) │
│  · 3 tiers + fold     · citation chips       · credibility score     │
│  · time scrubber      · 3 follow-up chips    · source excerpt viewer │
│  · swipe track/kill                                  │               │
│  · portfolio strip                                   │               │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ JSON + SSE  (CORS, 0.0.0.0:8000)
┌───────────────────────────┴──────────────────────────────────────────┐
│ FastAPI                                                              │
│  fetchers/   prices(yahoo+impersonate) · anns(screener) · docs(PDF)   │
│  classify/   keyword→LLM escalation→cache by filing hash              │
│  score/      materiality 0-100 (4 weighted inputs, explainable)       │
│  extract/    results numbers → QoQ/YoY, consolidated vs standalone    │
│  rules/      threshold engine + replay/simulate                       │
│  research/   fetch→chunk(speaker)→embed→retrieve→extract→VERIFY→cache │
│  llm/        Provider iface: hosted | local(Qwen GGUF) | deterministic│
│  ledger/     promise extraction → delivery lookup → verdict chips     │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
      ┌─────────────────────┴──────────────────────┐
      │ SQLite + files on disk (the snapshot)      │
      │ prices · announcements · documents ·       │
      │ chunks · embeddings(quantised int8) ·      │
      │ extractions · llm_cache(content hash) ·    │
      │ cost_ledger · verdicts                     │
      └────────────────────────────────────────────┘
```

**Data flow of one push item:** filing title+date+URL (screener) → filing ID/hash → classifier (category, confidence) → results? download PDF → extract Rev/EBITDA/PBT/PAT (cons+standalone) → screener quarterly table as the *verification anchor* → materiality score → card.

**Data flow of one Promise Ledger row:** concall PDF → chunk by speaker → embed → retrieve "guidance-like" chunks (deterministic cue list: *we expect / we will deliver / double-digit / margin of / capex of / we maintain guidance*) → structured promise {metric, direction, value, horizon, quote, page} → actual from quarterly table for the delivery quarter → deterministic verdict (Delivered / Partially / Missed / Not measurable) with tolerance band → credibility score = delivered ÷ measurable.

## 4. Stack (and what I'm changing from the suggested one, with justification)

| Layer | Choice | Justification |
|---|---|---|
| Frontend | **Flutter 3.35.4 → web/PWA** | This environment is Flutter-native (locked, with a build+serve pipeline and PWA/web preview). One codebase also yields the Android APK the job posting's "mobile-first" implies. React+Vite was suggested but would fight the sandbox toolchain for zero product gain. |
| Design system | Hand-built: dark near-black, single amber accent, tabular mono numerals, display serif for headlines | "No AI slop" is a grading axis; a custom token set beats a component library |
| Backend | **FastAPI + SQLite**, APScheduler not needed (snapshot mode) | Exactly as suggested; SQLite is the snapshot |
| Retrieval | **Local embeddings via llama.cpp (bge-small GGUF) → cosine; fallback BM25** | No embedding API credits; keeps pull side fully offline-capable |
| LLM | **Provider interface (hosted → local GGUF → deterministic)** | Hosted credits are exhausted in this sandbox; the deliverable must still run |
| Charts | **Hand-rolled CustomPainter** (sparkline, bars, donut, small multiples) | 4 KB of code vs a dependency; full control of the aesthetic |
| Deploy | Static web build + FastAPI, one `make dev`; Dockerfile included | Reviewer-friendly |

Model routing (documented in README, real numbers in the in-app cost ledger):

| Task | Tier | Why |
|---|---|---|
| Filing classification | deterministic rules first, LLM only on low confidence | 90% of titles are keyword-obvious |
| One-line summaries | cheap/local model | bulk, low stakes |
| Results number extraction | deterministic table parse + LLM repair on failure | numbers must be exact; never guess |
| Promise extraction | local/cheap model + deterministic cue regex | structured, bounded |
| Verdict synthesis, Bull/Bear, ambiguous verification | strong reasoning model **only** | the one place quality is visible |

## 5. Data model (SQLite, typed)

`companies(ticker, name, sector, cap, in_portfolio, reason, bse_code, screener_slug)`
`prices(ticker, date, o,h,l,c,v)` · `price_stats(ticker, date, ret_1d, vol_20d_avg, vol_ratio)`
`announcements(id PK, ticker, filed_at, title, category, category_conf, url, doc_id, summary, novelty, materiality, score_inputs_json)`
`documents(id PK, ticker, kind[AR|TRANSCRIPT|RESULTS], period, url, sha256, pages, path)`
`chunks(id PK, doc_id, seq, page, speaker, text, emb BLOB int8)`
`extractions(doc_id, schema_json, confidence, verified_json)` · `financials(ticker, period, metric, value, scope[cons|standalone], source)`
`promises(id, ticker, metric, direction, value, horizon, quote, page, doc_id)` · `verdicts(promise_id, actual, verdict, basis)`
`rules(id, expr_json, enabled)` · `alerts(id, rule_id, ticker, fired_at, trigger_text, linked_ann_id)`
`llm_cache(key=sha256(prompt+model), response_json, tokens_in, tokens_out, cost_inr)`
`cost_ledger(ts, feature, model, tokens, inr)`

## 6. The cut-line — what I will NOT build

Stated up front, because scope discipline is being graded:

1. **Live NSE announcements API** — blocked at the network level (`000`). BSE's Akamai-protected JSON also 403s. I use screener's announcement mirror (real filings, real dates, real PDF links) behind a `AnnouncementSource` adapter with a documented, tested NSE/BSE direct implementation that activates if the network allows. Not faked.
2. **Voice input (Web Speech API)** — stretch only; mic button present and honest about capability detection.
3. **Real web push (service-worker notifications)** — PWA installable + manifest shipped; notifications are in-app + alert history. I will not ship a notification path I can't demo reliably.
4. **Share-card-as-image** — only if Phase 7 time allows.
5. **Full 4-quarter Promise Ledger for all 22 tickers** — the seed pre-warms 6 (the 4 research names + 2 portfolio names with the deepest transcript history). Other tickers build lazily on first open, with the progress timeline. Depth over breadth, per the brief.
6. **Auth, multi-user, real brokerage integration, backtesting** — out of scope, not mentioned in brief.
7. **A generic chatbot tab** — explicitly refusing the obvious thing the brief warns against.

## 7. Build order (each phase ends runnable)

- **P1** Data layer: 22-ticker seed → `data/finn.db` + PDFs on disk; FastAPI endpoints; pytest on parsers.
- **P2** Classifier + materiality + Briefing UI (tiers, scrubber, swipe, portfolio strip).
- **P3** Results card (QoQ/YoY, cons/standalone, confidence, source page) + management-change card with labelled outside-source bio.
- **P4** Rule builder (plain-English tokens, sliders, per-stock overrides) + engine + Simulate-alert replay.
- **P5** Research pipeline + 8 lenses + **Promise Ledger** with citations & verification pass.
- **P6** Ask FINN: streamed SSE answers, citation chips, 3 follow-ups.
- **P7** Polish, PWA, cost ledger screen, README, demo script, covering note.

Priority if time compresses: **Briefing + Results card > Promise Ledger > Alerts > rest** (per the brief; I've put Ledger above Alerts because it's the differentiation and it shares the extraction pipeline with Phase 3).

---

## Open question (one only, per your rule)

**Cost ledger currency:** I'll report **₹ with a documented ₹/$ assumption** (₹88/$) and show the local-model default at ₹0.00, since hosted credits are unavailable in this environment — the ledger records real tokens for hosted calls and real wall-clock compute for local ones. Proceeding unless you say otherwise.

Starting Phase 1 now: seed script for the 18 + 4, snapshot committed, endpoints live.
