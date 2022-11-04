# Taiko protocol

This package contains rollup contracts on both L1 and L2, along with other assisting code. Taiko L2's chain ID is [167](https://github.com/ethereum-lists/chains/pull/1611).

## Deploy

Deploy TaikoL1 on hardhat network:

```sh
pnpm deploy:hardhat
```

## Test

Run test cases on hardhat network:

```sh
pnpm test
```

Run test cases that require a running go-ethereum node:

```sh
pnpm test:integration
```

## Generate L2 genesis JSON's `alloc` field

Start by creating a `config.json`, for example:

```json
{
  // Owner address of the pre-deployed L2 contracts.
  "contractOwner": "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",

  // Chain ID of the Taiko L2 network.
  "chainId": 167,

  // Account address and pre-mint ETH amount as key-value pairs.
  "seedAccounts": [
    { "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39": 1024 },
    { "0x79fcdef22feed20eddacbb2587640e45491b757f": 1024 }
  ],

  // Option to pre-deploy an ERC-20 token.
  "predeployERC20": true
}
```

Next, run the generation script:

```sh
pnpm compile && pnpm generate:genesis config.json
```

The script will output two JSON files under `./deployments`:

- `l2_genesis_alloc.json`: the `alloc` field which will be used in L2 genesis JSON file
- `l2_genesis_storage_layout.json`: the storage layout of those pre-deployed contracts
