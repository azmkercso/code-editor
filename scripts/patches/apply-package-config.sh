#!/usr/bin/env bash
# apply-package-config.sh — Remove unwanted dependencies from package.json files.
#
# @generated
# @generator: scripts/patches/apply-package-config.sh
#
# Usage:
#   ./scripts/patches/apply-package-config.sh [code-editor-src-dir]
#
# Removes kerberos (any version) and its overrides from package.json and
# remote/package.json.
set -euo pipefail

SRC_DIR="${1:-code-editor-src}"

jq_inplace() {
    local filter="$1" file="$2"
    jq --tab "$filter" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

remove_kerberos() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Warning: $file not found, skipping" >&2
        return
    fi
    jq_inplace '
        del(.dependencies.kerberos) |
        .overrides |= (if . then with_entries(select(.key | startswith("kerberos") | not)) else . end)
    ' "$file"
}

remove_kerberos "$SRC_DIR/package.json"
remove_kerberos "$SRC_DIR/remote/package.json"

echo "package.json files updated successfully"
