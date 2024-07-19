#!/bin/bash

# Define the list of contracts to inspect
contracts=(
    "AddressManager"
    "AutomataDcapV3Attestation"
    "Bridge"
    "BridgedERC1155"
    "BridgedERC20"
    "BridgedERC20V2"
    "BridgedERC721"
    "BridgedTaikoToken"
    "DelegateOwner"
    "ERC1155Vault"
    "ERC20Airdrop"
    "ERC20Vault"
    "ERC721Vault"
    "HeklaTaikoL1"
    "GuardianProver"
    "MainnetBridge"
    "MainnetERC1155Vault"
    "MainnetERC20Vault"
    "MainnetERC721Vault"
    "MainnetGuardianProver"
    "MainnetProverSet"
    "MainnetRiscZeroVerifier"
    "MainnetRollupAddressManager"
    "MainnetSgxVerifier"
    "MainnetSharedAddressManager"
    "MainnetSignalService"
    "MainnetTaikoL1"
    "MainnetTierRouter"
    "ProverSet"
    "QuotaManager"
    "RiscZeroVerifier"
    "SgxVerifier"
    "SignalService"
    "TaikoL1"
    "TaikoL2"
    "TaikoToken"
    "TokenUnlock"
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
