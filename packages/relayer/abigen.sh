#/bin/sh

if [ ! -d "../protocol/artifacts" ]; then
    echo "ABI not generated in protocol package yet. Please run npm install && npx hardhat compile in ../protocol"
    exit 1
fi

paths=("bridge/TokenVault.sol" "bridge/Bridge.sol" "common/IHeaderSync.sol" "L2/TaikoL2.sol" "L1/TaikoL1.sol")

names=("TokenVault" "Bridge" "IHeaderSync" "TaikoL2" "TaikoL1")

for (( i = 0; i < ${#paths[@]}; ++i ));
do
    jq .abi ../protocol/artifacts/contracts/${paths[i]}/${names[i]}.json > ${names[i]}.json
    lower=$(echo "${names[i]}" | tr '[:upper:]' '[:lower:]')
    abigen --abi ${names[i]}.json \
    --pkg $lower \
    --type ${names[i]} \
    --out contracts/$lower/${names[i]}.go
done

exit 0
