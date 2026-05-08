#!/usr/bin/env bash
# Replaces all sha256 values within script-src CSP directives with a single
# __INLINE_SCRIPT_SHA__ placeholder. Only touches content between 'script-src'
# and the next ';'. The placeholder is resolved by update_inline_sha in
# prepare-src.sh after all patches are applied.
#
# Usage: ./scripts/patches/replace-inline-sha-with-placeholder.sh <file> [<file>...]

set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <file> [<file>...]" >&2
    exit 1
fi

for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        echo "Skipping (not found): $file"
        continue
    fi
    if grep -q "'__INLINE_SCRIPT_SHA__'" "$file"; then
        echo "Already has placeholder: $file"
        continue
    fi
    if ! grep -q "script-src.*'sha256-" "$file"; then
        echo "No sha256 in script-src: $file"
        continue
    fi
    # Use perl to replace all 'sha256-...' within script-src...;  with one placeholder
    perl -i -pe "
        s{(script-src\b)(.*?)(;)}{
            my (\$pre, \$mid, \$end) = (\$1, \$2, \$3);
            \$mid =~ s/'sha256-[A-Za-z0-9+\\/=]+'/'__INLINE_SCRIPT_SHA__'/;
            \$mid =~ s/\\s*'sha256-[A-Za-z0-9+\\/=]+'//g;
            \"\$pre\$mid\$end\"
        }ge
    " "$file"
    echo "Replaced SHA with placeholder: $file"
done
