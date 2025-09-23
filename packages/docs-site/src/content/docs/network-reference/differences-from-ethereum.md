---
title: Differences from Ethereum
description: Network reference page describing the differences between Taiko Alethia and Ethereum.
---

| Parameter        | Ethereum       | Taiko Alethia                 | Reasoning                                                                                                                                                                                                        |
| ---------------- | -------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Block gas limit  | 36,000,000 gas | 241,000,000 gas               | Currently in Raiko, memory use scales linearly with block size both in the host (witness generation) and in the guest (memory use inside the VM/program being proven) so we set the block gas limit to 241m gas. |
| Block gas target | 18,000,000 gas | 40,000,000 gas (per L1 block) | Assuming an L2 block time of ~3 seconds will have a ~15,000,000 gas target.                                                                                                                                      |
| Block time       | 12 seconds     | ~2-6 seconds                  | This value is variable and will change as of based preconfirmations.                                                                                                                                             |

## Geth Diff

[Here](https://geth.taiko.xyz/) is an overview of the changes made to the `go-ethereum` codebase in `taiko-geth`.
