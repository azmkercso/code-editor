#!/usr/bin/env bash
# apply-product-config.sh — Generate the product.json patch for Code Editor.
#
# @generated
# @generator: scripts/patches/apply-product-config.sh
#
# Usage:
#   ./scripts/patches/apply-product-config.sh [--target <target>] [code-editor-src-dir]
#
# Targets:
#   base (default) — common product.json transformations
#   sagemaker      — SageMaker-specific incremental overrides (applied on top of base)
set -euo pipefail

TARGET="base"
SRC_DIR="code-editor-src"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        *) SRC_DIR="$1"; shift ;;
    esac
done

PRODUCT_JSON="$SRC_DIR/product.json"

if [[ ! -f "$PRODUCT_JSON" ]]; then
    echo "Error: $PRODUCT_JSON not found" >&2
    exit 1
fi

jq_inplace() {
    local filter="$1" file="$2"
    jq --tab "$filter" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

case "$TARGET" in
    base)
        jq_inplace '
.nameShort = "Code Editor" |
.nameLong = "Code Editor" |
.codeEditorVersion = "1.0.0" |
.applicationName = "code" |
.dataFolderName = ".vscode-editor" |
.sharedDataFolderName = ".vscode-editor-shared" |
.licenseUrl = "https://github.com/aws/code-editor/blob/main/LICENSE" |
.serverLicenseUrl = "https://github.com/aws/code-editor/blob/main/LICENSE" |
.serverApplicationName = "code-editor-server" |
.serverDataFolderName = ".code-editor-server" |
.tunnelApplicationName = "code-editor-tunnel" |
.linuxIconName = "code-editor" |
.reportIssueUrl = "https://github.com/aws/code-editor/issues/new" |
.builtInExtensions = [] |
.defaultChatAgent = (.defaultChatAgent // {} |
    .extensionId = "Amazon.amazon-q-vscode" |
    .chatExtensionId = "Amazon.amazon-q-vscode" |
    del(.chatExtensionOutputId, .chatExtensionOutputExtensionStateCommand,
        .documentationUrl, .termsStatementUrl, .privacyStatementUrl,
        .skusDocumentationUrl, .publicCodeMatchesUrl, .manageSettingsUrl,
        .managePlanUrl, .manageOverageUrl, .upgradePlanUrl, .signUpUrl,
        .providerExtensionId, .providerUriSetting, .providerScopes,
        .entitlementUrl, .entitlementSignupLimitedUrl,
        .chatQuotaExceededContext, .completionsQuotaExceededContext,
        .walkthroughCommand, .completionsMenuCommand, .chatRefreshTokenCommand,
        .generateCommitMessageCommand, .resolveMergeConflictsCommand,
        .completionsAdvancedSetting, .completionsEnablementSetting,
        .nextEditSuggestionsSetting, .tokenEntitlementUrl, .mcpRegistryDataUrl) |
    .provider = (.provider // {} | to_entries | map(.value = {id: "", name: ""}) | from_entries)
) |
.trustedExtensionAuthAccess = {"amazon": ["Amazon.amazon-q-vscode"]} |
.linkProtectionTrustedDomains = [
    "https://docs.aws.amazon.com",
    "https://docs.amazonaws.cn",
    "https://dcaprod.www.docs.aws.a2z.com",
    "https://lckprod.www.docs.aws.a2z.com",
    "https://console.aws.amazon.com",
    "https://console.amazonaws-us-gov.com",
    "https://console.amazonaws.cn",
    "https://aws.amazon.com",
    "https://*.amazon.com"
] |
.excludedSettingPatterns = [
    "chat.",
    "inlineChat.",
    "notebook.experimental.chat",
    "accessibility.signals.chat",
    "accessibility.chat",
    "accessibility.openChat",
    "accessibility.verboseChat",
    "accessibility.verbosity.chat",
    "accessibility.verbosity.terminalChat",
    "accessibility.verbosity.inlineChat",
    "accessibility.verbosity.panelChat",
    "accessibility.verbosity.sessionsChat",
    "workbench.chat.",
    "workbench.commandPalette.showAskInChat",
    "github.copilot",
    "terminal.integrated.chat.",
    "ai.",
    "git.addAICoAuthor",
    "workbench.commandPalette.experimental.chat",
    "workbench.commandPalette.experimental.askChat",
    "imageCarousel.chat"
] |
.excludedActionPatterns = [
    "workbench.action.chat.",
    "workbench.action.quickchat.",
    "inlineChat.",
    "notebook.cell.chat.",
    "interactive.input.chat.",
    "workbench.action.terminal.chat.",
    "github.copilot.",
    "workbench.action.edits."
]
' "$PRODUCT_JSON"
        ;;
    sagemaker)
        jq_inplace '
.nameShort = "SageMaker Code Editor" |
.nameLong = "SageMaker Code Editor" |
.sagemakerCodeEditorVersion = "__SAGEMAKER_VERSION__"
' "$PRODUCT_JSON"
        ;;
    *)
        echo "Error: unknown target '$TARGET'" >&2
        exit 1
        ;;
esac

echo "product.json updated successfully (target: $TARGET)"
