#!/bin/bash
# Run Code Editor smoke tests locally against a pre-built server target.
#
# Supported targets (reh-web server architecture):
#   - code-editor-sagemaker-server (default)
#   - code-editor-server
#
# Prerequisites:
#   - Build artifacts at vscode-reh-web-linux-x64/ (run a dev-build first)
#   - Patched source at code-editor-src/ with dependencies installed
#   - System: node 22+, npm, quilt, curl, chromium-compatible browser deps
#
# Usage:
#   ./scripts/run-smoke-tests.sh [OPTIONS] [TARGET]
#
# Options:
#   --skip-patches    Skip applying test patches (use if already applied)
#   --skip-compile    Skip compiling smoke tests (use if already compiled)
#   --grep PATTERN    Only run tests matching PATTERN

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/vscode-reh-web-linux-x64"
SRC_DIR="$ROOT_DIR/code-editor-src"
SERVER_PORT=9888
SERVER_PID=""
SKIP_PATCHES=false
SKIP_COMPILE=false
GREP_PATTERN=""
TARGET="${CODE_EDITOR_TARGET:-code-editor-sagemaker-server}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-patches) SKIP_PATCHES=true; shift ;;
    --skip-compile) SKIP_COMPILE=true; shift ;;
    --grep) GREP_PATTERN="$2"; shift 2 ;;
    code-editor-server|code-editor-sagemaker-server) TARGET="$1"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

export CODE_EDITOR_TARGET="$TARGET"

cleanup() {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# --- Check prerequisites ---

if [ ! -f "$BUILD_DIR/bin/code-editor-server" ]; then
  echo "ERROR: Build artifacts not found at $BUILD_DIR/bin/code-editor-server"
  echo "Run a dev-build first."
  exit 1
fi

if [ ! -d "$SRC_DIR/node_modules" ]; then
  echo "ERROR: node_modules not found in code-editor-src/"
  echo "Run: cd code-editor-src && npm ci"
  exit 1
fi

# --- Apply test patches ---

if [ "$SKIP_PATCHES" = false ]; then
  echo "=== Applying test patches ==="
  cd "$SRC_DIR"
  if [ -d .pc ]; then
    QUILT_PATCHES=../patches/test QUILT_SERIES=common-testing.series quilt pop -af 2>/dev/null || true
    rm -rf .pc
  fi
  # Restore files modified by test patches
  THIRD_PARTY="$ROOT_DIR/third-party-src"
  if [ -d "$THIRD_PARTY/test" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      src="$THIRD_PARTY/$f"
      dst="$SRC_DIR/$f"
      if [ -f "$src" ]; then cp "$src" "$dst"; else rm -f "$dst"; fi
    done < <(grep -rh "^Index:" "$ROOT_DIR"/patches/test/common/*.diff 2>/dev/null | sed 's|^Index: code-editor-src/||')
  fi
  export QUILT_PATCHES=../patches/test
  export QUILT_SERIES=common-testing.series
  quilt push -a
fi

# --- Install Playwright and compile ---

if [ "$SKIP_COMPILE" = false ]; then
  cd "$SRC_DIR"
  echo "=== Installing Playwright ==="
  npx playwright install --with-deps chromium
  echo "=== Compiling smoke tests ==="
  cd test/smoke
  npm install 2>&1 | tail -3
  npm run compile
fi

# --- Start server ---

echo "=== Starting Code Editor server (target: $TARGET) ==="
cd "$ROOT_DIR"
"$BUILD_DIR/bin/code-editor-server" \
  --without-connection-token --accept-server-license-terms \
  --host 0.0.0.0 --port "$SERVER_PORT" \
  --enable-smoke-test-driver --disable-workspace-trust > /tmp/smoke-server.log 2>&1 &
SERVER_PID=$!

for i in $(seq 1 15); do
  if curl -s "http://localhost:$SERVER_PORT/healthz" > /dev/null 2>&1; then
    echo "Server ready after ${i}s (PID $SERVER_PID)"
    break
  fi
  sleep 1
done

if ! curl -s "http://localhost:$SERVER_PORT/healthz" > /dev/null 2>&1; then
  echo "ERROR: Server failed to start. Log:"
  tail -20 /tmp/smoke-server.log
  exit 1
fi

# --- Run smoke tests ---

echo "=== Running smoke tests (target: $TARGET) ==="
cd "$SRC_DIR/test/smoke"

EXTRA_ARGS=""
if [ -n "$GREP_PATTERN" ]; then
  EXTRA_ARGS="--grep $GREP_PATTERN"
fi

VSCODE_REMOTE_SERVER_PATH="$BUILD_DIR" \
  node test/index.js --web --headless $EXTRA_ARGS

echo "=== Smoke tests complete ==="
