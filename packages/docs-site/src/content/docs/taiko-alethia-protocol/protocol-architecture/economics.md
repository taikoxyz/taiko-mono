---
title: Economics
description: Core concept page for "Economics".
---

Taiko Alethia's **based rollup design** and **multiproving architecture** create a unique economic cycle. The protocol ensures fair compensation for both **block proposers** and **block provers**, while sustaining the network through the **Taiko DAO Treasury**.

The following diagram illustrates **Taiko Alethia's transaction fee flow**:

![Economics](../../../../assets/content/docs/taiko-alethia-protocol/based-economics.png)

---

## **Transaction Fees and Their Allocation**

When a **user submits a transaction** on **Taiko L2**, they pay a **transaction fee** that consists of:

1. **Priority Fee** → Sent directly to the **L2 block proposer**.
2. **Base Fee** → Split between the **L2 block proposer** and the **Taiko DAO Treasury**.

### **Fee Breakdown**

| Component           | Recipient              | Purpose                                                 |
| ------------------- | ---------------------- | ------------------------------------------------------- |
| **Priority Fee**    | **L2 Block Proposer**  | Incentivizes faster inclusion of transactions.          |
| **75% of Base Fee** | **L2 Block Proposer**  | Compensation for proposing the block.                   |
| **25% of Base Fee** | **Taiko DAO Treasury** | Funds ecosystem development and network sustainability. |

---

## **Block Proposer Responsibilities & Costs**

The **L2 block proposer** is responsible for:

- Aggregating and ordering transactions into **L2 blocks**.
- Submitting **L2 blocks** to **Ethereum L1** by calling `proposeBlock` in `TaikoInbox.sol`.

### **Costs Incurred by L2 Block Proposer**

1. **L1 Fee** → Paid to **Ethereum L1** via `TaikoInbox.sol` when proposing an L2 block.
2. **Prover Fee** → Paid to the **block prover** for proving the correctness of the block.

---

## **Block Prover Responsibilities & Costs**

The **block prover** is responsible for:

- Generating cryptographic proofs to verify the correctness of **proposed L2 blocks**.
- Submitting proofs to **Ethereum L1** for verification.

### **Costs Incurred by Block Prover**

1. **Computation Costs** → Proof generation requires significant computational resources.
2. **Gas Costs** → Publishing proofs to **Ethereum L1** incurs gas fees.

---

## **Network Sustainability & Taiko DAO Treasury**

- **The Taiko DAO Treasury receives 25% of the base fee**, ensuring long-term sustainability of the protocol.
- The DAO uses these funds to **support development, research, security, and governance**.
- The **liveness bond** required for Taiko Alethia can be found on the [Network Configuration](/network-reference/network-configuration) page.

---
