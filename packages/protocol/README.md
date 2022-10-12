# Taiko Protocol

This repository contains rollup contracts on both L1 and L2 and other assisting code. Taiko L2's chain ID is [167](https://github.com/ethereum-lists/chains/pull/1611).

## Deployment

To deploy TaikoL1 on the hardhat network, run:

```bash
yarn deploy:hardhat
```

## Testing

To run test cases on hardhat network:

```bash
yarn test
```

To run test cases that rely on a go-ethereum node:

```bash
yarn test:geth
```

## Generate L2 genesis JSON's `alloc` field

```bash
yarn compile && yarn generate:genesis config.json
```

The specified `config.json` should contain:

-   contractOwner `String`: Owner address of the pre-deployed L2 contracts.
-   chainId `Number`: Chain id of the L2 network.
-   seedAccounts `Array`: _Account address_ and _pre-mint ETH amount_ k/v pairs.
-   predeployERC20 `Boolean`: Whether to pre-deploy an ERC-20 token.

Example:

```json
{
    "contractOwner": "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",
    "chainId": 167,
    "premintEthAccounts": [
        { "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39": 1024 },
        { "0x79fcdef22feed20eddacbb2587640e45491b757f": 1024 }
    ],
    "predeployERC20": true
}
```

the script above will output two JSON files:

-   `./deployments/l2_genesis_alloc.json`: the `alloc` field which will be used in L2 genesis JSON file
-   `./deployments/l2_genesis_storage_layout.json`: the storage layout of those pre-deployed contracts


## Github Actions

Each commit will automatically trigger the GitHub Actions to run. If any commit message in your push or the HEAD commit of your PR contains the strings [skip ci], [ci skip], [no ci], [skip actions], or [actions skip] workflows triggered on the push or pull_request events will be skipped.
