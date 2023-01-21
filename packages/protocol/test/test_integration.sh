#!/bin/bash

set -eou pipefail

DIR=$(cd $(dirname ${BASH_SOURCE[0]}); pwd)
TEST_NODE_CONTAINER_NAME_L1="test-ethereum-node-l1"
TEST_NODE_CONTAINER_NAME_L2="test-ethereum-node-l2"
TEST_IMPORT_TEST_ACCOUNT_ETH_JOB_NAME="import-test-account-eth"
TEST_ACCOUNT_ADDRESS="0xdf08f82de32b8d460adbe8d72043e3a7e25a3b39"
TEST_ACCOUNT_PRIV_KEY="2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501200"

if ! command -v docker &> /dev/null 2>&1; then
    echo "ERROR: `docker` command not found"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "ERROR: docker daemon isn't running"
    exit 1
fi

docker rm --force $TEST_NODE_CONTAINER_NAME_L1 \
  $TEST_NODE_CONTAINER_NAME_L2 \
  $TEST_IMPORT_TEST_ACCOUNT_ETH_JOB_NAME &> /dev/null

# Start a test ethereum node
docker run -d \
  --name $TEST_NODE_CONTAINER_NAME_L1 \
  -p 18545:8545 \
  ethereum/client-go:v1.10.26 \
  --dev --http --http.addr 0.0.0.0 --http.vhosts "*" \
  --http.api debug,eth,net,web3,txpool,miner

docker run -d \
  --name $TEST_NODE_CONTAINER_NAME_L2 \
  -p 28545:8545 \
  gcr.io/evmchain/hardhat-node:latest \
  hardhat node --hostname "0.0.0.0"

function waitTestNode {
  echo "Waiting for test node: $1"
  # Wait till the test node fully started
  RETRIES=120
  i=0
  until curl \
      --silent \
      --fail \
      --noproxy localhost \
      -X POST \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","id":0,"method":"eth_chainId","params":[]}' \
      $1
  do
      sleep 1
      if [ $i -eq $RETRIES ]; then
          echo 'Timed out waiting for test node'
          exit 1
      fi
      ((i=i+1))
  done
}

waitTestNode http://localhost:18545
waitTestNode http://localhost:28545

# Import ETHs from the random pre-allocated developer account to the test account
docker run -d \
  --name $TEST_IMPORT_TEST_ACCOUNT_ETH_JOB_NAME \
  --add-host host.docker.internal:host-gateway \
  ethereum/client-go:latest \
  --exec 'eth.sendTransaction({from: eth.coinbase, to: "'0xdf08f82de32b8d460adbe8d72043e3a7e25a3b39'", value: web3.toWei(1024, "'ether'")})' attach http://host.docker.internal:18545

function cleanup {
  docker rm --force $TEST_NODE_CONTAINER_NAME_L1 \
    $TEST_NODE_CONTAINER_NAME_L2 \
    $TEST_IMPORT_TEST_ACCOUNT_ETH_JOB_NAME &> /dev/null
}

trap cleanup EXIT INT KILL ERR

# Run the tests
PRIVATE_KEY=$TEST_ACCOUNT_PRIV_KEY \
  npx hardhat test --network l1_test --grep "^$TEST_TYPE"