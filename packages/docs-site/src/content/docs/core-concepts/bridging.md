---
title: Bridging
description: Core concept page for "Bridging".
---

Bridges are foundational for cross-chain users and applications. Users might come to another chain, such as Taiko (a ZK-rollup). To do this, they need to bridge over funds. Notoriously, bridging has been a dangerous operation. How do you make sure that this bridge is secure?

Let's explain bridging on Taiko. We will answer the following questions:

- [How does the Taiko protocol enable secure cross-chain messaging?](#cross-chain-messaging)
- [What is the Taiko signal service?](#the-signal-service)
- [How does Taiko's bridge implementation work?](#how-the-bridge-works)

## Cross-chain messaging

The Taiko protocol's design, specifically its Ethereum-equivalence enables secure cross-chain messaging. Let's see how it works by simply using merkle proofs.

### Taiko stores block hashes of each chain

Taiko deploys two smart contracts which store the hashes of the other chain:

- TaikoL1 stores a blockNumber->blockHash mapping `l2Hashes` (deployed on Ethereum)
- TaikoL2 stores a blockNumber->blockHash mapping `l1Hashes` (deployed on Taiko)

Every time an L2 block is created on Taiko, the hash of the enclosing block on L1 is stored in the TaikoL2 contract. And every time an L1 block is verified, the L2 hash is stored in the TaikoL1 contract (only the latest one, if multiple ones are verified at once).

### Merkle trees enable verifying values exist on the other chain

Merkle trees are a data storage structure that allows a lot of data to be fingerprinted with a single hash, called the merkle root. The way that they are structured enables one to verify that some value exists within this large data structure, without actually needing to have access to the entire merkle tree. To do this, the verifier would need:

- The merkle root, this is the single "fingerprint" hash of the merkle tree
- The value, this is the value we are checking is inside the merkle root
- A list of intermediate sibling hashes, these are the hashes that enable the verifier to re-calculate the merkle root

You can get the latest known merkle root stored on the destination chain by calling `getCrossChainBlockHash(0)` on the TaikoL1/TaikoL2 contract. You can get the value / message to verify and the sibling hashes for that latest known merkle root by asking for it with the standard RPC call `eth_getProof` on the "source chain". Then you just need to send them to be verified against that latest known block hash that is stored in a list on the "destination chain".

A verifier will take the value (a leaf in the merkle tree) and the sibling hashes to re-calculate the merkle root. If the calculated merkle root matches the one that is stored in the destination chain's list of block hashes (the block hashes of the source chain), then we have proved that the message was sent on the source chain, assuming the source chain block hashes stored on the destination chain were correct.

## The signal service

Taiko's signal service is a smart contract available on both L1 and L2, available for any dapp developer to use. It's what uses the previously mentioned merkle proofs to provide a service for secure cross-chain messaging.

You can store signals and check if a signal was sent from an address. It also exposes one more important function: `isSignalReceived`.

What does this function do? The first thing to understand is that the Taiko protocol maintains two important contracts:

- `TaikoL1`
- `TaikoL2`

These contracts both keep track of the block hashes on the **other chain**. So TaikoL1, which is deployed on Ethereum, has access to the latest block hashes on Taiko. And TaikoL2, which is deployed on Taiko, has access to the latest block hashes on Ethereum.

So, `isSignalReceived` can prove on either chain that you sent a signal to the Signal Service on the other chain. A user or dapp can call `eth_getProof`(https://eips.ethereum.org/EIPS/eip-1186) which generates a merkle proof.

You need to provide `eth_getProof` with:

1. The signal (the data you want to prove exists within the storage root of some block on the chain)
2. The address of the signal service (the contract address which stores the provided signal)
3. The block number you are asserting the signal was sent on (optional—if you don't provide this, it will default to the latest block number)

And, `eth_getProof` will generate a merkle proof (it will give the necessary sibling hashes and the height of the block, that along with the signal, can rebuild the merkle storage root of the block you are asserting the signal exists in).

This means, assuming that the hashes which TaikoL1 and TaikoL2 maintain are correct, we can reliably send **cross-chain messages**.

Let's walk through an example:

1. First, we can send a message on some source chain, and store it on the signal service.
2. Next, we call `eth_getProof`, which will give us a proof that we did indeed send a message on the source chain.
3. Finally, we call `isSignalReceived` on the destination chain's SignalService which essentially just verifies the merkle proof. `isSignalReceived` will look up the block hash you are asserting you had stored a message on the source chain (where you originally sent the message), and with the sibling hashes inside the merkle proof it will rebuild the merkle root, which verifies the signal was included in that merkle root—meaning it was sent.

And boom! We have sent a cross-chain message. If this is confusing, you can also find a simple dApp that was built during one of our workshops to demonstrate the fundamentals. You can find it [here](https://github.com/taikoxyz/MessageServiceShowCaseApp).

## How the bridge works

The bridge is a set of smart contracts and a frontend web app that allow you to send testnet ETH and ERC-20, ERC-1155 and ERC-721 tokens between Ethereum and Taiko. This bridge is just one possible implementation built on top of Taiko's core protocol, specifically the signal service which anybody can use to build bridges.

First, here is a flowchart of how our bridge dapp implementation works, which uses the signal service:

![bridging send message flowchart](~/assets/content/docs/core-concepts/bridging-send-message.excalidraw.png) \
![bridging process message flowchart](~/assets/content/docs/core-concepts/bridging-process-message.excalidraw.png)

### How does Ether bridging work?

Taiko's bridge utilizes the Signal Service we described. Here is the general user flow for Taiko's bridge:

1. The user sends their funds to the Bridge contract
2. The Bridge locks the Ether, and stores a message by calling `sendSignal(message)` on the SignalService contract
3. The user receives Ether on the destination chain, if they (or another) provide a valid merkle proof that the message was received on the source chain

With the current design there are 2 ways to bridge `Ether`:

1. `Ether` only case: The user interacts directly with the Bridge contract by calling `sendMessage`
2. `ERC-XXX` + `Ether` + case: The user interacts with the `ERCXXXVault` (ERC20, ERC721, ERC1155) because he/she wants to bridge over some tokens, but in case he/she fills the `message.value` field, also `Ether` will be bridged

### How does ERC-20 (or ERC-721, ERC-1155) bridging work?

ERC-20 tokens originate from a canonical chain. To send a token and bridge it to the other chain, a new BridgedERC20 contract needs to be deployed on the destination chain.

#### Bridge from canonical chain to destination chain

Here are the overall steps for transferring canonical ERC-20 (the overall process is identical for ERC-721, and ERC-1155 token types as well!) from a source chain to the destination chain:

1. A contract for the ERC-20 (or ERC-721, ERC-1155) must first be deployed on the destination chain (will be done automatically by the ERC20Vault if not already deployed)

2. Call `sendToken` on the source chain ERC20Vault, this will **transfer** the amount by using the `safeTransferFrom` function on the canonical ERC-20 contract, on the source chain, to the ERC20Vault.

3. The vault contract (via the Bridge) sends a message to the Signal Service (on the source chain), this message will contain some metadata related to the bridge request, but most importantly it includes the calldata for the `receiveToken` method.

4. Process the message on the destination chain by submitting a merkle proof (generated from the source chain), proving that a message is included in the state of the source chain Signal Service. After verifying this occurred and doing some checks, it will attempt to invoke the `receiveToken` method encoded in the message. This will **mint** ERC-20 (or ERC-721, ERC-1155) on the BridgedERC20 contract to the `to` address on the destination chain!

#### Bridge from destination chain back to the canonical chain

Okay now let's do the reverse, how do we transfer a bridged token from a source chain to the destination chain? (Destination chain in this case is the canonical chain, where the original token lives.)

1. A contract for the ERC-20 (or ERC-721, ERC-1155) already exists on the canonical chain, so no need to deploy a new one.
2. Call `sendToken` on the source chain token vault contract, this will **burn** the ERC-20 on the BridgedERC20 contract.
3. The vault contract (via the Bridge) sends a message to the Signal Service (on the source chain), this message will contain some metadata related to the bridge request, but most importantly it includes the calldata for the `receiveToken` method.
4. Process the message on the destination chain by submitting a merkle proof (generated from the source chain), proving that a message is included in the state of the source chain Signal Service. After verifying this occurred and doing some checks, it will attempt to invoke the `receiveToken` method encoded in this message. This will **transfer** the amount from the destination chain TokenVault to the `to` address on the destination chain.
