# Covering Email Submission

**To:** assessment@enam.com  
**Subject:** ENAM - IIT screening - 2027  

---

Dear ENAM Evaluation Team,

Here is my submission for the **ENAM AI Engineer Build Challenge**: **FINN (Financial Investment Agent)**.

### Submission Links
- **Deployed Mobile Prototype (Netlify):** https://magnificent-licorice-fb28bb.netlify.app  
  *(Optimized for mobile viewport / responsive web; add to home screen as PWA)*
- **GitHub Repository:** https://github.com/Glenap/ENAM
- **Netlify Deploy Preview (PR #1):** https://deploy-preview-1--magnificent-licorice-fb28bb.netlify.app

---

### 1. What I Built
A mobile-first investment intelligence agent designed around the principle of *"Show less, mean more."*

1. **Push Intelligence (The Briefing)**:
   - A windowed digest (`24h`, `3d`, `7d`, `30d`) covering an 18-stock diversified portfolio (banks, IT, auto, pharma, FMCG, capital goods, and turnaround plays).
   - An explainable 0–100 materiality scoring engine that classifies exchange filings into 3 actionable tiers (`High`, `Medium`, `Routine`), with swipe-to-dismiss and swipe-to-track gestures.
   - Grounded results cards extracting headline numbers (Revenue, EBITDA, PBT, PAT) with QoQ/YoY changes, banking-specific format handling (no false EBITDA for banks), and cross-source verification anchors against quarterly tables (0.02% error margin on Polycab).

2. **Pull Intelligence & The Promise Ledger (Hero Feature)**:
   - 8 research lenses for company drilldowns (Business snapshot, Financials, Trajectory, Balance sheet, Cash quality, Narrative vs Numbers, Guidance, Bull vs Bear).
   - An audited **Promise Ledger** evaluating management accountability: extracts forward-looking guidance from earnings call transcripts, pairs them with subsequent actual delivered financials, and scores management credibility (e.g. TCS at 0.80, Apollo Hospitals at 1.00, and HDFC Bank explicitly noted as "management does not provide guidance").
   - A strict **verbatim gate**: every quote must match stored primary source chunks after normalization, preventing hallucinations.

3. **Triggered Alerts & Replay Simulation**:
   - Plain-English configurable rules (e.g. *Price move > ±4%*, *Volume > 2.0x 20-day average*, material filings).
   - Event-filing correlation engine distinguishing news-driven price moves from unexplained market action.

4. **Ask FINN (Primary-Grounded Command Bar)**:
   - Persistent bottom command bar streaming grounded answers with live SSE progress steps, clickable citation chips, and 3 follow-up query suggestions.
   - Zero secondary commentary: relies purely on primary filings and earnings call transcripts.

5. **Transparency & Cost Ledger**:
   - In-app routing table and cost ledger tracking token spend and model inference costs across deterministic, local, and hosted tiers.

---

### 2. Key Architecture Decisions & Trade-Offs

- **Determinism Over Hallucination**:
  During testing, local small models hallucinated nonexistent margin targets for Maruti Suzuki transcripts. Rather than shipping fluent but false prose, I built a deterministic regex/cue extraction engine backed by an automated verbatim verification gate. A verifiable, grounded answer beats a fluent invented one every time.
- **Frozen Snapshot Architecture**:
  Real-world exchange sources frequently block scraping or rate-limit requests (BSE Akamai 403, NSE network blocking). FINN is architected snapshot-first using a pre-seeded SQLite database and offline fallback data covering all 18 portfolio stocks + 4 research names (22 total). This ensures the mobile prototype is 100% reliable and never fails during review.
- **Frontend / Backend Decoupling**:
  The Flutter client runs as an offline-capable PWA on static hosts like Netlify while seamlessly proxying to the full FastAPI backend (`backend/finn/api.py`) when available.

---

### 3. What Was Deliberately Left Out
- **Chatbot slop**: Refused the generic conversational chatbot tab in favor of structured financial lenses, actionable tier cards, and a verifiable Promise Ledger.
- **Third-party commentary / broker notes**: Excluded all secondary commentary to maintain pure primary source grounding.
- **Real web push / SMS**: Maintained in-app alert history and simulation rather than fragile notification services.

---

### 4. Where I Would Take It Next
- **Live WebSocket ingestion**: Streaming real-time NSE/BSE filings directly into the materiality pipeline.
- **Cross-transcript speaker diarization**: Tracking executive credibility when management moves between companies (e.g. incoming CFO track record).
- **Custom multi-portfolio management**: User-imported CAS (Consolidated Account Statement) portfolio feeds.

---

Warm regards,  
Vikash Yadav  
IIT Screening - 2027  
Repository: https://github.com/Glenap/ENAM
