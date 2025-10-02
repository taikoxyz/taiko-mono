#!/bin/bash

# Define the list of contracts to inspect
# Please try not to change the order
# Contracts shared between layer 1 and layer 2
contracts_shared=(
"contracts/shared/tokenvault/ERC1155Vault.sol:ERC1155Vault"
"contracts/shared/tokenvault/ERC20Vault.sol:ERC20Vault"
"contracts/shared/tokenvault/ERC721Vault.sol:ERC721Vault"
"contracts/shared/tokenvault/BridgedERC20.sol:BridgedERC20"
"contracts/shared/tokenvault/BridgedERC20V2.sol:BridgedERC20V2"
"contracts/shared/tokenvault/BridgedERC721.sol:BridgedERC721"
"contracts/shared/tokenvault/BridgedERC1155.sol:BridgedERC1155"
"contracts/shared/bridge/Bridge.sol:Bridge"
"contracts/shared/common/DefaultResolver.sol:DefaultResolver"
"contracts/shared/signal/SignalService.sol:SignalService"
)

# Layer 1 contracts
contracts_layer1=(
"contracts/layer1/token/TaikoToken.sol:TaikoToken"
"contracts/layer1/verifiers/compose/SgxAndZkVerifier.sol:SgxAndZkVerifier"
"contracts/layer1/verifiers/TaikoRisc0Verifier.sol:TaikoRisc0Verifier"
"contracts/layer1/verifiers/TaikoSP1Verifier.sol:TaikoSP1Verifier"
"contracts/layer1/verifiers/TaikoSgxVerifier.sol:TaikoSgxVerifier"
"contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation"
"contracts/layer1/based/TaikoInbox.sol:TaikoInbox"
"contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge"
"contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService"
"contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault"
"contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault"
"contracts/layer1/mainnet/multirollup/MainnetERC721Vault.sol:MainnetERC721Vault"
"contracts/layer1/mainnet/MainnetInbox.sol:MainnetInbox"
"contracts/layer1/shasta/impl/ShastaMainnetInbox.sol:ShastaMainnetInbox"
"contracts/layer1/team/TokenUnlock.sol:TokenUnlock"
"contracts/layer1/provers/ProverSet.sol:ProverSet"
"contracts/layer1/fork-router/ForkRouter.sol:ForkRouter"
"contracts/layer1/forced-inclusion/TaikoWrapper.sol:TaikoWrapper"
"contracts/layer1/forced-inclusion/ForcedInclusionStore.sol:ForcedInclusionStore"
"contracts/layer1/preconf/impl/PreconfRouter.sol:PreconfRouter"
"contracts/layer1/preconf/impl/PreconfRouter2.sol:PreconfRouter2"
"contracts/layer1/preconf/impl/PreconfWhitelist.sol:PreconfWhitelist"
"contracts/layer1/preconf/impl/LookaheadStore.sol:LookaheadStore"
"contracts/layer1/preconf/impl/PreconfSlasher.sol:PreconfSlasher"
"contracts/layer1/governance/TaikoDAOController.sol:TaikoDAOController"
)

# Layer 2 contracts
contracts_layer2=(
"contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken"
"contracts/layer2/mainnet/DelegateController.sol:DelegateController"
"contracts/layer2/based/TaikoAnchor.sol:TaikoAnchor"
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