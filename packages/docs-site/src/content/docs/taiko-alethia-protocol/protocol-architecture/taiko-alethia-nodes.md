---
title: Taiko Alethia nodes
description: Core concept page for Taiko Alethia nodes.
---

Taiko Alethia nodes are minimally modified Ethereum **execution clients** that adhere to Ethereum's **execution-consensus separation model**. The two primary components of a Taiko node are:

- **[taiko-geth](https://github.com/taikoxyz/taiko-geth)** (execution client)
- **[taiko-client](https://github.com/taikoxyz/taiko-client)** (consensus client)

This architecture mirrors Ethereum’s execution/consensus split but **replaces the consensus layer** with Taiko’s own `taiko-client`. The `taiko-client` drives `taiko-geth` over the [Engine API](https://github.com/ethereum/execution-apis/tree/main/src/engine), allowing **modular execution client compatibility**.

![Taiko Alethia nodes diagram](../../../../assets/content/docs/taiko-alethia-protocol/taiko-nodes.png)

## Execution Layer: taiko-geth

[taiko-geth](https://github.com/taikoxyz/taiko-geth) is a fork of [go-ethereum](https://github.com/ethereum/go-ethereum) with **minimal** changes to support Taiko Alethia.

### Functionality:

- Processes and executes **L2 transactions** from the Taiko mempool.
- Maintains **state storage, transaction history, and receipts**.
- Implements **Ethereum-equivalence**, ensuring all EVM opcodes behave identically.
- Supports **modular execution** by allowing future execution clients.

All modifications to `go-ethereum` can be reviewed in the [Geth fork diff](https://geth.taiko.xyz).

## Consensus Layer: taiko-client

[taiko-client](https://github.com/taikoxyz/taiko-mono/tree/main/packages/taiko-client) acts as the consensus component, replacing Ethereum’s traditional **beacon chain**. It interfaces with `taiko-geth` using the **Engine API**.

### Components:

#### `driver`

- Serves as the L2 **consensus client**.
- Monitors **L1 events from TaikoInbox** to detect **proposed batches**.
- Directs the **execution engine** to insert or reorganize blocks through the Engine API.

<br/>

#### `proposer`

- Collects pending transactions from `taiko-geth`’s **txpool**.
- Constructs **batch-compliant txLists** and submits them to **TaikoInbox**.

<br/>

#### `prover`

- Fetches proposed batches from `TaikoInbox` and verifies them.
- Generates **ZK/Secure Enclave proofs** to validate state transitions.

<br/>

## Chain Synchronization Process

The **Taiko Alethia consensus model** differs from Ethereum’s due to its rollup-based structure.

1. **Driver Initialization**
   - Fetches the latest **verified L2 head** from `TaikoInbox`.
   - Tries to sync state **via P2P**.
   - If P2P sync fails, inserts **verified L2 blocks sequentially** using the Engine API.
   - After catching up to the **latest verified L2 block**, proceeds to the following step.

<br/>

2. **Batch Proposal Ingestion**
   - Listens for `TaikoInbox.BatchProposed` events.
   - Retrieves the **transaction calldata** from `TaikoInbox.proposeBatch`.
   - Decompresses `txListBytes` and reconstructs **blocks shared metadata**.

<br/>

3. **Validation and Execution**
   - If `txList` is **valid**, constructs an **L2 anchor transaction** and inserts the block.
   - If `txList` is **invalid**, constructs an **empty L2 block**.

## Batch Proposal Process

1. The **proposer** fetches **pending transactions** from `taiko-geth`.

2. If transaction volume exceeds the **max txList size**, transactions are **split into batches**.

3. The proposer submits **`TaikoInbox.proposeBatch` transactions**, encoding the `txList`.

## Batch Proving Process

Once a batch is proposed:

1. The **prover** retrieves the corresponding **TaikoInbox.proposeBatch** transaction calldata.

2. It waits until the **L2 execution engine** has inserted the blocks.

3. The prover generates a **validity proof**.

For a **valid or invalid txList**, the prover:

1. Constructs a **Merkle proof** verifying the block’s **txRoot**.

2. Verifies the **TaikoAnchor.anchorV3** transaction in the **Merkle Patricia Trie (MPT)**.

3. Submits:
   - `TaikoAnchor.anchorV3` transaction’s **RLP-encoded bytes**.
   - **Merkle proofs**.
   - **Proof-of-validity** to `TaikoInbox.proveBatches`.

<br/>

Even if the txList is invalid, proving ensures that **invalid blocks are mapped to an empty anchor-only block**.

## Taiko Alethia Node APIs

A Taiko Alethia node exposes **Ethereum-equivalent JSON-RPC methods**, making it compatible with standard Ethereum tooling.

### Differences from Ethereum Geth

- **Modified Consensus Rules**: Taiko uses `taiko-client` instead of a traditional beacon chain.

- **Blob Data Handling**: If **EIP-4844 blobs** are enabled, calldata is stored separately.

- **Taiko-Specific Events**: Includes `TaikoInbox.BatchProposed`, `TaikoInbox.BatchesVerified`, etc.

For a complete diff, check the [Geth fork comparison](https://geth.taiko.xyz).

### JSON-RPC API

Supports all **standard Ethereum execution APIs**. See [Ethereum Execution API Docs](https://ethereum.org/en/developers/docs/apis/json-rpc).

### Engine API

Manages consensus-execution communication. See [Engine API Spec](https://github.com/ethereum/execution-apis/blob/main/src/engine/common.md).

### Hive Test Compliance

Taiko Alethia aims to pass the **[Ethereum Hive e2e test suite](https://github.com/ethereum/hive)**, ensuring API and execution consistency.

---
