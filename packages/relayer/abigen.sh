#/bin/sh

if [ ! -d "../protocol/out" ]; then
    echo "ABI not generated in protocol package yet. Please run npm install && npx hardhat compile in ../protocol"
    exit 1
fi

paths=("TokenVault.sol" "Bridge.sol" "ICrossChainSync.sol" "TaikoL2.sol" "TaikoL1.sol")

names=("TokenVault" "Bridge" "ICrossChainSync" "TaikoL2" "TaikoL1")

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
