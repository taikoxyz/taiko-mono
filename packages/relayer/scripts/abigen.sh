#/bin/sh

if [ ! -d "../protocol/out" ]; then
    echo "ABI not generated in protocol package yet. Please run npm install && npx hardhat compile in ../protocol"
    exit 1
fi

# Define paths and names arrays
paths=("ERC1155Vault.sol" "ERC721Vault.sol" "ERC20Vault.sol" "Bridge.sol" "TaikoL2.sol" "TaikoL1.sol" "SignalService.sol")
names=("ERC1155Vault" "ERC721Vault" "ERC20Vault" "Bridge" "TaikoL2" "TaikoL1" "SignalService")

# Iterate over paths array
for (( i = 0; i < ${#paths[@]}; ++i )); 
do
    # Generate JSON file path
    json_file="../protocol/out/${paths[i]}/${names[i]}.json"
    
    # Check if JSON file exists
    if [ ! -f "$json_file" ]; then
        echo "Error: JSON file not found for ${names[i]}"
        exit 1
    fi
    
    # Extract ABI using jq
    jq .abi "$json_file" > "${names[i]}.json"
    
    # Convert name to lowercase for package name
    pkg_name=$(echo "${names[i]}" | tr '[:upper:]' '[:lower:]')
    
    # Generate Go bindings using abigen
    abigen --abi "${names[i]}.json" \
           --pkg "$pkg_name" \
           --type "${names[i]}" \
           --out "bindings/$pkg_name/${names[i]}.go"
    
    # Check if abigen command was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate Go bindings for ${names[i]}"
        exit 1
    fi
done

exit 0
