---
title: Block states
description: Core concept page for "Block states".
---

## How can you determine when a Taiko block is `Safe` or `Finalized`?

The `Safe` block state on Taiko is analogous to a `Safe` block state on Ethereum.
Every Taiko L2 block has a corresponding Ethereum L1 block as it's origin that can be queried through a [`taiko-geth API`](https://github.com/taikoxyz/taiko-geth/blob/caf87509fe0f53fc937a3f5cc26325a380a1744e/eth/taiko_api_backend.go#L50).
When that Ethereum L1 block can be considered `Safe`, the corresponding Taiko L2 block can be considered to have reached the same block state.

The `Finalized` block state is referred to as the [`Verified` block state](/core-concepts/multi-proofs#verified-blocks-and-parallel-proving) on Taiko.
A Taiko block is `Finalized`/`Verified` when every state transition from genesis to the current block has valid proofs.
