#!/usr/bin/env bash
# Netlify build script: installs the Flutter SDK (not preinstalled on Netlify)
# and builds the web app into build/web.
set -euo pipefail

# Pin Flutter for reproducible builds. pubspec.lock requires Flutter >= 3.35.0.
# Override by setting FLUTTER_VERSION in the Netlify environment variables.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.35.7}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter-sdk}"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  # Download the official release archive (no git clone needed).
  ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  echo "Installing Flutter $FLUTTER_VERSION into $FLUTTER_HOME"
  TMP_DIR="$(mktemp -d)"
  curl -fsSL --retry 3 "$ARCHIVE_URL" -o "$TMP_DIR/flutter.tar.xz"
  tar -xJf "$TMP_DIR/flutter.tar.xz" -C "$TMP_DIR"
  rm -rf "$FLUTTER_HOME"
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  mv "$TMP_DIR/flutter" "$FLUTTER_HOME"
  rm -rf "$TMP_DIR"
fi
# The archive's git checkout may be owned by another user; let git trust it.
git config --global --add safe.directory "$FLUTTER_HOME" 2>/dev/null || true
export PATH="$FLUTTER_HOME/bin:$PATH"

flutter config --no-analytics >/dev/null
flutter --version
flutter pub get

# API wiring. The FINN FastAPI backend is hosted separately. Set FINN_API in the
# Netlify environment variables to its origin (e.g. https://finn-api.example.com).
# Netlify then proxies /api/* to it, so the app calls its own origin: no CORS
# setup is needed on the backend. The app itself is built without a base URL
# so it always uses same-origin /api/* paths.
flutter build web --release

API_ORIGIN="${FINN_API:-}"
API_ORIGIN="${API_ORIGIN%/}"
API_ORIGIN="${API_ORIGIN%/api}"
REDIRECTS="build/web/_redirects"
if [ -n "$API_ORIGIN" ]; then
  echo "Proxying /api/* to $API_ORIGIN"
  printf '/api/*  %s/api/:splat  200!\n' "$API_ORIGIN" > "$REDIRECTS"
else
  # Without this, /api/* falls through to the SPA fallback and the app gets
  # index.html instead of JSON ("Unexpected token '<'").
  echo "WARNING: FINN_API is not set; /api/* will return a 'not configured' error."
  cat > build/web/api-not-configured.json <<'JSON'
{"error": "FINN backend not connected. Set the FINN_API environment variable in Netlify to your API's URL and redeploy."}
JSON
  printf '/api/*  /api-not-configured.json  404!\n' > "$REDIRECTS"
fi
