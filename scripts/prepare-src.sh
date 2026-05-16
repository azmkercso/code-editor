#!/usr/bin/env bash

set -euo pipefail

PRESENT_WORKING_DIR="$(pwd)"
# Manually update this list to include all files for which there are modified script-src CSP rules
UPDATE_CHECKSUM_FILEPATHS=(
    "/src/vs/workbench/contrib/webview/browser/pre/index.html"
    "/src/vs/workbench/contrib/webview/browser/pre/index-no-csp.html"
    "/src/vs/workbench/services/extensions/worker/webWorkerExtensionHostIframe.html"
)

# ---------------------------------------------------------------------------
# Quilt environment helper
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

setup_quilt_layer() {
    local layer="$1"
    source "$SCRIPT_DIR/quilt-env.sh" "$layer" "$TARGET"
}

# ---------------------------------------------------------------------------
# SHA calculation
# ---------------------------------------------------------------------------

calc_script_SHAs() {
    local filepath="$1"
    
    if [[ ! -f "$filepath" ]]; then
        return 1
    fi
    
    local script_count
    script_count=$(xmllint --html --xpath "count(//script)" "$filepath" 2>/dev/null || echo "0")
    
    if [[ "$script_count" != "1" ]]; then
        if [[ "$script_count" == "0" ]]; then
            echo "No script tags found"
        else
            echo "Multiple script tags found ($script_count). Only single script updates are supported."
        fi
        return 0
    fi
    
    local script_content
    script_content=$(xmllint --html --xpath "//script[1]/text()" "$filepath" 2>/dev/null || true)
    
    if [[ "$script_content" == *"<![CDATA["* ]]; then
        script_content="${script_content#*<![CDATA[}"
        script_content="${script_content%]]>*}"
    fi
    
    if [[ -z "$script_content" ]]; then
        echo "Script tag found but no content"
        return 0
    fi
    
    local hash=$(printf '%s' "$script_content" | openssl dgst -sha256 -binary | base64)
    local new_sha="'sha256-$hash'"
    
    if grep -q "'__INLINE_SCRIPT_SHA__'" "$filepath"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|'__INLINE_SCRIPT_SHA__'|$new_sha|g" "$filepath"
        else
            sed -i "s|'__INLINE_SCRIPT_SHA__'|$new_sha|g" "$filepath"
        fi
        echo "Updated SHA in $filepath"
    elif grep -q "'sha256-" "$filepath"; then
        # Replace existing SHA-256 hash in CSP meta tag
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|'sha256-[A-Za-z0-9+/=]*'|$new_sha|g" "$filepath"
        else
            sed -i "s|'sha256-[A-Za-z0-9+/=]*'|$new_sha|g" "$filepath"
        fi
        echo "Updated existing SHA in $filepath"
    fi
    
    echo "$new_sha"
    return 0
}

# ---------------------------------------------------------------------------
# Quilt state checks
# ---------------------------------------------------------------------------

check_unsaved_changes() {
    local layer="${1:-patches}"

    setup_quilt_layer "$layer" 2>/dev/null || return 0
    
    if [[ ! -d "${PATCHED_SRC_DIR}" ]]; then
        return
    fi
    
    pushd "${PATCHED_SRC_DIR}" > /dev/null
    
    local applied_output
    applied_output=$(quilt applied 2>/dev/null || true)

    if [[ -z "$applied_output" ]]; then
        popd > /dev/null
        return
    fi
    
    local diff_output
    diff_output=$(quilt diff -z 2>/dev/null || true)

    if [[ -n "$diff_output" ]]; then
        popd > /dev/null
        echo "Error: You have unsaved changes in the current patch ($layer layer)."
        echo "Run 'quilt refresh' to update the patch with your changes."
        echo "Please refresh or revert your changes before rebasing again"
        exit 1
    fi
    
    popd > /dev/null
}

# ---------------------------------------------------------------------------
# Source preparation
# ---------------------------------------------------------------------------

prepare_patch_directory() {
    echo "Cleaning build src dir"
    rm -rf "${PATCHED_SRC_DIR}"
    
    echo "Copying third party source to the patch directory"
    rsync -a "${PRESENT_WORKING_DIR}/third-party-src/" "${PATCHED_SRC_DIR}"

    # Remove extensions not part of Code Editor distribution
    rm -rf "${PATCHED_SRC_DIR}/extensions/copilot"
}

apply_patches_layer() {
    local layer="$1"
    echo "Applying $layer"
    setup_quilt_layer "$layer"
    pushd "${PATCHED_SRC_DIR}" > /dev/null
    quilt push -a
    popd > /dev/null
}

apply_overrides() {
    local overrides_path=$(jq -r '.overrides.path' "$CONFIG_FILE")
    local package_lock_path=$(jq -r '."package-lock-overrides".path' "$CONFIG_FILE")
    
    echo "Applying overrides"
    rsync -a "${PRESENT_WORKING_DIR}/$overrides_path/" "${PATCHED_SRC_DIR}"

    echo "Applying package-lock overrides"
    if [[ "$RESET_LOCKFILES" == "true" ]]; then
        echo "Skipping package-lock overrides (--reset-lockfiles)"
    else
        rsync -a "${PRESENT_WORKING_DIR}/$package_lock_path/" "${PATCHED_SRC_DIR}"
    fi
}

update_inline_sha() {
    echo "Running calculate SHA script"

    if [[ ! -d "${PATCHED_SRC_DIR}" ]]; then
        echo "Error: PATCHED_SRC_DIR (${PATCHED_SRC_DIR}) does not exist."
        return 1
    fi
    
    for file_path in "${UPDATE_CHECKSUM_FILEPATHS[@]}"; do
        local full_path="$PATCHED_SRC_DIR$file_path"
        local sha_result
        
        if [[ -f "$full_path" ]]; then
            echo -n "$file_path: "
            sha_result=$(calc_script_SHAs "$full_path")
            echo "$sha_result"
        else
            echo "$file_path: not found"
        fi
    done
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

prepare_src() {
    echo "Creating patched source in directory: ${PATCHED_SRC_DIR}"
    prepare_patch_directory
    apply_patches_layer patches
    apply_overrides

    if [[ "$INCLUDE" == "test-patches" || "$INCLUDE" == "all" ]]; then
        local test_patches_path=$(jq -r '.testPatches.path' "$CONFIG_FILE")
        if [[ "$test_patches_path" == "null" || -z "$test_patches_path" ]]; then
            echo "No test-patches path configured for this target, skipping"
        else
            apply_patches_layer test-patches
        fi
    fi
}

rebase_patches() {
    echo "Creating patched source in directory: ${PATCHED_SRC_DIR}"

    # Rebase production patches
    check_unsaved_changes patches
    prepare_patch_directory
    setup_quilt_layer patches
    rebase
    apply_overrides

    # Rebase test patches if included
    if [[ "$INCLUDE" == "test-patches" || "$INCLUDE" == "all" ]]; then
        local test_patches_path=$(jq -r '.testPatches.path' "$CONFIG_FILE")
        if [[ "$test_patches_path" == "null" || -z "$test_patches_path" ]]; then
            echo "No test-patches path configured for this target, skipping test rebase"
        else
            echo ""
            echo "Rebasing test patches..."
            check_unsaved_changes test-patches
            setup_quilt_layer test-patches
            rebase
        fi
    fi
}

# ---------------------------------------------------------------------------
# Rebase engine
# ---------------------------------------------------------------------------

parse_conflict_files() {
    printf '%s\n' "$1" | grep -A1 "^patching file" | grep -B1 "NOT MERGED" | grep "^patching file" | sed 's/^patching file //'
}

parse_missing_files() {
    printf '%s\n' "$1" | grep -A5 "can't find file to patch" | grep "^|Index:" | sed 's/^|Index: //' | sort -u
}

# Patch metadata helpers
patch_has_meta() {
    local patch_file="$1"
    local key="$2"
    [[ -f "$patch_file" ]] || return 1
    sed '/^Index:\|^---.*\//q' "$patch_file" | grep -q "^${key}" 2>/dev/null
}

get_patch_meta() {
    local patch_file="$1"
    local key="$2"
    [[ -f "$patch_file" ]] || return 1
    sed '/^Index:\|^---.*\//q' "$patch_file" | grep "^${key}:" | head -1 | sed "s/^${key}:[[:space:]]*//"
}

get_upstream_version() {
    local pkg_json="${PRESENT_WORKING_DIR}/third-party-src/package.json"
    if [[ -f "$pkg_json" ]]; then
        jq -r '.version' "$pkg_json"
    else
        echo "0.0.0"
    fi
}

version_gte() {
    local v1="$1"
    local v2="$2"
    local sorted
    sorted=$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | head -1)
    [[ "$sorted" == "$v2" ]]
}

rebase() {
    echo "Rebasing patches one by one..."
    pushd "${PATCHED_SRC_DIR}" > /dev/null

    local removed_patches=()

    while quilt next >/dev/null 2>&1; do
        local next_patch
        next_patch=$(quilt next)

        local patch_file="${QUILT_PATCHES}/${next_patch}"

        # --- Backported patch: auto-remove if upstream version >= @remove-after ---
        if patch_has_meta "$patch_file" "@backported" && patch_has_meta "$patch_file" "@remove-after"; then
            local remove_after
            remove_after=$(get_patch_meta "$patch_file" "@remove-after")
            local upstream_version
            upstream_version=$(get_upstream_version)
            if version_gte "$upstream_version" "$remove_after"; then
                echo "Auto-removing expired backported patch: $next_patch (upstream $upstream_version >= $remove_after)"
                quilt delete -n "$next_patch"
                removed_patches+=("$next_patch")
                continue
            fi
        fi

        # --- Generated patch: try apply, then regenerate on conflict ---
        if patch_has_meta "$patch_file" "@generated"; then
            set +e
            local output
            output=$(quilt push -f -m 2>&1)
            local exit_code=$?
            set -e
            echo "$output"

            if [[ $exit_code -eq 0 ]]; then
                echo "Successfully applied generated patch: $(quilt top)"
                quilt refresh
                continue
            fi

            local generator
            generator=$(get_patch_meta "$patch_file" "@generator" || true)
            if [[ -n "$generator" ]]; then
                echo ""
                echo "Generated patch failed to apply, regenerating: $next_patch"
                quilt pop -f 2>/dev/null || true

                set +e
                # Security: only allow generators under scripts/patches/
                if [[ ! "$generator" =~ ^scripts/patches/[a-zA-Z0-9_-]+\.sh(\ .*)?$ ]]; then
                    echo "ERROR: @generator must reference scripts/patches/*.sh — refusing to execute: $generator"
                    popd > /dev/null
                    exit 1
                fi
                (cd "$PRESENT_WORKING_DIR" && $generator) 2>&1
                local regen_code=$?
                set -e

                if [[ $regen_code -eq 0 ]]; then
                    set +e
                    output=$(quilt push 2>&1)
                    exit_code=$?
                    set -e
                    echo "$output"
                    if [[ $exit_code -eq 0 ]]; then
                        echo "Successfully applied regenerated patch: $(quilt top)"
                        quilt refresh
                        continue
                    fi
                fi
                echo "Regeneration failed for: $next_patch"
            else
                echo "Generated patch failed and no @generator found: $next_patch"
            fi

            local conflict_files
            local missing_files
            conflict_files=($(parse_conflict_files "$output" || true))
            missing_files=($(parse_missing_files "$output" || true))

            if [[ ${#conflict_files[@]} -gt 0 ]]; then
                echo ""
                echo "Files with conflicts:"
                for file in "${conflict_files[@]}"; do
                    echo "- $PATCHED_SRC_DIR/$file"
                done
            fi

            echo ""
            echo "Required actions:"
            echo "1. Regenerate the patch manually"
            echo "2. Then run the prepare-src script again to continue"
            echo ""
            popd > /dev/null
            exit 1
        fi

        # --- Standard path: apply with force, halt on conflict ---
        local output
        set +e
        output=$(quilt push -f -m 2>&1)
        local exit_code=$?
        set -e
        
        echo "$output"
        
        local conflict_files
        local missing_files
        conflict_files=($(parse_conflict_files "$output" || true))
        missing_files=($(parse_missing_files "$output" || true))
        
        if [[ $exit_code -eq 0 ]]; then
            echo "Successfully applied patch: $(quilt top)"
            quilt refresh
        else
            if [[ ${#conflict_files[@]} -gt 0 ]]; then
                echo ""
                echo "Files with conflicts:"
                for file in "${conflict_files[@]}"; do
                    echo "- $PATCHED_SRC_DIR/$file"
                done
            fi
            
            if [[ ${#missing_files[@]} -gt 0 ]]; then
                echo ""
                echo "Missing files:"
                for file in "${missing_files[@]}"; do
                    echo "- $file"
                done
            fi
            
            echo ""
            echo "Required actions:"
            echo "1. Edit the files to resolve any conflicts"
            echo "2. Run 'quilt refresh' to update the patch"
            echo "3. Then run the prepare-src script again to continue"
            echo ""
            popd > /dev/null
            exit 1
        fi
        
    done

    if [[ ${#removed_patches[@]} -gt 0 ]]; then
        echo ""
        echo "Auto-removed ${#removed_patches[@]} expired patch(es):"
        for p in "${removed_patches[@]}"; do
            echo "  - $p"
        done
        echo "Remember to commit the updated series file(s) and remove the .diff file(s)."
    fi
    
    echo "All patches applied successfully"
    popd > /dev/null
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

COMMAND="prepare_src"
TARGET="code-editor-sagemaker-server"
RESET_LOCKFILES=false
INCLUDE="patches"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --command)
            [[ $# -ge 2 ]] || { echo "--command requires a value" >&2; exit 1; }
            COMMAND="$2"
            shift 2
            ;;
        --include)
            [[ $# -ge 2 ]] || { echo "--include requires a value" >&2; exit 1; }
            INCLUDE="$2"
            shift 2
            ;;
        --reset-lockfiles)
            RESET_LOCKFILES=true
            shift
            ;;
        -*)
            echo "Unknown option $1" >&2
            exit 1
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

PATCHED_SRC_DIR="${PATCHED_SRC_DIR:-$PRESENT_WORKING_DIR/code-editor-src}"
CONFIG_FILE="$PRESENT_WORKING_DIR/configuration/$TARGET.json"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Validate --include
case "$INCLUDE" in
    patches|test-patches|all) ;;
    *)
        echo "Error: --include must be one of: patches, test-patches, all" >&2
        exit 1
        ;;
esac

echo "Using configuration: $CONFIG_FILE"
echo "Preparing source for target: $TARGET (include: $INCLUDE)"
case "$COMMAND" in
    prepare_src)
        prepare_src
        update_inline_sha
        ;;
    rebase_patches)
        echo "Rebase mode enabled"
        rebase_patches
        ;;
    *)
        echo "Unknown command: $COMMAND" >&2
        echo "Available commands: prepare_src, rebase_patches" >&2
        exit 1
        ;;
esac
echo "Successfully prepared source for target: $TARGET"
