#!/usr/bin/env bash
# ============================================================================
# Zero Count — Flutter verification pipeline (reusable for ALL Flutter stories).
#
# Stages:
#   1. flutter --version
#   2. flutter pub get
#   3. flutter analyze
#   4. flutter test
#   5. flutter build web
#   6. Launch the built web app + headless-Chrome (Playwright) checks:
#        - loads without runtime errors (console/pageerror capture)
#        - navigates splash → login → otp → home
#        - verifies key UI elements per screen
#        - captures a screenshot per screen
#   Artifacts (screenshots + logs) land in $ARTIFACTS_DIR (default: build/verify/).
#
# Usage:
#   ./verify_flutter.sh [app_dir]
#
# Env:
#   FLUTTER_HOME  — Flutter SDK location (default: /tmp/flutter)
#   ARTIFACTS_DIR — output for screenshots/logs (default: <app>/build/verify)
#   SKIP_BROWSER  — set to 1 to run only stages 1–5 (no Chrome checks)
# ============================================================================
set -euo pipefail

APP_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
FLUTTER_HOME="${FLUTTER_HOME:-/tmp/flutter}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$APP_DIR/build/verify}"

# ---------------------------------------------------------------------------
# Flutter SDK bootstrap.
# /tmp is wiped between sandbox sessions, so the SDK does not survive. To
# keep reinstall fast, in priority order:
#   1. an already-extracted SDK at $FLUTTER_HOME,
#   2. stream download straight into tar (fast Tencent mirror, then the
#      official Google host) — ~90s on the mirror,
#   3. a chunked copy of the tarball under
#      /mnt/agents/tools/flutter-sdk-parts/ (90MB parts because the /mnt
#      portal FS rejects single files >100MiB; reads paced with backoff
#      because the mount drops under fast bulk reads).
# ---------------------------------------------------------------------------
FLUTTER_VERSION="3.47.1"
PARTS_DIR="${FLUTTER_PARTS_DIR:-/mnt/agents/tools/flutter-sdk-parts}"
MIRROR_URL="https://mirrors.cloud.tencent.com/flutter/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
OFFICIAL_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

bootstrap_flutter() {
  if [ -x "$FLUTTER_HOME/bin/flutter" ]; then return 0; fi
  echo "Flutter SDK not found at $FLUTTER_HOME — bootstrapping..."
  rm -rf "$FLUTTER_HOME"

  # 2) fast path: stream download straight into tar (no big intermediate file).
  #    Fast mirror first (~90s), official host as fallback (slow but reliable).
  for url in "$MIRROR_URL" "$OFFICIAL_URL"; do
    echo "  streaming $url ..."
    if curl -sL --retry 2 "$url" | (cd /tmp && tar xJ); then
      [ -x "$FLUTTER_HOME/bin/flutter" ] && return 0
    fi
    echo "  this source failed, trying next"
  done

  # 3) last resort: reassemble persisted 90MB parts from the /mnt mount.
  #    The portal FS rate-limits bulk reads (~450MB bursts), so reads are
  #    paced per part with backoff.
  if ls "$PARTS_DIR"/part-* >/dev/null 2>&1; then
    echo "  reassembling SDK from $PARTS_DIR (paced) ..."
    local tarball=/tmp/flutter-bootstrap.tar.xz
    : > "$tarball"
    local ok=1
    for p in "$PARTS_DIR"/part-*; do
      local want before after attempt
      want=$(stat -c %s "$p")
      for attempt in 1 2 3 4 5 6 7 8; do
        before=$(stat -c %s "$tarball" 2>/dev/null || echo 0)
        dd if="$p" of="$tarball" bs=1M iflag=fullblock oflag=append conv=notrunc 2>/dev/null
        after=$(stat -c %s "$tarball" 2>/dev/null || echo 0)
        [ $((after-before)) -eq "$want" ] && break
        truncate -s "$before" "$tarball"; sleep 25
      done
      [ $((after-before)) -eq "$want" ] || { ok=0; break; }
      sleep 2
    done
    if [ "$ok" = 1 ] && (cd /tmp && tar xf "$tarball"); then
      rm -f "$tarball"
      [ -x "$FLUTTER_HOME/bin/flutter" ] && return 0
    fi
    echo "  part assembly failed"
  fi

  echo "ERROR: could not bootstrap Flutter SDK" >&2
  return 1
}

bootstrap_flutter
export PATH="$FLUTTER_HOME/bin:$PATH"
mkdir -p "$ARTIFACTS_DIR"

echo "== 1. flutter --version =="
flutter --version | tee "$ARTIFACTS_DIR/flutter-version.log"

echo "== 2. flutter pub get =="
(cd "$APP_DIR" && flutter pub get) 2>&1 | tee "$ARTIFACTS_DIR/pub-get.log"

echo "== 3. flutter analyze =="
(cd "$APP_DIR" && flutter analyze) 2>&1 | tee "$ARTIFACTS_DIR/analyze.log"

echo "== 4. flutter test =="
(cd "$APP_DIR" && flutter test) 2>&1 | tee "$ARTIFACTS_DIR/test.log"

echo "== 5. flutter build web =="
# Point the dev build at the mock E2.3 backend started by verify_browser.py
# (stage 6), so browser checks exercise real HTTP auth round-trips.
(cd "$APP_DIR" && flutter build web --release \
  --dart-define=FLAVOR=dev --dart-define=API_BASE=http://localhost:18086) \
  2>&1 | tee "$ARTIFACTS_DIR/build-web.log"

if [ "${SKIP_BROWSER:-0}" = "1" ]; then
  echo "== 6. browser checks SKIPPED (SKIP_BROWSER=1) =="
  echo "ALL FLUTTER STAGES PASSED (browser checks skipped)"
  exit 0
fi

echo "== 6. browser verification (headless Chrome via Playwright) =="

# Serve the built app.
PORT=18085
(cd "$APP_DIR/build/web" && python3 -m http.server "$PORT" \
  > "$ARTIFACTS_DIR/http-server.log" 2>&1) &
HTTP_PID=$!
trap 'kill $HTTP_PID 2>/dev/null || true' EXIT

# Wait for the server.
for i in $(seq 1 30); do
  curl -sf "http://localhost:$PORT/" > /dev/null 2>&1 && break
  sleep 1
done

APP_URL="http://localhost:$PORT/" ARTIFACTS_DIR="$ARTIFACTS_DIR" \
python3 "$(dirname "$0")/verify_browser.py"

echo "ALL FLUTTER VERIFICATION STAGES PASSED"
echo "Artifacts: $ARTIFACTS_DIR"
