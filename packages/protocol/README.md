# Basic Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/sample-script.js
npx hardhat help
```

## Deployment

To deploy TaikoL1 on the hardhat network, run

```
LOG_LEVEL=debug npx hardhat deploy_L1 \
    --network hardhat \
    --dao-vault 0xdf08f82de32b8d460adbe8d72043e3a7e25a3b39 \
    --team-vault 0xdf08f82de32b8d460adbe8d72043e3a7e25a3b39 \
    --l2-genesis-block-hash 0xee1950562d42f0da28bd4550d88886bc90894c77c9c9eaefef775d4c8223f259 \
    --confirmations 1
```
