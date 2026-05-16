#!/usr/bin/env bash
# quilt-env.sh — source this to configure quilt environment for a patch layer.
#
# Usage:
#   source ./scripts/quilt-env.sh <layer> [target]
#
# Layers:
#   patches       — production patches (.pc directory)
#   test-patches  — test patches (.pc-test directory)
#
# Target defaults to code-editor-sagemaker-server.
#
# After sourcing, QUILT_PATCHES, QUILT_SERIES, and QUILT_PC are set (or unset).
# The working directory for quilt commands is code-editor-src/.

_QUILT_ENV_LAYER="${1:-patches}"
_QUILT_ENV_TARGET="${2:-code-editor-sagemaker-server}"
_QUILT_ENV_ROOT="${_QUILT_ENV_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
_QUILT_ENV_CONFIG="${_QUILT_ENV_ROOT}/configuration/${_QUILT_ENV_TARGET}.json"

if [[ ! -f "$_QUILT_ENV_CONFIG" ]]; then
    echo "quilt-env.sh: configuration not found: $_QUILT_ENV_CONFIG" >&2
    return 1 2>/dev/null || exit 1
fi

case "$_QUILT_ENV_LAYER" in
    patches)
        export QUILT_PATCHES="${_QUILT_ENV_ROOT}/patches"
        export QUILT_SERIES="${_QUILT_ENV_ROOT}/$(jq -r '.patches.path' "$_QUILT_ENV_CONFIG")"
        unset QUILT_PC
        ;;
    test-patches)
        _test_path="$(jq -r '.testPatches.path' "$_QUILT_ENV_CONFIG")"
        if [[ "$_test_path" == "null" || -z "$_test_path" ]]; then
            echo "quilt-env.sh: no testPatches.path configured for $_QUILT_ENV_TARGET" >&2
            return 1 2>/dev/null || exit 1
        fi
        export QUILT_PATCHES="${_QUILT_ENV_ROOT}/patches/test"
        export QUILT_SERIES="${_QUILT_ENV_ROOT}/$_test_path"
        export QUILT_PC=.pc-test
        unset _test_path
        ;;
    *)
        echo "quilt-env.sh: unknown layer '$_QUILT_ENV_LAYER' (use: patches, test-patches)" >&2
        return 1 2>/dev/null || exit 1
        ;;
esac

unset _QUILT_ENV_LAYER _QUILT_ENV_TARGET _QUILT_ENV_ROOT _QUILT_ENV_CONFIG
