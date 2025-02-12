---
title: What is Taiko Alethia?
description: Core concept page for "What is Taiko Alethia?".
---

Ethereum is **expensive** and **congested**. However, Ethereum's core principles—**censorship resistance, permissionless access, and robust security**—are **non-negotiable**. A true scaling solution must **extend** these properties without introducing trust assumptions, centralization, or trade-offs.

## Introducing Taiko Alethia

Taiko Alethia is an **Ethereum-equivalent, permissionless, based rollup** designed to scale Ethereum without compromising its fundamental properties. Unlike traditional rollups that rely on centralized sequencers, Taiko Alethia leverages Ethereum itself for sequencing, ensuring that block ordering is decentralized and censorship-resistant.

### Why Taiko Alethia?

- **Fully Ethereum-equivalent**: Runs an unmodified Ethereum execution layer, making it easy for developers to migrate smart contracts and tooling.
- **No centralized sequencer**: Ethereum L1 validators naturally order transactions in a decentralized way.
- **Multi-proof architecture**: Supports ZK proofs, Trusted Execution Environments (TEE), and Guardian proofs, making it more flexible than single-proof rollups.
- **Configurable proof system**: Can operate as a ZK-rollup, optimistic rollup, or hybrid, depending on security and performance trade-offs.
- **Decentralized proving & proposing**: Permissionless block proposing and proving, eliminating reliance on whitelisted actors.

### Key Concepts in Taiko Alethia

- [Based rollup](/taiko-alethia-protocol/protocol-design/based-rollups): A rollup where Ethereum L1 validators sequence blocks, removing the need for a centralized sequencer.
- [Based contestable rollup](/taiko-alethia-protocol/protocol-design/contestable-rollup): A configurable, multi-proof rollup with hierarchical proving mechanisms to enhance security.

## How Taiko Alethia Works

At its core, Taiko Alethia is a set of smart contracts deployed on Ethereum L1 that enforce execution rules, manage proofs, and facilitate rollup operations.

- **Proposing blocks**: Transactions are proposed permissionlessly by anyone following Ethereum’s sequencing rules.
- **Proving blocks**: Provers submit validity proofs (ZK, TEE, or Guardian) to confirm the correctness of proposed blocks.
- **Verification & contestation**: If a proof is contested, a higher-tier proof can be submitted to verify or dispute the original proof.

---

## Taiko Alethia Governance & Organizations

### Decentralized Organizations

Taiko Alethia operates as a fully decentralized protocol governed by **DAOs, community-run validators, and decentralized incentives**.

| Organization                             | Functionality                                                                            |
| ---------------------------------------- | ---------------------------------------------------------------------------------------- |
| **Taiko Community**                      | Open social groups and discussions (Discord, Twitter, forums).                           |
| **Taiko Labs**                           | Research and development entity supporting the Taiko Alethia protocol.                   |
| **Taiko Treasury**                       | Collects fees from L2 congestion pricing and distributes funds for development.          |
| **Taiko DAO (in progress)**              | Governing body managing smart contract upgrades, network parameters, and protocol funds. |
| **Taiko Foundation**                     | Funds technical development, partnerships, and ecosystem growth.                         |
| **Taiko Security Council (in progress)** | Handles critical protocol security, Guardian Provers, and emergency network decisions.   |

---

## Infrastructure Operated by Taiko Labs

Taiko Labs operates non-critical and critical infrastructure, but anyone can run these components due to Taiko’s open-source and permissionless nature.

### Non-Critical Infrastructure

These services are open-source, meaning anyone can replicate or improve them.

#### Frontends

- [Bridge UI](https://bridge.taiko.xyz) → Interface for asset transfers between L1 & L2.
- [Network status](https://status.taiko.xyz) → Live updates on Taiko Alethia.
- [Homepage](https://taiko.xyz) → Official website and ecosystem.
- [Geth fork diff](https://geth.taiko.xyz) → Fork comparison for Ethereum-equivalence.

#### Backends

- [Event Indexer](/api-reference/event-indexer) → Tracks rollup transactions & events.
- [Bridge Relayer](/api-reference/bridge-relayer) → Facilitates trust-minimized bridging.
- [Taiko Alethia & Hekla P2P Bootstrapping Nodes](https://github.com/taikoxyz/simple-taiko-node/tree/v1.9.1) → Helps decentralized peers sync with the network. Found in their respective `.env.sample` files.
- [Taiko Alethia Taiko Labs' proposers and provers](/network-reference/alethia-addresses)

### Critical Infrastructure

🚨 These components are trusted until full decentralization is achieved via the DAO. 🚨

- [Taiko Alethia contract owners](/network-reference/alethia-addresses#contract-owners)
- [Taiko Hekla contract owners](/network-reference/hekla-addresses#contract-owners)

Taiko Alethia is actively **transitioning towards full decentralization**, following **Ethereum's rollup-centric roadmap**.

---

## Why Taiko Alethia is Superior to Traditional Rollups

| Feature                        | Traditional Rollups                  | Taiko Alethia                          |
| ------------------------------ | ------------------------------------ | -------------------------------------- |
| **Sequencing**                 | Centralized (single sequencer)       | Decentralized (L1 validators sequence) |
| **Proof System**               | Single proof type (ZK or Optimistic) | Multi-proof (ZK, TEE, Guardian)        |
| **Censorship Resistance**      | Operator can censor transactions     | Permissionless transaction inclusion   |
| **Smart Contract Equivalence** | Modified Ethereum (Geth changes)     | 100% Ethereum-equivalent               |
| **Decentralization**           | Relies on multisig governance        | DAO-controlled with open participation |

Taiko Alethia follows Ethereum’s decentralization ethos by ensuring L1 validators remain in control, minimizing trust assumptions, and maximizing rollup neutrality.

---
