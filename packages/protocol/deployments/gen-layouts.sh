#!/bin/bash

# Check if a commit hash is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 commit_hash"
    exit 1
fi

# The commit hash is taken from the first command line argument
commit="$1"

# Define the list of contracts to inspect
contracts=(
    "TaikoL1"
    "TaikoL2"
    "SignalService"
    "Bridge"
    "DelegateOwner"
    "GuardianProver"
    "TaikoToken"
    "BridgedTaikoToken"
    "ERC20Vault"
    "ERC721Vault"
    "ERC1155Vault"
    "BridgedERC20"
    "BridgedERC721"
    "BridgedERC1155"
    "SgxVerifier"
)

# Switch to the commit in detached mode
git checkout $commit

# Empty the output file initially
output_file="layout-${commit:0:7}.txt"
> $output_file

# Loop over each contract
for contract in "${contracts[@]}"; do
    # Run forge inspect and append to the file
    # Ensure correct concatenation of the command without commas
    echo "forge inspect ${contract} storagelayout --pretty >> $output_file"

    echo "## ${contract}" >> $output_file
    forge inspect ${contract} storagelayout --pretty >> $output_file
done

git switch -

