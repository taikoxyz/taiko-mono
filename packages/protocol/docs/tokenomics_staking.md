# Staking-Based Tokenomics

## Objectives and Key Metrics
Please read our [objective and metrics in tokenomics design](./tokenomics_objective_metrics.md).



## The Proposal

### Overview

This solution proposal focuses on introducing a staking-based mechanism inspired by Brecht's initial staking idea. This mechanism involves provers staking Taiko tokens to become eligible for block proving, with the top 32 stakeholders allowed to prove blocks.

### Core Features

1. **Staking Mechanism**: Provers are permitted to stake Taiko tokens, limiting block-proving eligibility to the top 32 stakeholders. The prover's weight is calculated based on their staked tokens. Should a prover fail to prove blocks, a fraction of their staked tokens would be forfeit as a penalty.

2. **Prover Selection**: For every block proposal, a deterministic random number is generated (e.g., `keccak(parent_hash, l2_block_id)`) to select a prover. This selection process is designed to be cost-efficient on-chain, occurring once per block.

3. **Fee Structure**: The protocol maintains a `fee_per_gas`. Provers have the option to set a `fee_multiplier` within a range of `1/2` to `2`. The actual fee per gas for a particular block, `fee_per_gas * fee_multiplier`, is calculated at the time of block proposal. Prover weight and selection process adjustments might be fine-tuned based on the `fee_multiplier` value together with the `staking_amount`.

4. **Block Proving Limit**: For provers limited by bandwidth, they can specify a `capacity`. The protocol will stop selecting a prover once their `num_assigned_block` equals `capacity`.

5. **Proof Delay Enforcement**: The protocol will monitor an `average_proof_delay` and enforce that proofs be submitted within `2 * average_proof_delay`.

6. **Fee Multiplier Adjustment**: To avoid frequent small adjustments to the fee multiplier, changes to this value are limited to once every 24 hours.

7. **Fallback Options**: If a block's assigned prover fails to validate a block before the deadline, two alternatives are available: 1) a backup prover may be selected during the block proposal phase to validate the block within an extended time frame `4 * average_proof_delay`, or 2) any prover able to validate the block may be rewarded with `fee_per_gas * 8 * gas_used` tokens. We can also choose to combine the two options above.

8. **Proposing Fee**: The proposer spends `fee_per_gas * gas_used` as a fee for proposing (an initially larger deposit may be necessary, which can later be refunded).

9. **Handling Lack of Provers**: If all provers are out of bandwidth or there are no staked provers, block proposal will be disabled.

### Benefits Over Auction System

1. **Elimination of Onchain Auctions**: By carefully selecting staking parameters, provers can avoid conducting onchain auctions every N blocks.
2. **Avoidance of Monopolization**: The design ensures that the system is not dominated by a single prover. It resembles a PoW model, where each prover gets a chance to prove blocks, with opportunities depending on the fee amplifier and volume of staked tokens.
3. **Resource Optimization**: Since each block's prover is selected during block proposal, there is no wastage of proving resources.
4. **Enhanced Token Utility**: The utility of the Taiko token is improved. As there's no direct staking reward without ZK proofs, there are no concerns about the token being classified as a security.

