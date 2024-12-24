---
title: Economics
description: Core concept page for "Economics".
---


## taiko-economics

Thanks to its based and multi-proof structure, Taiko has a unique economic cycle.

This diagram illustrates Taiko's fee distribution mechanism. When users submit transactions on Taiko L2, they pay fees that are split into two components: a priority tip and a base fee. The priority tip goes to the L2 block proposer, who builds and proposes new blocks. The base fee is split between Taiko DAO Treasury (25%) and the L2 block proposer (75%). L2 block proposers have to pay two fees: L1 fee to the TaikoL1 contract on Ethereum to call `proposeBlock` function and a prover fee to the block prover. Block provers incur proof generation costs while proving the correctness of proposed blocks.

For the current amount of the validity/contest bond on mainnet, please see [network configuration](/network-reference/network-configuration) page.

![Economics](~/assets/content/docs/taiko-protocol/based-economics.png)
