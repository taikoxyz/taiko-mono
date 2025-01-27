---
title: What is Taiko Alethia?
description: Core concept page for "What is Taiko Alethia?".
---

Ethereum is too expensive. We believe in Ethereum's core properties (e.g., censorship-resistant, permissionless, secure). We also believe that rollups should **extend** (not augment) these properties.

Taiko Alethia is a [based rollup](/core-concepts/based-rollup) which makes Ethereum cheaper while maintaining its properties:

- [Based contestable rollup](/core-concepts/contestable-rollup): A configurable rollup to reduce transaction fees on Ethereum.
- [Based booster rollup](/core-concepts/booster-rollups): An innovative approach to **native L1 scaling**.

Taiko Alethia is a **highly configurable, fully open source, permissionless (based), Ethereum-equivalent rollup**.

It can be easily configured as a fully ZK rollup, optimistic rollup, or anything in between. There are no centralized actors that operate the network; all operations are permissionlessly run by the community.

## The Taiko Alethia protocol

- **Taiko Alethia Protocol**: A set of smart contracts deployed on Ethereum that describe the Taiko Alethia protocol, a fully open-source scaling solution for Ethereum. In the most fundamental sense, this is what Taiko is. Even Taiko Alethia's governance is written into the protocol contracts.

## Organizations

- **Taiko Community**: Social groups/accounts run by anyone interested, including Taiko Discord, Taiko Twitter, etc.
- **Taiko Labs**: Research & development group for the Taiko Alethia protocol.
- **Taiko Treasury**: Funded by income from the Taiko Alethia protocol (L2 EIP-1559 congestion MEV).
- **Taiko DAO (in progress)**: Governing body of Taiko Token (TAIKO) holders with voting rights over smart contract upgrades, network parameters, and more. Controls all aspects of the Taiko Alethia protocol smart contracts.
- **Taiko Foundation**: Stewards growth and development of the Taiko Alethia protocol and ecosystem. Works for the Taiko DAO and token holders, financing technical developments, ecosystem growth, partnerships, events, and more with full transparency.
- **Taiko Security Council**: Elected by the Taiko DAO to handle emergency actions. Ensures the safety of the Taiko Alethia protocol, implementing necessary upgrades or changes, and controls the Guardian Provers.

## Services operated by Taiko Labs

### Non-critical infrastructure

:::note
Anyone can run these components, not just Taiko Labs. Yes you can sequence blocks on Taiko, host your own bridge using our [signal service](/taiko-alethia-protocol/bridging#the-signal-service), etc.
:::

#### Frontends

- [Bridge UI](https://bridge.taiko.xyz)
- [Network status page](https://status.taiko.xyz)
- [Main homepage](https://taiko.xyz) + [this documentation site](https://docs.taiko.xyz)
- [Geth fork diff page](https://geth.taiko.xyz)

#### Backends

- [Event indexer](/api-reference/event-indexer)
- [Bridge relayer](/api-reference/bridge-relayer)
- [Taiko Alethia P2P bootstrapping nodes](/network-reference/alethia-addresses#taiko-labs-bootnode-addresses)
- [Taiko Alethia Taiko Labs' proposers and provers](/network-reference/alethia-addresses)
- [Taiko Hekla P2P bootstrapping nodes](/network-reference/hekla-addresses#taiko-labs-bootnode-addresses)
- [Taiko Hekla Taiko Labs' proposer and provers](/network-reference/hekla-addresses)

### Critical infrastructure

:::caution
This is a vital concern for rollup users. The smart contracts are upgradeable via a multi-sig, which is a **trusted component** until handed over to the DAO. Please look at a third party source regarding any rollup's safety, such as [L2Beat](https://l2beat.com/scaling/projects/taiko).
:::

- [Taiko Alethia contract owners (multi-sig)](/network-reference/alethia-addresses#contract-owners)
- [Taiko Hekla contract owners](/network-reference/hekla-addresses#contract-owners)
