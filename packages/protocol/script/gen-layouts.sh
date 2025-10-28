#!/bin/bash

# Storage Layout Generation Script
#
# This script generates storage layout information for smart contracts and automatically
# appends them as comments at the end of each contract file.
#
# Usage: ./gen-layouts.sh <profile>
#   profile: shared, layer1, or layer2
#
# The storage layout comments are marked with a single line:
#   // Storage Layout ---------------------------------------------------------------
#
# Re-running the script will replace old storage layout comments with updated ones.

set -e
set -o pipefail  # Fail on any command in a pipeline

# Storage layout comment marker
readonly LAYOUT_MARKER="// Storage Layout ---------------------------------------------------------------"

# Define the list of contracts to inspect
# Please try not to change the order
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

# Function to update storage layout for a single contract
update_contract_layout() {
    local contract=$1
    local profile=$2
    local file_path=$(echo "${contract}" | cut -d':' -f1)

    [ -f "$file_path" ] || { echo "❌ Failed: ${contract} (file not found: $file_path)"; return 1; }

    # Generate storage layout and convert to plain text format
    local forge_output layout_comments

    # First, run forge inspect and capture output + check for errors
    if ! forge_output=$(FORGE_DISPLAY=plain FOUNDRY_PROFILE=${profile} \
        forge inspect -C ./contracts/${profile} -o ./out/${profile} ${contract} storagelayout 2>&1); then
        echo "❌ Error: forge inspect failed for ${contract}"
        echo "   Output: ${forge_output}"
        return 1
    fi

    # Check if output looks like a valid storage layout table (contains pipes)
    if ! echo "$forge_output" | grep -q "|"; then
        echo "❌ Error: forge inspect did not produce valid storage layout output for ${contract}"
        echo "   Output: ${forge_output}"
        return 1
    fi

    # Parse and format the output
    # This is more robust - just look for lines with pipes and parse the 6 columns
    layout_comments=$(echo "$forge_output" \
        | awk '
            BEGIN { FS="|"; }
            # Process any row with at least 6 pipe-separated fields
            NF >= 6 && /\|/ {
                # Extract fields by pipe delimiter and trim spaces
                name = $2; gsub(/^[ \t]+|[ \t]+$/, "", name);
                type = $3; gsub(/^[ \t]+|[ \t]+$/, "", type);
                slot = $4; gsub(/^[ \t]+|[ \t]+$/, "", slot);
                offset = $5; gsub(/^[ \t]+|[ \t]+$/, "", offset);
                bytes = $6; gsub(/^[ \t]+|[ \t]+$/, "", bytes);

                # Skip header rows and empty rows
                if (name == "Name" || name == "" || slot == "Slot") next;
                # Skip rows that are just border characters
                if (name ~ /^[─═╭╰╯╮│┤┐└┴┬├┼╪╬╩╦╠═╣╚╔╗╝+\-]+$/) next;

                # Format output
                printf "  %-30s | %-50s | Slot: %-4s | Offset: %-4s | Bytes: %-4s\n",
                       name, type, slot, offset, bytes;
            }
        ' \
        | sed 's/^/\/\/ /')

    # Verify we got some output
    if [ -z "$layout_comments" ]; then
        echo "❌ Error: Failed to parse storage layout for ${contract}"
        return 1
    fi

    # Remove old storage layout comments if they exist
    # Simply remove everything from the marker line to end of file
    if grep -q "$LAYOUT_MARKER" "$file_path"; then
        # Find the line number where the marker appears
        local marker_line
        marker_line=$(grep -n "$LAYOUT_MARKER" "$file_path" | head -1 | cut -d: -f1)

        # Keep everything before the marker line, also remove all preceding blank lines
        local keep_until=$((marker_line - 1))

        # Walk backwards removing all blank lines before the marker
        while [ "$keep_until" -gt 0 ]; do
            local line_content
            line_content=$(sed -n "${keep_until}p" "$file_path")
            if [ -z "$line_content" ]; then
                keep_until=$((keep_until - 1))
            else
                break
            fi
        done

        sed -n "1,${keep_until}p" "$file_path" > "${file_path}.tmp" && mv "${file_path}.tmp" "$file_path"
    fi

    # Append new storage layout comment block
    cat >> "$file_path" << EOF

${LAYOUT_MARKER}
// solhint-disable max-line-length
//
${layout_comments}
// solhint-enable max-line-length
EOF

    echo "✅ Updated: ${contract}"
}

# Main script
profile=$1

case "$profile" in
    shared)
        echo "Generating shared contract layouts..."
        contracts=("${contracts_shared[@]}")
        ;;
    layer1)
        echo "Generating layer 1 contract layouts..."
        contracts=("${contracts_layer1[@]}")
        ;;
    layer2)
        echo "Generating layer 2 contract layouts..."
        contracts=("${contracts_layer2[@]}")
        ;;
    *)
        echo "❌ Error: Invalid profile '$profile'"
        echo ""
        echo "Usage: $0 <profile>"
        echo "  profile: shared, layer1, or layer2"
        exit 1
        ;;
esac

# Process each contract and track failures
failed_contracts=()
success_count=0

for contract in "${contracts[@]}"; do
    if update_contract_layout "$contract" "$profile"; then
        success_count=$((success_count + 1))
    else
        failed_contracts+=("$contract")
        # Error message already printed by update_contract_layout
    fi
done

echo ""
echo "=========================================="
echo "Summary:"
echo "  Success: $success_count/${#contracts[@]} contracts"
if [ ${#failed_contracts[@]} -gt 0 ]; then
    echo "  Failed:  ${#failed_contracts[@]} contracts"
    echo ""
    echo "❌ Failed contracts:"
    for contract in "${failed_contracts[@]}"; do
        echo "  - $contract"
    done
    echo ""
    echo "⚠️  Some contracts failed to update. Please review errors above."
    exit 1
else
    echo "✅ All storage layout comments updated successfully!"
fi
