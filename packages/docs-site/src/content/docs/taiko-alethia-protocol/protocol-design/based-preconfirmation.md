---
title: Based Preconfirmations
description: Core concept page for "Based Preconfirmations".
---

Taiko Alethia is implementing **based preconfirmations** to enhance transaction finality, reducing the current 12-second block time to **sub-second finality**. This significantly improves UX, particularly for applications requiring fast transaction execution. Based preconfirmations allow transactions to receive **early inclusion guarantees** from **preconfirmers**, providing users with immediate execution assurance.

This mechanism is currently **a work in progress (WIP) at Taiko Alethia**, with ongoing research into **design optimizations, economic security, and implementation constraints**.

## What Are Based Preconfirmations?

A **preconfirmation (preconf)** is a cryptographic promise from a **preconfer** (an L1 validator opting into preconfirmations) that a transaction will be included in a future block. This promise allows transactions to be **treated as final within milliseconds**, significantly improving UX while maintaining Ethereum’s security model.

Based preconfirmations rely on two key mechanisms:

1. **Proposer Slashing**: Preconfirmers opt into **additional slashing conditions** to ensure honest commitments.
2. **Proposer Forced Inclusion**: Preconfirmers must **forcefully include preconfirmed transactions** in their proposer slot, ensuring execution.

If a preconfirmer fails to honor commitments, they face **slashing penalties** proportional to the economic security required.

## How Based Preconfirmations Work

### 1. Transaction Preconfirmation Flow

1. **Transaction Submission**: A user requests preconfirmation from the next preconfer in the proposer lookahead.
2. **Preconfirmation Issuance**: The preconfer **signs a promise** guaranteeing execution in an upcoming block.
3. **Execution Precedence**: Preconfirmed transactions are prioritized in the execution queue over non-preconfirmed transactions.
4. **Onchain Finalization**: The rollup finalizes the batch when the preconfer’s slot is reached, and L1 includes the transactions.

Non-preconfirmed transactions remain in an **execution queue** until a proposer slot is available, ensuring **preconfirmed transactions always execute first**.

### 2. Slashing Conditions

Preconfirmers are subject to **two types of faults**, both of which are slashable:

- **Liveness Faults**: If a preconfirmer **misses their proposer slot**, any outstanding preconfirmed transactions are left unexecuted.
- **Safety Faults**: If a preconfirmer **modifies or contradicts** a previously issued promise, they are **fully slashed**.

The economic security of preconfirmations relies on **collateral-backed commitments**, ensuring preconfirmers act honestly.

### 3. Execution Guarantees

Preconfirmations provide **different levels of execution guarantees**:

- **Inclusion Guarantee**: Ensures that the transaction will be included on L1.
- **Ordering Guarantee**: Ensures transaction sequencing aligns with the preconfirmed commitment.
- **Execution Guarantee**: Ensures the transaction executes in the expected state context.

Higher guarantees require **stronger economic commitments**, which impact preconfirmation fees.

## Benefits of Based Preconfirmations

### Sub-Second Finality

Preconfirmations enable transactions to achieve **practical finality within ~100ms**, dramatically improving UX for latency-sensitive applications like **DeFi, trading, and gaming**.

### Stronger Economic Security

Preconfirmers stake collateral and face **slashing penalties** for dishonesty, ensuring users can trust preconfirmation commitments.

### Eliminating Block Time Constraints

Traditional rollups suffer from **fixed block proposal times**. With based preconfirmations, transactions are **secured instantly**, removing **perceived waiting times**.

### Censorship Resistance & Trust-Minimization

Unlike centralized sequencers, based preconfirmations **leverage Ethereum validators** to sequence transactions, ensuring **neutrality and resistance to censorship**.

### Preconfirmation Fees & Incentives

Preconfirmers earn **fees for issuing preconfirmations**, creating a **market-driven mechanism** for transaction prioritization while ensuring proper economic alignment.

## Challenges & Ongoing Development

Taiko Alethia is actively researching **several key challenges** to optimize the design of based preconfirmations:

- **Preconfirmer Discovery**: Ensuring users can efficiently locate and interact with preconfirmers.
- **Latency Optimizations**: Reducing preconfirmation delay to **sub-100ms** for better UX.
- **Preconfirmation Failures**: Developing robust fallback mechanisms in case of liveness faults.
- **Execution Priority Handling**: Preventing front-running risks by maintaining a **secure execution ordering mechanism**.
- **Economic Model Refinement**: Optimizing fee structures and collateral requirements for sustainable preconfirmation markets.

## Summary

Based preconfirmations represent a **game-changing improvement** for rollups by enabling **sub-second finality**, improving **economic efficiency**, and **maintaining decentralization**. Taiko Alethia is actively **developing and refining this mechanism**, with the goal of bringing near-instant finality to **Ethereum-aligned rollups**.
