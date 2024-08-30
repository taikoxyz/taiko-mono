#!/bin/bash

# Define the list of contracts to inspect
# Please try not to change the order
contracts=(
"contracts/L1/TaikoL1.sol:TaikoL1"
"contracts/L2/TaikoL2.sol:TaikoL2"
"contracts/signal/SignalService.sol:SignalService"
"contracts/bridge/Bridge.sol:Bridge"
"contracts/L2/DelegateOwner.sol:DelegateOwner"
"contracts/L1/provers/GuardianProver.sol:GuardianProver"
"contracts/tko/TaikoToken.sol:TaikoToken"
"contracts/tko/BridgedTaikoToken.sol:BridgedTaikoToken"
"contracts/tokenvault/ERC20Vault.sol:ERC20Vault"
"contracts/tokenvault/ERC721Vault.sol:ERC721Vault"
"contracts/tokenvault/ERC1155Vault.sol:ERC1155Vault"
"contracts/tokenvault/BridgedERC20.sol:BridgedERC20"
"contracts/tokenvault/BridgedERC20V2.sol:BridgedERC20V2"
"contracts/tokenvault/BridgedERC721.sol:BridgedERC721"
"contracts/tokenvault/BridgedERC1155.sol:BridgedERC1155"
"contracts/automata-attestation/AutomataDcapV3Attestation.sol:AutomataDcapV3Attestation"
"contracts/verifiers/SgxVerifier.sol:SgxVerifier"
"contracts/verifiers/Risc0Verifier.sol:Risc0Verifier"
"contracts/verifiers/SP1Verifier.sol:SP1Verifier"
"contracts/bridge/QuotaManager.sol:QuotaManager"
"contracts/team/proving/ProverSet.sol:ProverSet"
"contracts/team/tokenunlock/TokenUnlock.sol:TokenUnlock"
"contracts/verifiers/compose/ComposeVerifier.sol:ComposeVerifier"
"contracts/verifiers/compose/TeeAnyVerifier.sol:TeeAnyVerifier"
"contracts/verifiers/compose/ZkAnyVerifier.sol:ZkAnyVerifier"
"contracts/verifiers/compose/ZkAndTeeVerifier.sol:ZkAndTeeVerifier"
"contracts/hekla/HeklaTaikoL1.sol:HeklaTaikoL1"
"contracts/mainnet/shared/MainnetBridge.sol:MainnetBridge"
"contracts/mainnet/shared/MainnetERC1155Vault.sol:MainnetERC1155Vault"
"contracts/mainnet/shared/MainnetERC20Vault.sol:MainnetERC20Vault"
"contracts/mainnet/shared/MainnetERC721Vault.sol:MainnetERC721Vault"
"contracts/mainnet/rollup/MainnetGuardianProver.sol:MainnetGuardianProver"
"contracts/mainnet/rollup/MainnetProverSet.sol:MainnetProverSet"
"contracts/mainnet/rollup/verifiers/MainnetRisc0Verifier.sol:MainnetRisc0Verifier"
"contracts/mainnet/rollup/verifiers/MainnetSP1Verifier.sol:MainnetSP1Verifier"
"contracts/mainnet/rollup/MainnetRollupAddressManager.sol:MainnetRollupAddressManager"
"contracts/mainnet/rollup/verifiers/MainnetSgxVerifier.sol:MainnetSgxVerifier"
"contracts/mainnet/rollup/verifiers/MainnetTeeAnyVerifier.sol:MainnetTeeAnyVerifier"
"contracts/mainnet/rollup/verifiers/MainnetZkAnyVerifier.sol:MainnetZkAnyVerifier"
"contracts/mainnet/rollup/verifiers/MainnetZkAndTeeVerifier.sol:MainnetZkAndTeeVerifier"
"contracts/mainnet/shared/MainnetSharedAddressManager.sol:MainnetSharedAddressManager"
"contracts/mainnet/shared/MainnetSignalService.sol:MainnetSignalService"
"contracts/mainnet/rollup/MainnetTaikoL1.sol:MainnetTaikoL1"
"contracts/mainnet/rollup/MainnetTierRouter.sol:MainnetTierRouter"
)

# Empty the output file initially
output_file="contract_layout.md"
> $output_file

# Loop over each contract
for contract in "${contracts[@]}"; do
    # Run forge inspect and append to the file
    # Ensure correct concatenation of the command without commas
    echo "forge inspect ${contract} storagelayout --pretty >> $output_file"

    echo "## ${contract}" >> $output_file
    forge inspect ${contract} storagelayout --pretty >> $output_file
    echo "" >> $output_file
done
