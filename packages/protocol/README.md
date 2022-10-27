# Taiko protocol

This package contains rollup contracts on both L1 and L2, along with other assisting code. Taiko L2's chain ID is [167](https://github.com/ethereum-lists/chains/pull/1611).

## Deploy

Deploy TaikoL1 on hardhat network:

```sh
yarn deploy:hardhat
```

## Test

Run test cases on hardhat network:

```sh
yarn test
```

Run test cases that require a running go-ethereum node:

```sh
yarn test:integration
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
yarn compile && yarn generate:genesis config.json
```

The script will output two JSON files under `./deployments`:

-   `l2_genesis_alloc.json`: the `alloc` field which will be used in L2 genesis JSON file
-   `l2_genesis_storage_layout.json`: the storage layout of those pre-deployed contracts

## Contract flow

### Bridge

`contracts/bridge/Bridge.sol` is to be deployed on both the Layer 1 and Layer 2 chains.

#### Bridging Ether

1. User initiates a bridge transaction with `sendMessage` on the source chain which includes:
    - The amount to send
    - The destination chain's ID
    - The processing fee for the relayer
2. The funds are stored on the `EtherVault` contract and a `signal` is created by hashing the message with the L1 bridge contract address. The `signal` is stored on the `Bridge` contract, and a `MessageSent` event is emitted.
3. The off-chain relayer captures the event and:
    1. Generates a proof from L1 (can check `LibTrieProof.test.ts` to see how to generate one).
    2. Initiates `processMessage` on the destination chain which will verify the signal was sent and check that the message has not been processed already.
4. `processMessage` will verify the proof, and if valid will attempt to send Ether to `message.owner`, marking the message as "DONE". Else, the message will be marked as "RETRIABLE" and `retryMessage` will need to be called.
5. Any remaining funds are sent as a refund

#### Bridging ERC20

#### Bridging ERC721

#### Bridging ERC1155
