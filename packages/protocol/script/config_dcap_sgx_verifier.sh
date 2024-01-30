# for foundry test only!
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
ETHERSCAN_API_KEY=ABC123ABC123ABC123ABC123ABC123ABC1 \
LOG_LEVEL=DEBUG \
REPORT_GAS=true \
SGX_VERIFIER_ADDRESS=0x1fA02b2d6A771842690194Cf62D91bdd92BfE28d \
TIMELOCK_ADDRESS=0xB2b580ce436E6F77A5713D80887e14788Ef49c9A \
ATTESTATION_ADDRESS=0xC9a43158891282A2B1475592D5719c001986Aaec \
TCB_INFO_PATH=/test/automata-attestation/assets/0923/tcbInfo.json \
QEID_PATH=/test/automata-attestation/assets/0923/identity.json \
V3_QUOTE_PATH=/test/automata-attestation/assets/0923/v3quote.json \
MR_ENCLAVE=0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef \
MR_SIGNER=0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef \
forge script script/SetDcapParams.s.sol:SetDcapParams \
    --fork-url http://localhost:8545 \
    --broadcast \
    --ffi \
    -vvvv \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \ #foundry test key
    --block-gas-limit 100000000