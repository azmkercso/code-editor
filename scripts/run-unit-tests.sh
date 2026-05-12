#!/bin/bash

set -e

echo "INFO: Running Code Editor Unit Tests"

PROJ_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$PROJ_ROOT"

# Default target; pass 'all' to run all targets
TARGET="${1:-all}"

run_target() {
    local target="$1"
    local src_dir="$PROJ_ROOT/code-editor-src-$target"

    if [ ! -d "$src_dir" ]; then
        echo "INFO: Preparing source for $target..."
        PATCHED_SRC_DIR="$src_dir" ./scripts/prepare-src.sh "$target"
    fi

    echo "Running tests for: $target"
    cd "$PROJ_ROOT/unit-tests"
    PATCHED_SRC_DIR="$src_dir" TARGET="$target" npm run "test:$target"
}

# Install and build tests
cd unit-tests
npm ci --quiet
npm run build
cd "$PROJ_ROOT"

if [ "$TARGET" = "all" ]; then
    for t in code-editor-sagemaker-server code-editor-server code-editor-web-embedded code-editor-web-embedded-with-terminal; do
        run_target "$t"
    done
else
    run_target "$TARGET"
fi
