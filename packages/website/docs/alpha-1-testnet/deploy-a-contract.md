---
sidebar_position: 4
---

# 🚀 Deploy a contract

We will deploy a smart contract to Taiko A1 using Foundry.

1. Follow the Foundry Book to install Foundry and init the default project: https://book.getfoundry.sh/getting-started/first-steps
2. From `~/hello_foundry` run `forge create --legacy --rpc-url https://l2rpc.a1.taiko.xyz --private-key <yourPrivateKey> src/Counter.sol:Counter` (replace `<yourPrivateKey>` with the private key of the account deploying the contract)

We are using the `--legacy` flag because EIP-1559 is currently disabled on Taiko. We have plans to re-enable it in the future.

You can use the block explorer to verify that the contract was deployed: https://l2explorer.a1.taiko.xyz/
