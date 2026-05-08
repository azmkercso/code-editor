#!/bin/bash
# Run Code Editor smoke tests locally against a pre-built server.
#
# Prerequisites:
#   - Build artifacts at vscode-reh-web-linux-x64/ (run a dev-build first)
#   - Patched source at code-editor-src/ with dependencies installed
#   - System: node 22+, npm, quilt, curl, chromium-compatible browser deps
#
# Usage:
#   ./scripts/run-smoke-tests.sh [OPTIONS]
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-patches) SKIP_PATCHES=true; shift ;;
    --skip-compile) SKIP_COMPILE=true; shift ;;
    --grep) GREP_PATTERN="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

cleanup() {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# --- Check prerequisites ---

if [ ! -f "$BUILD_DIR/bin/code-editor-server" ]; then
  echo "ERROR: Build artifacts not found at vscode-reh-web-linux-x64/"
  echo "Run a dev-build first."
  exit 1
fi

if [ ! -d "$SRC_DIR/node_modules" ]; then
  echo "ERROR: node_modules not found in code-editor-src/"
  echo "Run: ./scripts/build-artifacts.sh --dev <target>"
  exit 1
fi

# --- Apply test patches ---

if [ "$SKIP_PATCHES" = false ]; then
  echo "=== Applying test patches ==="
  cd "$SRC_DIR"
  # Pop any existing test patches
  source "$SCRIPT_DIR/quilt-env.sh" test-patches code-editor-sagemaker-server
  quilt pop -af 2>/dev/null || true
  rm -rf .pc-test
  # Restore files modified by test patches to upstream state
  THIRD_PARTY="$ROOT_DIR/third-party-src"
  if [ -d "$THIRD_PARTY/test" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      src="$THIRD_PARTY/$f"
      dst="$SRC_DIR/$f"
      if [ -f "$src" ]; then
        cp "$src" "$dst"
      else
        rm -f "$dst"
      fi
    done < <(grep -h "^Index:" "$ROOT_DIR"/patches/test/*.diff "$ROOT_DIR"/patches/test/sagemaker/*.diff 2>/dev/null | sed 's|^Index: code-editor-src/||')
  fi
  # Apply test patches
  quilt push -a
fi

# --- Install Playwright and compile ---

if [ "$SKIP_COMPILE" = false ]; then
  cd "$SRC_DIR"

  # Install Playwright browser + system deps
  echo "=== Installing Playwright ==="
  npx playwright install --with-deps chromium

  # Compile smoke tests (compiles test/automation + test/smoke)
  echo "=== Compiling smoke tests ==="
  cd test/smoke
  npm install 2>&1 | tail -3
  npm run compile
fi

# --- Start server ---

echo "=== Starting Code Editor server ==="
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

echo "=== Running smoke tests ==="
cd "$SRC_DIR/test/smoke"

EXTRA_ARGS=""
if [ -n "$GREP_PATTERN" ]; then
  EXTRA_ARGS="--grep $GREP_PATTERN"
fi

VSCODE_REMOTE_SERVER_PATH="$BUILD_DIR" \
  CODE_EDITOR_TARGET=code-editor-sagemaker-server \
  node test/index.js --web --headless $EXTRA_ARGS

echo "=== Smoke tests complete ==="
