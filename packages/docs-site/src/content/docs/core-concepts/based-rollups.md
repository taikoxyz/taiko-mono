---
title: Based Rollup
description: Core concept page for based rollups.
---

Taiko Alethia is a based rollup, meaning its sequencing is driven by Ethereum (L1) rather than a centralized or decentralized sequencer. Instead of relying on external sequencers, **Ethereum validators handle sequencing**, ensuring **maximum decentralization, economic alignment with L1, and strong censorship resistance**.

Unlike rollups with centralized sequencers, based rollups **fully inherit Ethereum’s liveness and security guarantees**, making them a **natural extension of Ethereum itself**.

For more information, explore our [learning resources](/resources/learning-resources).

## The Role of a Based Rollup

A based rollup is an L2 that delegates block sequencing to L1 validators, meaning the rollup’s transaction ordering is determined by Ethereum’s consensus mechanism. The key properties of based rollups include:

- **L1-Driven Sequencing**: Ethereum’s block proposers select the next rollup block, ensuring a permissionless and censorship-resistant system.
- **No External Sequencer**: Unlike rollups with centralized or committee-based sequencers, based rollups have no additional trust assumptions.
- **Economic Alignment with L1**: The MEV generated on the rollup flows directly to Ethereum validators, reinforcing Ethereum’s economic security.
- **No Extra Consensus Mechanism**: There is no separate PoS-based sequencing layer, reducing complexity and ensuring simplicity.

## Comparison with Other Rollup Sequencing Models

| Feature                     | Based Rollup (L1 Sequenced)            | Centralized Sequencer                                | Shared Sequencer                                    |
| --------------------------- | -------------------------------------- | ---------------------------------------------------- | --------------------------------------------------- |
| **L1 Economic Alignment**   | ✅ Yes, MEV benefits Ethereum          | ❌ No, MEV captured by sequencer                     | ❌ No, sequencer captures MEV                       |
| **Censorship Resistance**   | ✅ Yes, inherits Ethereum's resistance | ❌ No, sequencer can censor                          | ✅ Yes, but depends on operator set                 |
| **Decentralization**        | ✅ Maximum (Ethereum validators)       | ❌ Single-point of failure                           | ✅ Multi-party, but still an additional trust layer |
| **Simplicity**              | ✅ No extra infra needed               | ❌ Requires separate sequencer                       | ❌ Requires coordination mechanism                  |
| **L1 Liveness Inheritance** | ✅ Yes, 100%                           | ❌ No, separate infra may fail                       | ❌ No, depends on sequencer uptime                  |
| **Gas Overhead**            | ✅ Minimal, uses L1 inclusion          | ❌ Higher, sequencer requires signature verification | ❌ Higher, additional coordination required         |

## Why Based Rollups Are Superior

1. **Decentralization at the Root Level**

   - Based rollups eliminate single points of failure by relying solely on Ethereum validators.
   - Unlike rollups with centralized sequencers, there’s no risk of operator downtime, misbehavior, or cartelization.

<br/>

2. **Security Through L1 Alignment**

   - Ethereum validators naturally include rollup transactions, ensuring that rollup security is directly tied to Ethereum’s own security.
   - This eliminates the risk of sequencer reorgs, censorship, or bribery attacks that centralized sequencers can be prone to.

<br/>

3. **L1-Level Censorship Resistance**

   - Based rollups inherit Ethereum’s censorship resistance guarantees.
   - Transactions cannot be censored by any external party since L1 validators are already highly decentralized and economically incentivized to include all transactions.

<br/>

4. **Simplicity & Cost-Efficiency**

   - No need for extra sequencer infrastructure, complex fallback mechanisms, or governance layers.
   - **No additional gas overhead**—transactions are simply included in Ethereum blocks, making based rollups more efficient and cheaper for users.

## Summary

Based rollups are the simplest, most decentralized, and most Ethereum-aligned scaling solution. By leveraging Ethereum for sequencing, Taiko Alethia achieves:

- **Maximum decentralization** (no extra trust assumptions)
- **Full censorship resistance** (inherits L1 guarantees)
- **Strong economic alignment with Ethereum**
- **Efficient gas usage** (no additional sequencer overhead)
- **Enhanced security** (Ethereum validators enforce correctness)

---
