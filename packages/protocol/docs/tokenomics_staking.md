# Staking-Based Tokenomics

## Objectives and Key Metrics
Please read our [objective and metrics in tokenomics design](./tokenomics_objective_metrics.md).



## The Proposal

### Overview

This solution proposal focuses on introducing a staking-based mechanism inspired by Brecht's initial staking idea. This mechanism involves provers staking Taiko tokens to become eligible for block proving, with 32 top provers allowed to prove blocks.

### Core Features

-  **Staking Mechanism**: Provers are permitted to stake Taiko tokens, limiting block-proving eligibility to the top 32 stakeholders. The prover's weight is calculated based on their staked tokens and other parameters. Should a prover fail to prove blocks, a fraction of their staked tokens would be forfeit as a penalty. Each validator has a `health` score to track the percentage of tokens not slashed, default to `100%`.

-  **Prover Selection**: For every block proposal, a deterministic random number is generated (e.g., `keccak(parent_hash, l2_block_id)`) to select a prover. This selection process is designed to be cost-efficient on-chain, occurring once per block. If no prover is available, the block is considered to be *open*, meaning it can be proven by any address.

-  **Fee Structure**: The protocol maintains a `fee_per_gas`. Provers have the option to set a `fee_multiplier` within a range of `1/2` to `2`. The actual fee per gas for a particular block, `fee_per_gas * fee_multiplier`, is calculated at the time of block proposal. Prover weight is fine-tuned based on the `fee_multiplier` value together with the `staking_amount`.

-  **Block Proving Limit**: For provers limited by bandwidth, they can specify a `capacity`. The protocol will stop selecting a prover once their `num_assigned_block` equals `capacity`.

-  **Proof Delay Enforcement**: The protocol will monitor an `average_proof_delay` and enforce that proofs be submitted within `2 * average_proof_delay`.

-  **Fee Multiplier Adjustment**: To avoid frequent adjustments to top provers, changes to `fee_multipler` are limited to once every 24 hours, and the number of provers that can exit from the top prover list is also limited based.

-  **Fallback Options**: If a block's assigned prover fails to validate a block before the deadline, it is considiered to be open.

-  **Proposing Fee**: The proposer spends `fee_per_gas * gas_used` as a fee for proposing (an initially larger deposit may be necessary, which can later be refunded).

-  **Handling Lack of Provers**: If all provers are out of bandwidth, or fully slashed, or there are no staked provers, blocks will be open, but the max number of open blocks shall be limited.

### Benefits Over Auction System

-  **Elimination of Onchain Auctions**: By carefully selecting staking parameters, provers can avoid conducting onchain auctions every N blocks.
- **Avoidance of Monopolization**: The design ensures that the system is not dominated by a single prover. It resembles a PoW model, where each prover gets a chance to prove blocks, with opportunities depending on the fee amplifier and volume of staked tokens.
- **Resource Optimization**: Since each block's prover is selected during block proposal, there is no wastage of proving resources.
- **Enhanced Token Utility**: The utility of the Taiko token is improved. As there's no direct staking reward without ZK proofs, there are no concerns about the token being classified as a security.




## Implementation Considerations

### Decoupling Staking from Core Protocol

It's advisable to decouple all staking logic into a separate contract that offers a few methods, such as:

```solidity
interface ProposerSelection {
  function getProvers(uint blockId) external view returns (address);
  function slash(address prover) external;
}
```

### Staking Weight Calculation

Staking weight can be calculated as:

```
sqrt(staking_amount) / pow(fee_multiplier,2)
```

Applying `sqrt` to `staking_amount` and `pow(*,2)` to `fee_multiplier` discourages monopoly and promotes cheaper proofs.

### Maintaining the Top Provers

Managing the top 32 provers in a gas-efficient manner is challenging. Notably, changes in the top prover list can occur due to a prover's request to exit, a new prover making it to the top, or an existing prover being slashed (this should be avoided).

Reading the information of the top 32 validators may result in numerous *SLOAD* operations. Storing this information in the code of a smart contract may be more efficient, enabling code loading and decoding into structured data.
