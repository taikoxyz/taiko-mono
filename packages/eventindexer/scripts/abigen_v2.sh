#!/bin/bash

if [ ! -d "../protocol/out" ]; then
    echo "ABI not generated in protocol package yet. Please run npm install && pnpm run compile in ../protocol"
    exit 1
fi

paths=("layer1/TaikoL1.sol")

names=("TaikoL1")


for (( i = 0; i < ${#paths[@]}; ++i ));
do
    lower=$(echo "${names[i]}" | tr '[:upper:]' '[:lower:]')
    jq .abi ../protocol/out/${paths[i]}/${names[i]}.json > contracts/v2/$lower/${names[i]}.json
    abigen --abi contracts/v2/$lower/${names[i]}.json \
    --pkg $lower \
    --type ${names[i]} \
    --out contracts/v2/$lower/${names[i]}.go
done

exit 0
