#!/bin/bash

# Define the list of contracts to inspect
# Please try not to change the order
# Contracts shared between layer 1 and layer 2
contracts_shared=(
"contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault"
"contracts/tokenvault/ERC20Vault.sol:ERC20Vault"
"contracts/tokenvault/ERC721Vault.sol:ERC721Vault"
"contracts/tokenvault/BridgedERC20.sol:BridgedERC20"
"contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2"
"contracts/tokenvault/BridgedERC721.sol:BridgedERC721"
"contracts/tokenvault/BridgedERC1155.sol:BridgedERC1155"
"contracts/bridge/Bridge.sol:Bridge"
"contracts/bridge/QuotaManager.sol:QuotaManager"
"contracts/common/AddressManager.sol:AddressManager"
"contracts/common/AddressResolver.sol:AddressResolver"
"contracts/common/EssentialContract.sol:EssentialContract"
"contracts/signal/SignalService.sol:SignalService"
)

# Layer 1 contracts
contracts_layer1=(
"contracts/tko/TaikoToken.sol:TaikoToken"
"contracts/verifiers/compose/ComposeVerifier.sol:ComposeVerifier"
"contracts/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier"
"contracts/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier"
"contracts/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier"
"contracts/verifiers/Risc0Verifier.sol:Risc0Verifier"
"contracts/verifiers/SP1Verifier.sol:SP1Verifier"
"contracts/verifiers/SgxVerifier.sol:SgxVerifier"
"contracts/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation"
"contracts/L1/TaikoL1.sol:TaikoL1"
"contracts/L1/tiers/TierProviderV2.sol:TierProviderV2"
"contracts/hekla/HeklaTaikoL1.sol:HeklaTaikoL1"
"contracts/hekla/HeklaTierProvider.sol:HeklaTierProvider"
"contracts/mainnet/shared/MainnetBridge.sol:MainnetBridge"
"contracts/mainnet/shared/MainnetSignalService.sol:MainnetSignalService"
"contracts/mainnet/shared/MainnetERC20Vault.sol:MainnetERC20Vault"
"contracts/mainnet/shared/MainnetERC1155Vault.sol:MainnetERC1155Vault"
"contracts/mainnet/shared/MainnetERC721Vault.sol:MainnetERC721Vault"
"contracts/mainnet/shared/MainnetSharedAddressManager.sol:MainnetSharedAddressManager"
"contracts/mainnet/addrcache/RollupAddressCache.sol:RollupAddressCache"
"contracts/mainnet/addrcache/SharedAddressCache.sol:SharedAddressCache"
"contracts/mainnet/addrcache/AddressCache.sol:AddressCache"
"contracts/mainnet/rollup/verifiers/MainnetSgxVerifier.sol:MainnetSgxVerifier"
"contracts/mainnet/rollup/verifiers/MainnetSP1Verifier.sol:MainnetSP1Verifier"
"contracts/mainnet/rollup/verifiers/MainnetZkAnyVerifier.sol:MainnetZkAnyVerifier"
"contracts/mainnet/rollup/verifiers/MainnetRisc0Verifier.sol:MainnetRisc0Verifier"
"contracts/mainnet/rollup/verifiers/MainnetZkAndTeeVerifier.sol:MainnetZkAndTeeVerifier"
"contracts/mainnet/rollup/verifiers/MainnetTeeAnyVerifier.sol:MainnetTeeAnyVerifier"
"contracts/mainnet/rollup/MainnetGuardianProver.sol:MainnetGuardianProver"
"contracts/mainnet/rollup/MainnetTaikoL1.sol:MainnetTaikoL1"
"contracts/mainnet/rollup/MainnetRollupAddressManager.sol:MainnetRollupAddressManager"
"contracts/mainnet/rollup/MainnetTierRouter.sol:MainnetTierRouter"
"contracts/mainnet/rollup/MainnetProverSet.sol:MainnetProverSet"
"contracts/team/tokenunlock/TokenUnlock.sol:TokenUnlock"
"contracts/team/proving/ProverSet.sol:ProverSet"
"contracts/L1/provers/GuardianProver.sol:GuardianProver"
)

# Layer 2 contracts
contracts_layer2=(
"contracts/tko/BridgedTaikoToken.sol:BridgedTaikoToken"
"contracts/L2/DelegateOwner.sol:DelegateOwner"
"contracts/L2/TaikoL2.sol:TaikoL2"
"contracts/hekla/HeklaTaikoL2.sol:HeklaTaikoL2"
"contracts/mainnet/rollup/MainnetTaikoL2.sol:MainnetTaikoL2"
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
