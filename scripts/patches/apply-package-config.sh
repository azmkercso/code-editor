#!/usr/bin/env bash
# apply-package-config.sh — Remove unwanted dependencies from package.json files.
#
# @generated
# @generator: scripts/patches/apply-package-config.sh
#
# Usage:
#   ./scripts/patches/apply-package-config.sh [code-editor-src-dir]
#
# Removes unused dependencies from package.json and remote/package.json:
# - kerberos: cannot compile on the Brazil fleet
# - kerberos overrides block: no longer needed without kerberos
# - @github/copilot: Copilot features are disabled in Code Editor
set -euo pipefail

SRC_DIR="${1:-code-editor-src}"

remove_line() {
    local file="$1" pattern="$2"
    [[ -f "$file" ]] && sed -i "\|${pattern}|d" "$file"
}

# Remove kerberos override block ("kerberos@2.1.1": { "node-addon-api": "7.1.0" },)
remove_kerberos_override() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    sed -i '\|"kerberos@|{N;N;d}' "$file"
}

for file in "$SRC_DIR/package.json" "$SRC_DIR/remote/package.json"; do
    [[ -f "$file" ]] || continue
    remove_line "$file" '"kerberos":'
    remove_line "$file" '"@github/copilot":'
    remove_kerberos_override "$file"
    python3 -c "import json; json.load(open('$file'))" || { echo "ERROR: $file is invalid JSON" >&2; exit 1; }
done

echo "package.json files updated successfully"
