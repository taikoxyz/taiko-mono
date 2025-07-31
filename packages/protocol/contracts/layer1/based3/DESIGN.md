# Shasta Protocol Design Specification

## Executive Summary

Shasta represents a next-generation based rollup protocol designed to minimize on-chain gas costs by shifting computational complexity from Layer 1 (L1) smart contracts to Layer 2 (L2) nodes and provers. This architectural approach optimizes for economic efficiency while maintaining security guarantees through validity proofs.

## Core Design Principles

The protocol adheres to the following fundamental principles:

1. **Data Efficiency**: Proposal blob data encompasses not only L2 transaction lists but all proposer-configurable parameters required for deterministic L2 block construction.

2. **Minimal L1 Validation**: On-chain validation is strictly limited to:

   - Permission and authorization checks
   - Bond payment processing
   - Validity proof verification

3. **State Consistency**: Finalizing existing proposals must not invalidate preconfirmed but pending proposals, ensuring smooth state progression.

## Terminology

The protocol introduces refined terminology to better capture semantic intent:

| Previous Term | New Term  | Rationale                                                                                   |
| ------------- | --------- | ------------------------------------------------------------------------------------------- |
| Batch         | Proposal  | Enables proposing multiple proposals in a single transaction without linguistic ambiguity   |
| Transition    | Claim     | Encompasses the complete set of proven assertions, including state transitions and metadata |
| Verified      | Finalized | Clarifies the completion of the validation process                                          |

## System Architecture

### L2 Block Construction

L2 blocks are deterministically constructed from three primary data sources:

#### 1. Parent L2 Block State (`parentL2Block`)

The parent block provides the foundation for constructing new blocks. Protocol state management occurs through a dedicated L2 storage address (e.g., `0x1234567890`) without associated private keys or contract code. State modifications are executed through system calls integrated into the rollup client.

#### 2. Proposal Object (`proposal`)

The L1-emitted `Proposal` structure contains:

- Proposer address
- Proposal timestamp and ID
- Latest L1 block hash (enables verification of L1 state via Merkle proofs)
- Blob data hash reference

#### 3. Proposal Specification (`proposalSpec`)

Encoded within proposal blobs, this specification contains proposer-customizable parameters and transaction data. When blob data is missing or invalid (non-decompressable/decodable), the system defaults to an empty specification with zero values and empty lists.

### Protocol System Calls

The rollup client executes four categories of system calls during block production:

1. **Proposal Leading Call**: Executed before the first transaction in the proposal's first block
2. **Proposal Trailing Call**: Executed after the last transaction in the proposal's final block
3. **Block Leading Call**: Executed before the first transaction in each block
4. **Block Trailing Call**: Executed after the last transaction in each block

These calls are gas-free and manage protocol state transitions, including bond payments and parameter updates.

### Empty Proposal Handling

Empty proposals (lacking blob data or containing invalid data) generate a single empty L2 block. This design choice ensures:

- Continuous protocol state progression
- Proper bond payment processing
- Consistent block numbering

## Block Header Construction

### Execution Payload Header Fields

#### `parent_hash`

Derived from the parent block selected by the block builder.

#### `prev_randao`

Calculated as: `keccak256(abi.encode(proposal.prevRandao, parentBlockNumber))`

- `proposal.prevRandao`: Previous RANDAO from the latest L1 block
- Mixing with parent block number ensures unique randomness per L2 block

#### `fee_recipient`

Priority order:

1. Valid address from `proposalSpec.feeRecipient`
2. Fallback to `proposal.proposer`

#### `block_number`

Incremented from parent: `parentL2Block.header.block_number + 1`

#### `timestamp`

Validation rules for custom timestamps:

- Default: `parentL2Block.timestamp + 1`
- Custom timestamp `t` valid if: `parentL2Block.timestamp + 1 ≤ t ≤ latestL1Timestamp + 12`
- `latestL1Timestamp` derived from `proposal.latestL1BlockHash` (12 seconds before proposal)

#### `gas_limit`

Calculated per block: `(thisBlock.timestamp - parentL2Block.timestamp) × gasIssuancePerSecond × 2`

- Factor of 2 provides headroom; expected usage targets 50% of limit
- `gasIssuancePerSecond` updates apply to subsequent proposals

#### `extra_data`

Set to `proposal.id` for traceability.

#### `base_fee_per_gas`

Managed via EIP-4396 algorithm accounting for variable block times:

- Read from `protocolState.basefee`
- Updated in block trailing call based on actual gas usage

#### `withdrawals_root`

Uses default value (withdrawals not currently implemented).

### Computed Fields

The following fields are calculated post-execution:

- `state_root`
- `receipts_root`
- `logs_bloom`
- `gas_used`
- `block_hash`
- `transactions_root`

## Claim Management System

### Claim Structure

Claims represent assertions about state transitions and include:

- Proposal hash reference
- Parent claim record hash (enables claim chaining)
- End L2 block hash and state root
- End L2 block number
- Proposer and prover addresses
- Prover bond amount

### Claim Chaining and Competition

1. **Multiple Branches**: A proposal may have multiple claims with different parent claim hashes, forming a tree structure.
2. **Replacement Logic**: Claims sharing identical `(proposalId, parentClaimRecordHash)` tuples replace previous claims silently.
3. **Finalization Selection**: The finalization process constructs a valid chain by linking claims via `parentClaimRecordHash`. Unlinked claims are ignored.

## Bond Economics

### Proving Window Mechanism

The protocol implements a time-based incentive structure:

- **Within Window**: Designated provers receive 100% bond refund
- **Outside Window**: Actual provers receive 50% refund; protocol retains remainder

This mechanism ensures timely proof submission while compensating emergency provers.

### Bond Payment Flow

_[Section reserved for bond collection and payment specifications]_

## Gas Economics

### Issuance Model

- **Initial State**: Zero-initialized; defaults to `DEFAULT_GAS_ISSUANCE_PER_SECOND`
- **Updates**: New values apply to subsequent proposals
- **Target Utilization**: 50% of gas limit
- **Dynamic Adjustment**: Base fee adjusts via EIP-4396 based on actual usage

## Protocol State Management

_[Section reserved for protocol state structure definition]_

## Security Considerations

1. **Proof Verification**: All state transitions must be validated through cryptographic proofs
2. **L1 State Verification**: Merkle proofs against `latestL1BlockHash` ensure L1 data integrity
3. **Bond Incentives**: Economic mechanisms discourage malicious behavior
4. **Claim Competition**: Multiple claim branches provide resilience against prover failures

## Implementation Notes

- System calls implemented as native rollup client hooks
- Protocol state stored at predetermined L2 addresses
- No anchor transactions or contracts in this design
- Supports batch proposal submission with individual blob associations

## Future Considerations

_[Section reserved for upgrade paths and extensibility]_
