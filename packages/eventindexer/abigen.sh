#/bin/sh

if [ ! -d "../protocol/out" ]; then
    echo "ABI not generated in protocol package yet. Please run npm install && pnpm run compile in ../protocol"
    exit 1
fi

paths=("TaikoL1.sol" "Bridge.sol" "AssignmentHook.sol" "SgxVerifier.sol" "TaikoToken.sol")

names=("TaikoL1" "Bridge" "AssignmentHook" "SgxVerifier" "TaikoToken")


for (( i = 0; i < ${#paths[@]}; ++i ));
do
    jq .abi ../protocol/out/${paths[i]}/${names[i]}.json > ${names[i]}.json
    lower=$(echo "${names[i]}" | tr '[:upper:]' '[:lower:]')
    abigen --abi ${names[i]}.json \
    --pkg $lower \
    --type ${names[i]} \
    --out contracts/$lower/${names[i]}.go
done

exit 0
