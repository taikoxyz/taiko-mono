#!/bin/bash

if [ ! -d "../protocol/out" ]; then
    echo "ABI not generated in protocol package yet. Please run npm install && pnpm run compile in ../protocol"
    exit 1
fi

paths=("layer1/Inbox.sol")

names=("Inbox")


for (( i = 0; i < ${#paths[@]}; ++i ));
do
    lower=$(echo "${names[i]}" | tr '[:upper:]' '[:lower:]')
    jq .abi ../protocol/out/${paths[i]}/${names[i]}.json > contracts/shasta/$lower/${names[i]}.json
    abigen --abi contracts/shasta/$lower/${names[i]}.json \
    --pkg $lower \
    --type ${names[i]} \
    --out contracts/shasta/$lower/${names[i]}.go
done

exit 0
