---
title: Differences from Ethereum
description: Network reference page describing the differences between Taiko and Ethereum.
---

| Parameter        | Ethereum       | Taiko                         | Reasoning                                                                                                                                                                                                        |
| ---------------- | -------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Block gas limit  | 30,000,000 gas | 240,000,000 gas               | Currently in Raiko, memory use scales linearly with block size both in the host (witness generation) and in the guest (memory use inside the VM/program being proven) so we set the block gas limit to 240m gas. |
| Block gas target | 15,000,000 gas | 60,000,000 gas (per L1 block) | Assuming an L2 block time of ~3 seconds will have a ~15,000,000 gas target.                                                                                                                                      |
| Block time       | 12 seconds     | 12-20~ seconds                | Currently, we are the only block proposer. Once we move to decentralized proposing / achieve preconfirmations, this value is expected to decrease.                                                               |
