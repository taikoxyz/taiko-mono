#!/bin/bash

# Storage Layout Generation Script
#
# Generates storage layout comments for smart contracts and appends them to contract files.
#
# Usage: ./gen-layouts.sh <profile>
#   profile: shared, layer1, or layer2
#
# The storage layout is marked with:
#   // Storage Layout ---------------------------------------------------------------
#
# Re-running the script replaces old storage layout comments with updated ones.

set -euo pipefail

# Storage layout comment marker
readonly LAYOUT_MARKER="// Storage Layout ---------------------------------------------------------------"

# Contracts shared between layer 1 and layer 2
contracts_shared=(
"contracts/shared/vault/ERC1155Vault.sol:ERC1155Vault"
"contracts/shared/vault/ERC20Vault.sol:ERC20Vault"
"contracts/shared/vault/ERC721Vault.sol:ERC721Vault"
"contracts/shared/vault/BridgedERC20.sol:BridgedERC20"
"contracts/shared/vault/BridgedERC20V2.sol:BridgedERC20V2"
"contracts/shared/vault/BridgedERC721.sol:BridgedERC721"
"contracts/shared/vault/BridgedERC1155.sol:BridgedERC1155"
"contracts/shared/bridge/Bridge.sol:Bridge"
"contracts/shared/common/DefaultResolver.sol:DefaultResolver"
"contracts/shared/signal/SignalService.sol:SignalService"
)

# Layer 1 contracts
contracts_layer1=(
"contracts/layer1/mainnet/TaikoToken.sol:TaikoToken"
"contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation"
"contracts/layer1/core/impl/Inbox.sol:Inbox"
"contracts/layer1/core/impl/InboxOptimized1.sol:InboxOptimized1"
"contracts/layer1/core/impl/InboxOptimized2.sol:InboxOptimized2"
"contracts/layer1/devnet/DevnetInbox.sol:DevnetInbox"
"contracts/layer1/mainnet/MainnetInbox.sol:MainnetInbox"
"contracts/layer1/mainnet/MainnetBridge.sol:MainnetBridge"
"contracts/layer1/mainnet/MainnetSignalService.sol:MainnetSignalService"
"contracts/layer1/mainnet/MainnetERC20Vault.sol:MainnetERC20Vault"
"contracts/layer1/mainnet/MainnetERC1155Vault.sol:MainnetERC1155Vault"
"contracts/layer1/mainnet/MainnetERC721Vault.sol:MainnetERC721Vault"
"contracts/layer1/preconf/impl/PreconfWhitelist.sol:PreconfWhitelist"
"contracts/layer1/preconf/impl/LookaheadStore.sol:LookaheadStore"
"contracts/layer1/preconf/impl/LookaheadSlasher.sol:LookaheadSlasher"
"contracts/layer1/mainnet/MainnetDAOController.sol:MainnetDAOController"
)

# Layer 2 contracts
contracts_layer2=(
"contracts/layer2/mainnet/BridgedTaikoToken.sol:BridgedTaikoToken"
"contracts/layer2/governance/DelegateController.sol:DelegateController"
"contracts/layer2/core/Anchor.sol:Anchor"
)

# Update storage layout for a single contract
update_contract_layout() {
    local contract=$1
    local profile=$2
    local file_path="${contract%%:*}"  # Extract path before colon

    [ -f "$file_path" ] || { echo "❌ Failed: ${contract} (file not found)"; return 1; }

    # Generate storage layout
    local layout_output
    layout_output=$(FORGE_DISPLAY=plain FOUNDRY_PROFILE="${profile}" \
        forge inspect -C "./contracts/${profile}" -o "./out/${profile}" "${contract}" storagelayout 2>&1) || {
        echo "❌ Failed: ${contract} (forge inspect failed)"
        return 1
    }

    # Parse layout table: extract data rows with pipes, skip headers and borders
    local layout_comments
    layout_comments=$(echo "$layout_output" | awk -F'|' '
        NF >= 6 && /\|/ {
            # Trim whitespace from each field
            for (i=1; i<=NF; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i);
            name=$2; type=$3; slot=$4; offset=$5; bytes=$6;

            # Skip headers, empty rows, and border characters
            if (name == "Name" || name == "" || slot == "Slot" || name ~ /^[─═╭╰│┤┐└┴┬├┼+\-]+$/) next;

            printf "  %-30s | %-50s | Slot: %-4s | Offset: %-4s | Bytes: %-4s\n", name, type, slot, offset, bytes;
        }
    ' | sed 's/^/\/\/ /')

    [ -n "$layout_comments" ] || { echo "❌ Failed: ${contract} (no layout data)"; return 1; }

    # Remove everything from marker onwards (including preceding blank lines)
    if grep -q "$LAYOUT_MARKER" "$file_path"; then
        # Find first marker line, walk back past blank lines, delete from there to end
        local marker_line last_content_line
        marker_line=$(grep -n "$LAYOUT_MARKER" "$file_path" | head -1 | cut -d: -f1)
        last_content_line=$((marker_line - 1))

        # Skip blank lines before marker
        while [ $last_content_line -gt 0 ] && [ -z "$(sed -n "${last_content_line}p" "$file_path")" ]; do
            ((last_content_line--))
        done

        sed -i '' "1,${last_content_line}!d" "$file_path"
    fi

    # Append new storage layout
    cat >> "$file_path" << EOF

${LAYOUT_MARKER}
// solhint-disable max-line-length
//
${layout_comments}
// solhint-enable max-line-length
EOF

    echo "✅ Updated: ${contract}"
}

# Main
profile=$1

case "$profile" in
    shared) echo "Generating shared contract layouts..."; contracts=("${contracts_shared[@]}") ;;
    layer1) echo "Generating layer 1 contract layouts..."; contracts=("${contracts_layer1[@]}") ;;
    layer2) echo "Generating layer 2 contract layouts..."; contracts=("${contracts_layer2[@]}") ;;
    *) echo "❌ Error: Invalid profile '$profile'"; echo "Usage: $0 <shared|layer1|layer2>"; exit 1 ;;
esac

# Process contracts
failed=0
for contract in "${contracts[@]}"; do
    update_contract_layout "$contract" "$profile" || ((failed++))
done

# Summary
echo ""
echo "=========================================="
if [ $failed -eq 0 ]; then
    echo "✅ All ${#contracts[@]} contracts updated successfully!"
else
    echo "⚠️  ${failed}/${#contracts[@]} contracts failed"
    exit 1
fi
