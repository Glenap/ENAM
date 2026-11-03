# Covering Email — Final Submission

**To:** assessment@enam.com  
**Subject:** ENAM - IIT screening - 2027  

---

Dear ENAM Evaluation Team,

Here is my submission for the **ENAM AI Engineer Build Challenge**: **FINN — Financial Investment Agent**.

---

## Submission Links

| Item | Link |
|---|---|
| 📱 **Mobile-First Web Prototype** | https://magnificent-licorice-fb28bb.netlify.app |
| 🐙 **GitHub Repository** | https://github.com/Glenap/ENAM |
| 🤖 **AI Build History (Antigravity / Gemini)** | https://antigravity.google.dev/conversations/e6a0374d-04c1-450c-b91e-0a8e0a59d567 |
| 🤖 **Netlify Agent Runs** | https://app.netlify.com/projects/magnificent-licorice-fb28bb/agent-runs |

> The Netlify app is a **PWA** — open the link on a phone and tap "Add to Home Screen" for a native-like experience. The app runs fully on the bundled offline snapshot so it never shows a blank screen.

---

## 1. What I Built

A mobile-first investment intelligence agent designed around the principle of **"Show less, mean more."**

### Push Intelligence — The Briefing Feed
- A windowed digest (`24h` / `3d` / `7d` / `30d`) for an 18-stock diversified portfolio (private banks, IT services, FMCG, auto, pharma, capital goods, PSUs, midcaps, turnaround).
- An explainable **0–100 materiality score** that classifies every exchange filing into three actionable tiers (`High` / `Medium` / `Routine`) with a step-by-step breakdown (price reaction, novelty, category weight, confidence).
- Results cards extracting Revenue, EBITDA, PBT, PAT with QoQ/YoY changes, banking-specific formatting (no false EBITDA row for HDFC Bank), and cross-source verification (Polycab: 0.02% delta vs. the quarterly table → `verified` badge).
- Swipe-to-dismiss and swipe-to-track gestures; portfolio strip with sparklines.

### Pull Intelligence — 8 Research Lenses + **Promise Ledger (Hero Feature)**
- Per-company research with 8 swipeable lens cards: Business, Snapshot, Trajectory, Balance Sheet, Cash Quality, Narrative vs Numbers, Guidance, Bull / Bear.
- An audited **Promise Ledger** that extracts management's forward-looking guidance from concall transcripts, cross-references the promises against subsequently published financials, and computes a credibility score using exact arithmetic:
  - TCS: 0.80 (*"4 of 5 measurable claims held up"*)
  - Apollo Hospitals: 1.00
  - HDFC Bank: `None` — *"management does not provide guidance"* (the correct answer, not an invented score)
- Every quote passes a **strict verbatim gate** — it must be found in the stored source chunk after normalisation before it can render. Hallucinated quotes are dropped and counted.

### Triggered Alerts & Replay Simulation
- Plain-English configurable rule cards (price move > ±4%, volume > 2.0× 20-day average, material filing detected).
- An event-filing correlation engine that distinguishes news-driven moves from unexplained market noise.
- **Simulate Alert Replay** runs the rule engine backwards over the snapshot so reviewers can see historical firings without live data.

### Ask FINN — Command Bar (Pull, Grounded, Streamed)
- A persistent bottom command bar that sends questions over SSE, showing live reasoning steps (`Retrieving`, `Extracting quotes`, `Grounded`, `Verified`) before the final answer.
- Answers come with clickable **citation chips** linking to verbatim passages in source documents. No broker commentary; no secondary noise.
- 3 contextual follow-up suggestions generated from the answer itself.

### Settings — Cost Transparency
- An in-app **cost ledger** showing total tokens, total ₹ spend, and the model routing table (deterministic → local → hosted) so the reviewer can audit the inference chain.

---

## 2. Key Decisions & Trade-Offs

**Determinism over hallucination.**  
A local 1.5B model hallucinated a margin target ("18.0%") absent from the Maruti transcript. I rejected it and replaced LLM promise extraction with deterministic cue regex (`we expect / we will deliver / capex of / maintain guidance`) + the verbatim gate. A grounded but less fluent answer beats an invented fluent one.

**Snapshot-first architecture.**  
NSE is network-blocked (`000`); BSE's Akamai JSON API returns 403. Rather than fail gracefully and show empty screens, FINN is built snapshot-first — a pre-seeded SQLite database (`finn/seed.py`) and a bundled `offline_data.dart` snapshot cover all 22 tickers. A live backend (`backend/finn/api.py`, FastAPI, 15 endpoints) upgrades quality when reachable but is never required for a demo.

**Flutter Web → Netlify.**  
Single codebase, PWA manifest, add-to-home-screen on iOS and Android without an App Store submission. Offline fallback means the prototype works even when the FastAPI backend is not deployed.

**No chatbot tab.**  
The brief explicitly warns against *"generic Q&A on broker commentary."* Ask FINN is document-scoped and grounded. I refused the obvious thing.

---

## 3. What Was Deliberately Left Out

- **Live NSE/BSE streaming** — sources are blocked or rate-limited; a snapshot-first design is the honest answer, not faked live data.
- **Voice input** — the mic button is present and routes to Web Speech API; I didn't ship a feature I couldn't demo reliably.
- **Full Ledger for all 22 tickers** — the Ledger is pre-warmed for 6 tickers (the 4 research names + 2 deep-history portfolio names); the rest build lazily on first open via `POST /api/research/{ticker}/build`. Depth over breadth.
- **Auth, multi-user, brokerage integration** — out of scope.

---

## 4. Where I'd Take It Next

1. **Live filing ingestion** via NSE/BSE WebSocket or screener's public announcement feed, piped into the materiality pipeline in real time.
2. **Cross-transcript speaker diarization** — tracking a CFO's promise record when they move between companies.
3. **User-imported CAS portfolio** — replace the demo portfolio with an investor's actual holdings from Zerodha / MF Central statement upload.
4. **Android APK / iOS TestFlight** — the Flutter codebase compiles directly; the `android/` directory is already scaffolded.

---

Warm regards,  
Vikash Yadav  
IIT Screening - 2027  

**GitHub:** https://github.com/Glenap/ENAM  
**Prototype:** https://magnificent-licorice-fb28bb.netlify.app  
**AI Build History:** https://antigravity.google.dev/conversations/e6a0374d-04c1-450c-b91e-0a8e0a59d567
