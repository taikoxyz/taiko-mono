#!/bin/sh

if [ ! -d "../protocol/out" ]; then
    echo "ABI not generated in protocol package yet. Please run npm install && npx hardhat compile in ../protocol"
    exit 1
fi

paths=("ERC1155Vault.sol" "ERC721Vault.sol" "ERC20Vault.sol" "Bridge.sol" "TaikoL2.sol" "TaikoL1.sol" "SignalService.sol" "QuotaManager.sol")

names=("ERC1155Vault" "ERC721Vault" "ERC20Vault" "Bridge" "TaikoL2" "TaikoL1" "SignalService" "QuotaManager")

for (( i = 0; i < ${#paths[@]}; ++i ));
do
    lower=$(echo "${names[i]}" | tr '[:upper:]' '[:lower:]')
    jq .abi ../protocol/out/${paths[i]}/${names[i]}.json > bindings/$lower/${names[i]}.json
    abigen --abi bindings/$lower/${names[i]}.json \
    --pkg $lower \
    --type ${names[i]} \
    --out bindings/$lower/${names[i]}.go
done

exit 0
