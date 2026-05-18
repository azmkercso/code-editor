#!/bin/bash
# Run Code Editor extension integration tests against the compiled patched source.
#
# This compiles the source tree (server + extensions) and runs the upstream
# test-web-integration.sh which launches a dev server and exercises extension
# APIs via Playwright in a headless browser.
#
# Prerequisites:
#   - Patched source at code-editor-src/ (run prepare-src.sh first)
#   - node_modules installed (npm ci inside Docker)
#   - System: node 22+, npm, chromium-compatible browser deps
#
# Usage:
#   ./scripts/run-integ-tests.sh [OPTIONS]
#
# Options:
#   --skip-compile    Skip source compilation (use if already compiled)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$ROOT_DIR/code-editor-src"
SKIP_COMPILE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-compile) SKIP_COMPILE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Check prerequisites ---

if [ ! -d "$SRC_DIR/node_modules" ] && [ "$SKIP_COMPILE" = true ]; then
  echo "ERROR: node_modules not found in code-editor-src/ and --skip-compile is set"
  echo "Run: cd code-editor-src && npm ci"
  exit 1
fi

# --- Install dependencies if needed ---

if [ "$SKIP_COMPILE" = false ] && [ ! -d "$SRC_DIR/node_modules" ]; then
  cd "$SRC_DIR"
  echo "=== Installing dependencies ==="
  npm ci
fi

# --- Compile source + extensions ---

if [ "$SKIP_COMPILE" = false ]; then
  cd "$SRC_DIR"
  echo "=== Compiling source ==="
  npm run gulp -- compile

  echo "=== Compiling extensions ==="
  npm run gulp -- compile-extensions

  echo "=== Installing Playwright ==="
  npx playwright install chromium

  echo "=== Compiling integration test runner ==="
  cd test/integration/browser
  npm run compile
fi

# --- Run integration tests ---

echo "=== Running extension integration tests ==="
cd "$SRC_DIR"
./scripts/test-web-integration.sh
