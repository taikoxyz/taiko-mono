#!/bin/bash

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
"contracts/shared/fork-router/ForkRouter.sol:ForkRouter"
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

profile=$1

if [ "$profile" == "shared" ]; then
    echo "Generating shared contract layouts..."
    contracts=("${contracts_shared[@]}")
elif [ "$profile" == "layer1" ]; then
    echo "Generating layer 1 contract layouts..."
    contracts=("${contracts_layer1[@]}")
elif [ "$profile" == "layer2" ]; then
    echo "Generating layer 2 contract layouts..."
    contracts=("${contracts_layer2[@]}")
else
    echo "Invalid profile. Please enter either 'shared','layer1' or 'layer2'."
    exit 1
fi

# Empty the output file initially
output_file="layout/${profile}-contracts.txt"
> $output_file

# Loop over each contract
for contract in "${contracts[@]}"; do
    # Run forge inspect and append to the file
    # Ensure correct concatenation of the command without commas
    echo "inspect ${contract}"

    echo "## ${contract}" >> $output_file
    FORGE_DISPLAY=plain FOUNDRY_PROFILE=${profile} forge inspect -C ./contracts/${profile} -o ./out/${profile} ${contract} storagelayout >> $output_file
    echo "" >> $output_file
done

sed_pattern='s|contracts/.*/\([^/]*\)\.sol:\([^/]*\)|\2|g'

if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "$sed_pattern" "$output_file"
else
    sed -i "$sed_pattern" "$output_file"
fi

# Use awk to remove the last column and write to a temporary file
temp_file="${output_file}_temp"
while IFS= read -r line; do
    # Remove everything behind the second-to-last "|"
    echo "$line" | sed -E 's/\|[^|]*\|[^|]*$/|/'
done < "$output_file" > "$temp_file"
mv "$temp_file" "$output_file"
