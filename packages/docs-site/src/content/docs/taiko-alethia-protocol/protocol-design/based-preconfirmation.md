---
title: Based Preconfirmations
description: Core concept page for "Based Preconfirmations".
---

Taiko Alethia is implementing **based preconfirmations** to enhance transaction finality, reducing the current **12-second block time** to **sub-second finality**. This significantly improves UX, particularly for applications requiring fast transaction execution. Based preconfirmations allow transactions to receive **early inclusion guarantees** from **preconfirmers**, providing users with immediate execution assurance.

## What Are Based Preconfirmations?

A **preconfirmation (preconf)** is a cryptographic commitment from a **preconfer** (an L1 validator opting into preconfirmations) that a transaction will be included in a future block. This allows transactions to be **treated as final within milliseconds**, significantly improving UX while maintaining Ethereum’s security model.

Based preconfirmations rely on two key mechanisms:

1. **Preconfer Slashing**: Preconfirmers opt into **additional slashing conditions** to ensure honest commitments.
2. **Preconfer Forced Inclusion**: Preconfirmers must **forcefully include preconfirmed transactions** in their proposer slot, ensuring execution.

If a preconfirmer fails to honor commitments, they face **slashing penalties** proportional to the economic security required.

## Execution vs. Inclusion Preconfirmations

There are two primary types of preconfirmations:

1. **Inclusion Preconfirmations**

   - Guarantees that the transaction will be **eventually included** in L1.
   - No strict guarantee on when it will execute or in what order.
   - Often used in systems that rely on external MEV solutions.

2. **Execution Preconfirmations**
   - Ensures a transaction’s **exact execution ordering** and state before L1 inclusion.
   - Provides a stronger guarantee for applications like **DeFi, high-frequency trading, and gaming**.
   - Transactions are **executed immediately in L2** based on the preconfirmed state.

Execution preconfirmations **remove uncertainty**, making applications feel **as responsive as centralized systems** while preserving Ethereum’s security model.

## How Based Preconfirmations Work

### 1. Transaction Preconfirmation Flow

1. **Transaction Submission**: A user submits a transaction to a **preconfer** in the proposer lookahead.
2. **Preconfirmation Issuance**: The preconfer **cryptographically signs** a commitment guaranteeing execution in an upcoming block.
3. **Execution Precedence**: Preconfirmed transactions are prioritized in the execution queue over non-preconfirmed transactions.
4. **Onchain Finalization**: The rollup finalizes the batch when the preconfer’s slot is reached, and L1 includes the transactions.

Non-preconfirmed transactions remain in an **execution queue** until a proposer slot is available, ensuring **preconfirmed transactions always execute first**.

### 2. Preconfer Election & Incentives

- L1 **validators opt-in** to provide preconfirmations by staking collateral.
- A **preconfirmer is elected** for each slot from the opted-in validators.
- Preconfirmers earn **preconfirmation fees** in exchange for guaranteeing execution.

### 3. Slashing & Security

Preconfirmers are subject to **two types of faults**, both of which are slashable:

- **Liveness Faults**: If a preconfirmer **misses their proposer slot**, any outstanding preconfirmed transactions are left unexecuted.
- **Safety Faults**: If a preconfirmer **modifies or contradicts** a previously issued promise, they are **fully slashed**.

The economic security of preconfirmations relies on **collateral-backed commitments**, ensuring preconfirmers act honestly.

## Benefits of Based Preconfirmations

### Sub-Second Finality

Preconfirmations enable transactions to achieve **practical finality within ~100ms**, dramatically improving UX for latency-sensitive applications like:

- **Decentralized Exchanges (DEXs)**
- **Real-time gaming applications**
- **DeFi lending and liquidations**
- **Cross-chain interactions**

### Stronger Economic Security

Preconfirmers stake **collateralized ETH** and face **slashing penalties** for dishonesty, ensuring users can trust preconfirmation commitments.
This reduces reliance on **centralized sequencers** while preserving Ethereum’s security guarantees.

### Eliminating Block Time Constraints

Traditional rollups suffer from **fixed block proposal times**. With based preconfirmations, transactions are **secured instantly**, removing **perceived waiting times**.

### Censorship Resistance & Trust-Minimization

Unlike centralized sequencers, based preconfirmations **leverage Ethereum validators** to sequence transactions, ensuring:

- **Decentralized sequencing**
- **No single point of failure**
- **Resistance to censorship by MEV players**

### Efficient Transaction Pricing & MEV Reduction

- Preconfirmers **bid for transaction execution slots**, creating **efficient fee markets**.
- Users can **pay a preconfirmation premium** for faster execution.
- This reduces **transaction latency for high-priority users** while keeping normal transactions cost-effective.

### Dynamic Preconfirmation Auctions

Preconfirmations allow for **batch-based bidding** in execution auctions, aligning **transaction inclusion with fair price discovery**:

1. Preconfirmers compete to **include transactions at optimal pricing**.
2. Users select **priority execution or cost-efficient execution**.
3. Batching enables **MEV-resistant inclusion**.

## Preconfirmation Design Approach

The design of based preconfirmations follows these **core principles**:

1. **Proposer Selection & Preconfirmation**

   - L1 validators **opt into** preconfirmations.
   - A **preconfirmer is selected** based on their **stake and slot availability**.
   - The selected preconfirmer **publishes a preconfirmation**.

2. **Execution of Preconfirmed Transactions**

   - Transactions are **processed in real time on L2**.
   - The state is **updated immediately** based on the preconfirmation.

3. **Forced Inclusion in L1 Blocks**

   - Preconfirmed transactions **must be included** in an L1 block.
   - Preconfirmers **submit proof** of inclusion to **avoid slashing**.

4. **Slashing Mechanisms**

   - **Non-inclusion slashing**: If a preconfirmer fails to include a preconfirmed transaction, they **lose stake**.
   - **Misordering slashing**: If an inclusion order is **altered**, the preconfirmer is **penalized**.

5. **Fallback for Non-Preconfirmed Transactions**
   - Non-preconfirmed transactions **wait for proposer inclusion** in a future slot.
   - Ensures **fair access** to execution while **prioritizing preconfirmed transactions**.

## Summary

Based preconfirmations enable sub-second finality (~100ms) by allowing Ethereum L1 validators to issue cryptographic guarantees on transaction inclusion and execution before block finalization. Transactions are prioritized based on execution preconfirmations (strict order + execution guarantee) or inclusion preconfirmations (eventual inclusion with flexible execution). Preconfirmers stake collateral, ensuring economic security via forced inclusion and slashing penalties for misbehavior.
