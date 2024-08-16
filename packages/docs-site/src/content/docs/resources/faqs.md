---
title: FAQs
description: Resource page for listing out FAQs.
---

This page is divided between [General FAQs](#general-faqs) and [Developer FAQs](#developer-faqs).

## General FAQs

---

### What is Taiko?

See [What is Taiko?](/core-concepts/what-is-taiko).

### What is a Type 1 ZK-EVM?

The different types of ZK-EVMs make tradeoffs between compatibility and proof generation cost. A Type 1 ZK-EVM prioritizes compatibility over proof generation cost.

Another term for a Type 1 ZK-EVM is “Ethereum-equivalent”. This term comes from the fact that Type 1 ZK-EVMs make no changes to the Ethereum architecture, whether it be the hash function, state trees, or gas costs. This equivalency allows us to reuse execution clients with minimal modification.

### Is Taiko open source?

Yes, Taiko is open source under the permissive MIT license (free to access and modify). The Geth fork ([taiko-geth](https://github.com/taikoxyz/taiko-geth)) retains the original Geth GPL licenses.

### Can I ignore these logs from my node?

Join the Discord ([`#errors-faq` channel](https://discord.com/channels/984015101017346058/1193975550256107660)) to see the node logs that can be ignored and which are errors.

### Where can I find the deployed contract addresses for Hekla?

See [deployed contracts](/network-reference/testnet-addresses) for a list of deployed contract addresses.

### Where can I find the deployed contract addresses for Mainnet?

See [deployed contracts](/network-reference/mainnet-addresses) for a list of deployed contract addresses.

### I ran a node during a previous testnet do I need to do anything different?

Yes, please update your simple-taiko-node and run through one of the profiles described in the guides. You can also shut down your Taiko (Katla) node and run a Taiko (Hekla) node. Check out our guides in the sidebar.

### Does Taiko have a sequencer?

Taiko does not have an L2 sequencer, since everyone can become a proposer permissionlessly. Ultimately the L1 Ethereum validator for the current block is the sequencer that can sequence multiple L2 blocks. This is also referred to as a **based rollup**.

### How do I get ETH on the Taiko Hekla network?

You can use the official [Taiko bridge](https://bridge.hekla.taiko.xyz/) to send your ETH from the Holesky network to the Taiko Hekla network.

## Developer FAQs

---

### How can I get the L1 block number from L2 on Testnet?

You can check the last synced L1 block height in the TaikoL2 contract [here](/network-reference/testnet-addresses#taiko-l2-hekla-contracts). You can do the same for [Mainnet](/network-reference/mainnet-addresses#taiko-l2-contracts).
