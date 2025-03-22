---
title: Based Preconfirmations
description: Core concept page for "Based Preconfirmations".
---

Taiko Alethia is implementing based preconfirmations to enhance transaction finality, reducing the current 12-second block time to sub-second finality. This significantly improves UX, particularly for applications requiring fast transaction execution. Based preconfirmations allow transactions to receive early inclusion guarantees from preconfirmers, providing users with immediate execution assurance.

## What Are Based Preconfirmations?

A preconfirmation (preconf) is a cryptographic commitment from a preconfer (an L1 validator opting into preconfirmations) that a transaction will be included in a future block. This allows transactions to be treated as final within milliseconds, significantly improving UX while maintaining Ethereum's security model.

Based preconfirmations rely on two key mechanisms:

1. Preconfer Slashing: Preconfirmers opt into additional slashing conditions to ensure honest commitments.
2. Preconfer Forced Inclusion: Preconfirmers must forcefully include preconfirmed transactions in their proposer slot, ensuring execution.

If a preconfirmer fails to honor commitments, they face slashing penalties proportional to the economic security required.

## Preconfirmation Types: Execution vs. Inclusion

There are two primary types of preconfirmations:

1. Inclusion Preconfirmations

- Guarantees that the transaction will be eventually included in L1.
- No strict guarantee on when it will execute or in what order.
- Often used in systems that rely on external MEV solutions.

2. Execution Preconfirmations

- Ensures a transaction's exact execution ordering and state before L1 inclusion.
- Provides a stronger guarantee for applications like DeFi, high-frequency trading, and gaming.
- Transactions are executed immediately in L2 based on the preconfirmed state.

Execution preconfirmations remove uncertainty, making applications feel as responsive as centralized systems while preserving Ethereum's security model.

## Taiko's Preconfirmation Implementation

Taiko is implementing preconfirmations as an EigenLayer AVS (Actively Validated Service). This implementation reduces the waiting time for transaction confirmations from 12 seconds to sub-second finality.

### How Taiko Preconfirmations Work

The preconfirmation process follows seven key steps:

#### Step 1: Registration

L1 validators opt-in to become preconfirmers by staking collateral and registering with the PreconfServiceManager contract, which interacts with EigenLayer middleware.

#### Step 2: Election

A single preconfer is elected from the registered validators for each slot. If the current proposer is registered as a preconfer, they will be chosen. Otherwise, the next preconfer in the lookahead will provide preconfirmations.

#### Step 3: Request Submission

Users submit transactions to the Taiko public mempool. Transactions with higher L2 priority fees have a better chance of being preconfirmed, as the fee goes to the preconfer.

#### Step 4: Preconfirmation Publication

The elected preconfer collects transactions from the L2 mempool, builds an L2 block, and propagates this block to the Taiko network. This propagation serves as the preconfirmation.

#### Step 5: State Sync

Taiko full nodes verify the preconfirmed block's signature, execute the L2 transactions, and provide users with the latest preconfirmed state without waiting for L1 inclusion.

#### Step 6: L1 Inclusion

The preconfirmer must submit preconfirmed L2 blocks to the L1 Taiko inbox contract. This is done either through forced inclusion lists in MEV-Boost (if the preconfer is the current slot's proposer) or via the L1 mempool.

#### Step 7: Slashing

If a preconfer fails to honor their commitments—either by not including preconfirmed transactions or by submitting an incorrect lookahead—they face slashing penalties, which are enforced through the EigenLayer slashing mechanism.

For more detailed technical information, please see the [Taiko Preconfirmation Design Doc](https://github.com/NethermindEth/Taiko-Preconf-AVS/blob/master/Docs/design-doc.md).

## Implementation Architecture

![Taiko Preconfirmation Architecture](~/assets/content/docs/taiko-alethia-protocol/based-preconfirmation.png)

The above diagram shows the preconfirmation architecture with the permissionless gateway connecting users with Ethereum contracts. Users can submit transactions through two routes:

1. **Route 1**: Through an RPC endpoint directly to the gateway
2. **Route 2**: Through a Taiko Node which then connects to the gateway

The preconfirmation system interacts with Ethereum contracts including TaikoInbox.sol and PreconfRegistry.sol, providing fast preconfirmation with economic security. The architecture ensures that based fallback will always be an option.

## Benefits of Based Preconfirmations

### Sub-Second Finality

Preconfirmations enable transactions to achieve practical finality within ~200ms, dramatically improving UX for latency-sensitive applications like DEXs, gaming, and DeFi.

### Stronger Economic Security

Preconfirmers stake collateralized ETH and face slashing penalties for dishonesty, reducing reliance on centralized sequencers while maintaining Ethereum's security guarantees.

### Eliminating Block Time Constraints

With based preconfirmations, transactions are secured instantly rather than waiting for fixed block proposal times, removing perceived waiting times for users.

### Censorship Resistance & Trust-Minimization

Based preconfirmations leverage Ethereum validators to sequence transactions, ensuring decentralized sequencing with resistance to censorship by MEV players.

## Summary

Based preconfirmations enable sub-second finality (~200ms) by allowing Ethereum L1 validators to issue cryptographic guarantees on transaction inclusion and execution before block finalization. Transactions are prioritized based on execution preconfirmations (strict order + execution guarantee) or inclusion preconfirmations (eventual inclusion with flexible execution). Preconfirmers stake collateral, ensuring economic security via forced inclusion and slashing penalties for misbehavior.
