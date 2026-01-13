---
title: Bridging
description: Core concept page for "Bridging".
---

Bridges are essential for cross-chain interoperability, allowing users and applications to transfer assets and messages between Ethereum and Taiko Alethia. However, cross-chain messaging and asset transfers introduce potential security risks. Taiko Alethia implements a secure bridge design leveraging Ethereum-equivalence, Merkle proofs, and the Signal Service smart contract.

This page explains how Taiko's bridge works and answers key questions:

- [How does the Taiko Alethia protocol enable secure cross-chain messaging?](#cross-chain-messaging)
- [What is the Taiko Signal Service?](#the-signal-service)
- [How does Taiko Alethia's bridge implementation work?](#how-the-bridge-works)

## Cross-chain messaging

Taiko Alethia uses a **trust-minimized**, **Ethereum-equivalent** design for secure cross-chain messaging. This is achieved by synchronizing **world state roots** between L1 (Ethereum) and L2 (Taiko) and using **Merkle proofs** for verification.

### Storing block hashes across chains

Two smart contracts are responsible for maintaining cross-chain state:

- **TaikoInbox** (deployed on Ethereum) → Stores L2 world state roots
- **TaikoAnchor** (deployed on Taiko) → Stores L1 world state roots

Whenever an L2 block is created, the corresponding world state root of the enclosing Ethereum L1 block is stored in the [`TaikoAnchor`](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.0/packages/protocol/contracts/layer2/based/TaikoAnchor.sol#L150) contract using the `anchor` transaction. This ensures that only valid state transitions are recognized.

Similarly, the L2 world state root is stored in [`TaikoInbox`](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.0/packages/protocol/contracts/layer1/based/TaikoInbox.sol#L699) using the `syncChainData` function.

### Verifying values across chains using Merkle proofs

A Merkle tree is a data structure that enables efficient verification of whether a specific value exists within a dataset without requiring full access to all data. The Merkle tree consists of:

- **Merkle root**: A cryptographic fingerprint representing the entire dataset.
- **Merkle proof**: A series of intermediate hashes that allow recomputing the Merkle root.
- **Leaf node**: The actual value being verified.
- **Sibling hashes**: A list of intermediate hashes required to reconstruct the Merkle root.

By leveraging Merkle trees, Taiko Alethia ensures that messages and transactions sent on one chain can be securely validated on the other. **Sibling hashes** play a critical role in this process, as they provide the necessary path for recomputing the Merkle root efficiently.

## The Signal Service

The **Signal Service** is a core component enabling decentralized and secure messaging. It is deployed on both L1 and L2, allowing any contract or user to send and verify messages.

### Key functions

- **`sendSignal(message)`**: Stores a message in the Signal Service contract.
- **`verifySignalReceived(message, proof)`**: Checks if a message was sent on the source chain using a Merkle proof.

### Verification process

1. The sender calls `sendSignal(message)` on the source chain.
2. The recipient retrieves the **Merkle proof** of the message using `eth_getProof`.
3. The proof is submitted to `verifySignalReceived` on the destination chain.
4. The contract reconstructs the Merkle root using **sibling hashes** and verifies it against stored state roots.
5. If the proof is valid, the message is considered received.

## How the bridge works

The bridge allows **trust-minimized asset transfers** between Ethereum and Taiko. It leverages the **Signal Service** for security, ensuring assets are transferred only if the source chain transaction is **verifiable**.

### Flow of an asset transfer

#### Sending assets from source chain

When a user initiates a transfer:

1. The user sends assets (ETH or ERC tokens) to the **Bridge contract**.
2. The Bridge contract:

- Locks the ETH/ERC token.
- Calls `sendSignal(message)` on the Signal Service.

3. The signal is stored on the source chain.

**Diagram: Sending a message on the source chain**

![Bridging source chain process](../../../../assets/content/docs/taiko-alethia-protocol/bridging-source-chain.webp)

#### Receiving assets on destination chain

To complete the transfer:

1. A relayer (or user) submits a **Merkle proof** from the source chain.
2. The **Bridge contract** verifies the proof using the **Signal Service**.
3. If valid:

- ETH/ERC tokens are released to the recipient.
- The transfer is marked as **complete**.

**Diagram: Processing a message on the destination chain**

![Bridging destination chain process](../../../../assets/content/docs/taiko-alethia-protocol/bridging-dest-chain.webp)

## Ether bridging

Taiko Alethia's bridge supports **Ether transfers** in two cases:

1. **Direct ETH transfer**: The user calls `sendMessage` on the Bridge contract.
2. **ETH + ERC token transfer**: The user calls `sendToken` on the `ERCXXXVault`, including ETH as part of the transaction.

## ERC-20, ERC-721, and ERC-1155 token bridging

Token bridging requires a **BridgedERC contract** on the destination chain.

### Bridging ERC tokens to the destination chain

1. The ERC token contract must exist on the destination chain.
2. The sender calls `sendToken` on `ERCXXXVault` (source chain).
3. The vault transfers the token to the **Bridge contract** and generates a **Merkle proof**.
4. The recipient submits a **Merkle proof** on the destination chain.
5. If valid, the **BridgedERC contract** mints the corresponding amount.

### Bridging back to the canonical chain

1. The sender calls `sendToken` on the `BridgedERC` contract (destination chain).
2. The contract **burns** the token and generates a **Merkle proof**.
3. The recipient submits the **proof** on the canonical chain.
4. The canonical **TokenVault contract** releases the original token.

## Summary

| Feature             | Taiko Alethia Bridge                  |
| ------------------- | ------------------------------------- |
| **Security Model**  | Merkle proofs + world state root sync |
| **Asset Types**     | ETH, ERC-20, ERC-721, ERC-1155        |
| **Validation**      | On-chain proof verification           |
| **Permissionless**  | No centralized operators              |
| **Trust-Minimized** | No third-party reliance               |

The Taiko Alethia bridge is a **fully decentralized**, **secure**, and **Ethereum-equivalent** solution for cross-chain asset transfers. Developers can use its **Signal Service** for their own bridging implementations.
