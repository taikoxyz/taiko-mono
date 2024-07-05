#!/bin/sh

if [ ! -d "../protocol/out" ]; then
    echo "ABI not generated in protocol package yet. Please run npm install && pnpm run compile in ../protocol"
    exit 1
fi

paths=("TaikoL1.sol" "Bridge.sol" "SgxVerifier.sol" "TaikoToken.sol")

names=("TaikoL1" "Bridge" "SgxVerifier" "TaikoToken")


for (( i = 0; i < ${#paths[@]}; ++i ));
do
    lower=$(echo "${names[i]}" | tr '[:upper:]' '[:lower:]')
    jq .abi ../protocol/out/${paths[i]}/${names[i]}.json > contracts/$lower/${names[i]}.json
    abigen --abi contracts/$lower/${names[i]}.json \
    --pkg $lower \
    --type ${names[i]} \
    --out contracts/$lower/${names[i]}.go
done

exit 0
