#!/bin/bash

if [ ! -d "../protocol/out" ]; then
    echo "ABI not generated in protocol package yet. Please run npm install && npx hardhat compile in ../protocol"
    exit 1
fi

paths=("layer1/PreconfWhitelist.sol")

names=("PreconfWhitelist")

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
