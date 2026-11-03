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

# The app reads its API base URL from the FINN_API compile-time define.
BUILD_ARGS=(--release)
if [ -n "${FINN_API:-}" ]; then
  BUILD_ARGS+=("--dart-define=FINN_API=$FINN_API")
fi

flutter build web "${BUILD_ARGS[@]}"
