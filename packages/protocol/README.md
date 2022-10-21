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
yarn test:integration
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

## Contract Flow

### Bridge

`contracts/bridge/Bridge.sol` is to be deployed on both the Layer 1 and Layer 2 chains.

#### Bridging Ether

To bridge from Layer 1 to Layer 2, the process starts at `Bridge.sendMessage(message)` on Layer 1. The message must have a `depositValue`, `callValue`, and `processingFee` that sum up to the amount of Ether `msg.value`. The `destChainId` of the message must be different than `block.chainid`, and the chainId must be enabled in `state.destChains` by calling `Bridge.enableDestChain(chainId)`.

The `msg.value` amount of Ether will be sent to the Layer1 `EtherVault` contract to be held. Then, the mesage will be hashed and stored as a `signal`.

The bridge will use `LibBridgeSignal.sendSignal(bridgeContractAddress, signalHash)` to store the signal being sent as a boolean `1`, and then use `LibBridgeData.MessageSent(signal, message)` event as an indicator to an off-chain relayer that a message has been sent to be processed on Layer 2.

On the Layer 2 Bridge, the relayer, upon receipt of the Layer 1 `LibBridgeData.MessageSent` event, `Bridge.processMessage(message, proof)` must be called. A proof must be generated to pass in as the `proof`. `processMessage` will use `LibBridgeProcess.processMessage(state, addressResolver, message, proof)` to verify the message is valid.

`LibBridgeProces.processMessage` requires the message's `destChainId`, set earlier, is equal to the current `block.chainid`. Then, it will hash the message to generate the `signal`, and then require the internal `state.messageStatus` of the signal is equal to `LibBridgeData.MessageStatus.NEW` to ensure the message has not been processed already.

It will then require that the signal has been received, using `LibBridgeSignal.isSignalReceived(resolver, srcBridge, sender, signal, proof)`, and, using Merkle Trie verification via `LibTrieProof`, and the synced header hash from the `TaikoL2` contract, make sure the block has been synced to by comparing the merkle proof block header hash. The proof generated is proof that the storage of the `srcBridge` address contains a key, generated wth `_key(sender, signal)` on LibBridgeSignal, is equal to the value of `bytes32(uint256(1))`, proving that bridge has sent the signal from the Layer 1 chain. You can generate the proof with `eth_getProof` RPC call to Layer 1.

If that passes verification, the `EtherVault.receiveEither()` call is made to receive Ether on Layer 2. Then, the ether is sent to the `message.owner`.

The message status is updated if it succeeded to `LibBridgeData.MessageStatus.Done`, otherwise, to `LibBridgeData.MessageStatus.RETRIABLE`. Either way, `processMessage` can never be called again for this message. If it failed, caller must use `retryMessage` instead.

To finish off, a refund is calculated and sent to the `message.refundAddress`, or if it is not sent, the `message.owner`. In either case, the `msg.sender` gets the `message.processingFee` for being the first attempt relayer, and the `refundAddress` gets the `refundAmount` if it exists.

The funds should be successfully bridged now.

#### Bridging ERC20

#### Bridging ERC721

#### Bridging ERC1155
