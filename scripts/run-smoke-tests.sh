#!/bin/bash
# Run Code Editor smoke tests locally against a pre-built server.
#
# Prerequisites:
#   - Build artifacts at vscode-reh-web-linux-x64/ (run a dev-build first)
#   - Patched source at code-editor-src/ (from prepare-src.sh)
#   - System: node 22+, npm, quilt, curl, chromium-compatible OS
#
# Usage:
#   ./scripts/run-smoke-tests.sh [--skip-prepare] [--grep <pattern>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/vscode-reh-web-linux-x64"
SRC_DIR="$ROOT_DIR/code-editor-src"
SERVER_PORT=9888
SERVER_PID=""
SKIP_PREPARE=false
GREP_PATTERN=""

for arg in "$@"; do
  case "$arg" in
    --skip-prepare) SKIP_PREPARE=true ;;
    --grep) shift; GREP_PATTERN="$1" ;;
    *) ;;
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
  echo ""
  echo "Run a dev-build of the sagemaker target first:"
  echo "  ./scripts/prepare-src.sh code-editor-sagemaker-server"
  echo "  cd code-editor-src && npm ci && npm run gulp vscode-reh-web-linux-x64"
  exit 1
fi

if [ ! -f "$SRC_DIR/product.json" ]; then
  echo "ERROR: Patched source not found at code-editor-src/"
  echo ""
  echo "Run prepare-src.sh first:"
  echo "  ./scripts/prepare-src.sh code-editor-sagemaker-server"
  exit 1
fi

# --- Apply test patches ---

if [ "$SKIP_PREPARE" = false ]; then
  echo "=== Applying test patches ==="
  cd "$SRC_DIR"
  rm -rf .pc
  export QUILT_PATCHES=../patches/test
  export QUILT_SERIES=../patches/test/sagemaker-testing.series
  quilt push -a
fi

# --- Install dependencies and compile ---

echo "=== Installing dependencies ==="
cd "$SRC_DIR"

# Root deps (includes typescript, playwright-core, mocha)
npm ci 2>&1 | tail -3

# Install playwright browsers
npm run playwright-install

# Compile smoke tests (compiles automation + smoke via upstream script)
echo "=== Compiling smoke tests ==="
cd test/smoke
npm install
npm run compile

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
  node test/index.js --web --headless $EXTRA_ARGS

echo "=== All smoke tests passed ==="
