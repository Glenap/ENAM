# FINN — a financial investment agent

"Show less, mean more."

A Flutter client for the FINN investment-research API. Dark, near-black UI with a
single amber accent; briefing feed, per-company research lenses, promise ledger,
alerts and an SSE-backed Ask bar.

## Architecture

```
lib/
  api.dart              thin HTTP client over the FINN API (cached GET, SSE stream)
  main.dart             app shell, theme + preference wiring
  screens/briefing.dart headline, tier stack, time scrubber, portfolio strip
  screens/research.dart 8 swipeable lens cards + promise ledger
  screens/company.dart  single-name drill-down
  screens/alerts.dart   plain-English rule builder + replay simulation
  screens/settings.dart local preferences
  widgets/ask_bar.dart  Ask FINN, streamed answers with citation chips
  widgets/cite.dart     citation chips and verbatim-quote display
  widgets/charts.dart   sparklines
  theme/tokens.dart     colour / type tokens
```

## The API dependency — read this before deploying

`lib/api.dart` resolves its base URL in this order:

1. `--dart-define=FINN_API=<url>` if provided at build time;
2. otherwise `Uri.base.origin` (i.e. same origin as the page);
3. otherwise `http://localhost:8000`.

Every screen fetches from that base. **This app is a front end and requires the
FINN FastAPI backend to return data.** That backend is *not* included in this
repository, and Netlify serves static files only, so a deploy here will load the
shell and then show connection errors on the data screens until an API is
reachable.

### Connecting a Netlify deploy to the API

In Netlify, set the environment variable `FINN_API` to your backend's origin
(for example `https://finn-api.example.com`) and redeploy. The build script then
makes Netlify proxy `/api/*` to that backend, so the app calls its own origin
and the backend needs no CORS setup.

If `FINN_API` isn't set, `/api/*` returns a JSON "backend not connected" error.
Without that rule, those requests would get `index.html` from the SPA fallback.

## Local development

```bash
flutter pub get
flutter run -d chrome --dart-define=FINN_API=http://localhost:8000
```

## Web build

```bash
flutter build web --release
# output: build/web
```

## Deploying

The repo ships a `netlify.toml` (publish `build/web`, SPA fallback, cache headers).
Connect the repository in Netlify and it will build and deploy on every push.

## Status

Recovered from a sandbox backup. `flutter analyze` reports 0 errors (warnings and
infos only) and the web release build succeeds.
