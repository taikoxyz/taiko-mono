#!/bin/bash

if [ ! -d "../protocol/out" ]; then
    echo "ABI not generated in protocol package yet. Please run npm install && npx hardhat compile in ../protocol"
    exit 1
fi

paths=("shared/SignalService.sol" "shared/SignalServiceForkRouter.sol")

names=("SignalService" "SignalServiceForkRouter")

for (( i = 0; i < ${#paths[@]}; ++i ));
do
    lower=$(echo "${names[i]}" | tr '[:upper:]' '[:lower:]')
    jq .abi ../protocol/out/${paths[i]}/${names[i]}.json > bindings/v4/$lower/${names[i]}.json
    abigen --abi bindings/v4/$lower/${names[i]}.json \
    --pkg $lower \
    --type ${names[i]} \
    --out bindings/v4/$lower/${names[i]}.go
done

exit 0
