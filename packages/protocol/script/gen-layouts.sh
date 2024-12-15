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
"contracts/shared/bridge/QuotaManager.sol:QuotaManager"
"contracts/shared/common/DefaultResolver.sol:DefaultResolver"
"contracts/shared/common/EssentialContract.sol:EssentialContract"
"contracts/shared/signal/SignalService.sol:SignalService"
)

# Layer 1 contracts
contracts_layer1=(
"contracts/layer1/token/TaikoToken.sol:TaikoToken"
"contracts/layer1/verifiers/compose/ComposeVerifier.sol:ComposeVerifier"
"contracts/layer1/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier"
"contracts/layer1/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier"
"contracts/layer1/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier"
"contracts/layer1/verifiers/Risc0Verifier.sol:Risc0Verifier"
"contracts/layer1/verifiers/SP1Verifier.sol:SP1Verifier"
"contracts/layer1/verifiers/SgxVerifier.sol:SgxVerifier"
"contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation"
"contracts/layer1/based/TaikoL1.sol:TaikoL1"
"contracts/layer1/hekla/HeklaTaikoL1.sol:HeklaTaikoL1"
"contracts/layer1/mainnet/multirollup/MainnetBridge.sol:MainnetBridge"
"contracts/layer1/mainnet/multirollup/MainnetSignalService.sol:MainnetSignalService"
"contracts/layer1/mainnet/multirollup/MainnetERC20Vault.sol:MainnetERC20Vault"
"contracts/layer1/mainnet/multirollup/MainnetERC1155Vault.sol:MainnetERC1155Vault"
"contracts/layer1/mainnet/multirollup/MainnetERC721Vault.sol:MainnetERC721Vault"
"contracts/layer1/mainnet/MainnetTaikoL1.sol:MainnetTaikoL1"
"contracts/layer1/team/TokenUnlock.sol:TokenUnlock"
"contracts/layer1/provers/ProverSet.sol:ProverSet"
"contracts/layer1/fork/ForkManager.sol:ForkManager"
)

# Layer 2 contracts
contracts_layer2=(
"contracts/layer2/token/BridgedTaikoToken.sol:BridgedTaikoToken"
"contracts/layer2/DelegateOwner.sol:DelegateOwner"
"contracts/layer2/based/TaikoL2.sol:TaikoL2"
"contracts/layer2/hekla/HeklaTaikoL2.sol:HeklaTaikoL2"
"contracts/layer2/mainnet/MainnetTaikoL2.sol:MainnetTaikoL2"
)

profile=$1

if [ "$profile" == "layer1" ]; then
    echo "Generating layer 1 contract layouts..."
    contracts=("${contracts_shared[@]}" "${contracts_layer1[@]}")
elif [ "$profile" == "layer2" ]; then
    echo "Generating layer 2 contract layouts..."
    contracts=("${contracts_shared[@]}" "${contracts_layer2[@]}")
else
    echo "Invalid profile. Please enter either 'layer1' or 'layer2'."
    exit 1
fi

# Empty the output file initially
output_file="contract_layout_${profile}.md"
> $output_file

# Loop over each contract
for contract in "${contracts[@]}"; do
    # Run forge inspect and append to the file
    # Ensure correct concatenation of the command without commas
    echo "inspect ${contract}"

    echo "## ${contract}" >> $output_file
    FOUNDRY_PROFILE=${profile} forge inspect -C ./contracts/${profile} -o ./out/${profile} ${contract} storagelayout --pretty >> $output_file
    echo "" >> $output_file
done

sed_pattern='s|contracts/.*/\([^/]*\)\.sol:\([^/]*\)|\2|g'

if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "$sed_pattern" "$output_file"
else
    sed -i "$sed_pattern" "$output_file"
fi
