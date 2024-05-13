---
title: Taiko Node API
description: The Taiko Node API describes the various API surfaces of a Taiko node.
---

Using a Taiko node should feel the same as using any other L1 node, because we essentially re-use the L1 client and make a few backwards-compatible modifications. You can first read about the architecture of Taiko nodes [here](/core-concepts/taiko-nodes).

## Differences from a Geth client

View the fork diff page to see the minimal set of changes made to Geth [here](https://geth.taiko.xyz).

## Execution JSON-RPC API

Check out the execution client spec [here](https://ethereum.github.io/execution-apis/api-documentation/).

## Engine API

Check out the engine API spec [here](https://github.com/ethereum/execution-apis/blob/main/src/engine/common.md).

## Hive test harness

If a Taiko node should feel the same as using any other L1 node, it should surely be able to pass the [hive e2e test harness](https://github.com/ethereum/hive). At the time of writing, the hive tests are actually one of the best references for what the API of an Ethereum node actually is.

We're working on integrating with hive, so stay tuned!
