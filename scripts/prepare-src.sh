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
    
    # Get count of </script> elements to ensure we only handle single scripts
    local script_count
    script_count=$(xmllint --html --xpath "count(//script)" "$filepath" 2>/dev/null || echo "0")
    
    # Only process if there's exactly one script tag
    if [[ "$script_count" != "1" ]]; then
        if [[ "$script_count" == "0" ]]; then
            echo "No script tags found"
        else
            echo "Multiple script tags found ($script_count). Only single script updates are supported."
        fi
        return 0
    fi
    
    # Extract the single script content. Suppress HTML parsing warnings by re-directing error output to null.
    local script_content
    script_content=$(xmllint --html --xpath "//script[1]/text()" "$filepath" 2>/dev/null || true)
    
    # Remove CDATA markers if present. CDATA markers are added automatically by xmllint.
    if [[ "$script_content" == *"<![CDATA["* ]]; then
        # Strip CDATA opening and closing markers
        script_content="${script_content#*<![CDATA[}"
        script_content="${script_content%]]>*}"
    fi
    
    if [[ -z "$script_content" ]]; then
        echo "Script tag found but no content"
        return 0
    fi
    
    # Calculate SHA256 hash and encode to base64
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
    
    export QUILT_PATCHES="$patch_dir"
    export QUILT_SERIES="${PRESENT_WORKING_DIR}/$patches_path"
    
    pushd "${PATCHED_SRC_DIR}"
    
    # Check if there are applied patches
    local applied_output
    applied_output=$(quilt applied 2>/dev/null || true)

    if [[ -z "$applied_output" ]]; then
        popd
        return
    fi
    
    # Check for unsaved changes with diff
    local diff_output
    diff_output=$(quilt diff -z 2>/dev/null || true)

    if [[ -n "$diff_output" ]]; then
        popd
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
    # Read configuration from JSON file
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

    if [[ "$INCLUDE_TESTS" == "true" ]]; then
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
    if [[ "$INCLUDE_TESTS" == "true" ]]; then
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

        # --- Standard path: apply with force, halt on conflict ---
        local output
        set +e  # Disable exit on error
        output=$(quilt push -f -m 2>&1)
        local exit_code=$?
        set -e  # Re-enable exit on error
        
        echo "$output"
        
        # Parse conflicts and missing files
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
            popd
            exit 1
        fi
        
    done
    
    echo "All patches applied successfully"
    popd
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

COMMAND="prepare_src"
TARGET="code-editor-sagemaker-server"
RESET_LOCKFILES=false
INCLUDE_TESTS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --command)
            [[ $# -ge 2 ]] || { echo "--command requires a value" >&2; exit 1; }
            COMMAND="$2"
            shift 2
            ;;
        --include-tests)
            INCLUDE_TESTS=true
            shift
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

echo "Using configuration: $CONFIG_FILE"
echo "Preparing source for target: $TARGET (include-tests: $INCLUDE_TESTS)"
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
