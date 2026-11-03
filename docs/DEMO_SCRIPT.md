# FINN — 90-Second Demo Walkthrough Script

A mobile-first walkthrough designed to run cleanly on a phone in 90 seconds.

---

### [0:00 – 0:20] Push Mode: The Briefing Feed
- **Visual**: App opens on the Briefing screen in dark near-black with amber accents.
- **Action**: Tap through time-scrubber pills (`24h`, `3d`, `7d`, `30d`).
- **Narration**: *"FINN replaces the endless flood of exchange filings with a filtered, prioritized intelligence feed for our 18-stock mock portfolio. The AI headline synthesizes what moved, while filings are grouped into three clear tiers based on an explainable 0–100 materiality score."*
- **Action**: Expand the POLYCAB results card showing QoQ and YoY metrics with the green `verified` badge (cross-checked against the quarterly table with 0.02% delta). Swipe a routine announcement left to dismiss.

### [0:20 – 0:45] Pull Mode: The Promise Ledger (Hero Feature)
- **Visual**: Tap the bottom navigation to open **Research**, select **TCS**.
- **Action**: Scroll down to the **Promise Ledger** section. Tap one of the management promises (e.g. margin target or headcount commentary).
- **Narration**: *"This is our hero feature: Narrative vs. Numbers. Instead of a chatbot summarizing earnings calls, FINN runs an audited Promise Ledger. It extracts management's forward-looking guidance, tests actual delivered numbers across subsequent quarters with exact arithmetic, and assigns a credibility score (0.80 for TCS). Every quote passes a strict verbatim gate against stored primary documents before rendering."*
- **Action**: Tap **HDFCBANK** in research to demonstrate that the ledger explicitly reports *"management does not provide guidance"* instead of hallucinating targets.

### [0:45 – 1:05] Triggered Alerts & Replay Simulation
- **Visual**: Tap **Alerts** tab.
- **Action**: Show the plain-English configurable rule cards (e.g., *Price move > 4%*, *Volume > 2.0x 20-day average*). Tap **Simulate Alert Replay**.
- **Narration**: *"Under Alerts, investors set threshold rules in plain English. The engine scans price and volume spikes and correlates them with regulatory filings, explaining whether a 4% move was driven by a contract win or unexplained market noise."*

### [1:05 – 1:20] Command Bar: Ask FINN
- **Visual**: Tap the persistent **Ask FINN** bottom command bar.
- **Action**: Submit prompt *"What did TCS guide on margin?"* Watch the SSE stream yield progressive reasoning steps (`Retrieving...`, `Extracting quotes...`, `Grounded...`, `Verified`) followed by the answer with primary citation chips.
- **Narration**: *"Ask FINN is strictly grounded in primary sources (annual reports, quarterly filings, concall transcripts). It streams answers with interactive citation chips linking directly to document excerpts — zero broker commentary, zero external noise."*

### [1:20 – 1:30] Settings & Cost Transparency
- **Visual**: Tap **Settings**.
- **Action**: Scroll past Dark Mode / 'Explain like I'm a PM' toggles to the **Cost Ledger** & **Routing Table**.
- **Narration**: *"Under Settings, FINN maintains an open cost ledger. We employ smart model routing — using deterministic cue extraction and rules first, local inference for structured extraction, and strict primary grounding. Total hosted tokens spent: zero. No AI slop, verified numbers, and predictable compute cost."*
