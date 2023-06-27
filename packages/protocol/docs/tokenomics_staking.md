# Staking-Based Tokenomics

## Objectives and Key Metrics

Please read our [objective and metrics in tokenomics design](./tokenomics_objective_metrics.md).

## The Proposal

### Overview

This solution proposal focuses on introducing a staking-based mechanism inspired by Brecht's initial staking idea. This mechanism involves provers staking Taiko tokens to become eligible for block proving, with 32 top provers allowed to prove blocks.

### Core Features

- **Staking Mechanism**: Provers are permitted to stake Taiko tokens, limiting block-proving eligibility to the top 32 stakeholders. The prover's weight is calculated based on their staked tokens and other parameters. Should a prover fail to prove blocks, a fraction of their staked tokens would be forfeit as a penalty. Each validator has a `health` score to track the percentage of tokens not slashed, default to `100%`.

- **Prover Selection**: For every block proposal, a deterministic random number is generated (e.g., `keccak(parent_hash, l2_block_id)`) to select a prover. This selection process is designed to be cost-efficient on-chain, occurring once per block. If no prover is available, the block is considered to be _open_, meaning it can be proven by any address.

- **Fee Structure**: The protocol maintains a `fee_per_gas`. Provers have the option to set a `fee_multiplier` within a range of `1/2` to `2`. The actual fee per gas for a particular block, `fee_per_gas * fee_multiplier`, is calculated at the time of block proposal. Prover weight is fine-tuned based on the `fee_multiplier` value together with the `staking_amount`.

- **Block Proving Limit**: For provers limited by bandwidth, they can specify a `capacity`. The protocol will stop selecting a prover once their `num_assigned_block` equals `capacity`.

- **Proof Delay Enforcement**: The protocol will monitor an `average_proof_delay` and enforce that proofs be submitted within `2 * average_proof_delay`.

- **Fee Multiplier Adjustment**: To avoid frequent adjustments to top provers, changes to `fee_multipler` are limited to once every 24 hours, and the number of provers that can exit from the top prover list is also limited based.

- **Fallback Options**: If a block's assigned prover fails to validate a block before the deadline, it is considiered to be open.

- **Proposing Fee**: The proposer spends `fee_per_gas * gas_used` as a fee for proposing (an initially larger deposit may be necessary, which can later be refunded).

- **Handling Lack of Provers**: If all provers are out of bandwidth, or fully slashed, or there are no staked provers, blocks will be open, but the max number of open blocks shall be limited.

## Understanding Prover Staking Mechanisms

In the previous two tokenomics iterations, including the one used by the ongoing alpha-3 testnet, we incorporated a dynamic fee-reward adjustment system, drawing data from in-protocol stats. However, a key flaw surfaced in this design: it instigated numerous provers to generate Zero-Knowledge Proofs (ZKPs) for the same block, unbeknownst to each other. This redundancy leads to a scenario where only one prover is rewarded, while the remaining provers, having worked on the same task, incur a loss. This issue, henceforth referred to as 'Prover Redundancy', escalates the overall proving costs for the Layer 2 (L2) network, making it unnecessarily expensive. Consequently, users have to bear inflated transaction costs on L2. To alleviate this, we need to develop an effective solution to reduce the per-block proving cost, which would in turn decrease the user's transaction cost on L2.

A proposed solution was an auction-based mechanism, enabling provers to bid for exclusive rights to prove blocks. While this approach effectively tackles the 'Prover Redundancy' issue, it also presents new challenges. Provers would have to engage in a significant number of Layer 1 (L1) transactions to participate in these auctions. This not only raises their costs but also necessitates the development of a separate auction participation system alongside their proving system. This complexity could potentially discourage provers from entering our ecosystem.

To address these concerns, we've implemented a staking-based prover pool, which essentially simulates a perpetual auction bidding process. This system allows a prover to bid once and remain eligible for proving blocks indefinitely.

Within the prover pool, when an address wishes to stake, it must provide three parameters:

1. The number of Taiko Tokens to stake (`A`),
2. The expected reward per gas (`R`), and
3. Its maximum capacity (`C`).

These inputs contribute to the calculation of a score (`S`). The top 32 stakes with the highest scores are chosen to constitute the list of active provers.

When a block is proposed, each prover in the list is assigned a weight (`W`), calculated as a function of `A`, `R`, `C`, and the current fee per gas (`F`):

```solidity
W = 0, if A = 0 or C = 0
W = (A * F^2) / R^2, otherwise
```

Notably, a prover's weight depends on the number of tokens staked, the current fee per gas supplied by the core protocol, and the expected reward per gas:

- The more tokens staked, the higher the weight of the prover. This is a linear relationship.
- The less reward expected, the higher the weight of the prover. This is an inverse square relationship.

The protocol then uses a deterministic pseudo-random number and each prover's weight to select a prover to be assigned to a given block. If all provers' weights are zero, address(0) is returned, indicating that any prover can prove the block - we'll refer to this as an 'open block'.

If a block is proven by the assigned prover within a set proving window (3 times the average proof delay), we reward the prover with `R * gasUsed`. However, to prevent excessive fluctuations in `R`, we cap the actual reward per gas (`R'`) at (95%-105%) \* `F`. This implies that if a prover's expected reward per gas is exceedingly high, their weight will be minimal. Even if such a prover is selected, their reward won't exceed 5% more than the current fee per gas.

For instances where the block is an open block or proven outside the set proving window, the actual prover is rewarded with `1.5 * R'`. If the assigned prover fails to prove the block within the proving window, we slash a certain percentage from their total staked amount, which consequently reduces the prover's weight.

In order to ensure automatic adjustment of the fee-reward ratio, we modify the fee per gas (`F`) every time a block is verified by its assigned prover within the proving window:

```solidity
F = (F*1023 + R')/1024
```

In this system, we can ensure efficient proof generation, provide provers with a fair reward mechanism, and maintain an economically viable environment for both users and provers alike in the Layer 2 network.

Additionally, when a prover is assigned to a block, its capacity (`C`) is decreased by 1, and when the block is proven by the assigned prover or is verified, the assigned prover's capacity is increased by 1. However, the current capacity always remains capped at its initial value.
