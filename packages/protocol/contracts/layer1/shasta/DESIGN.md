# Shasta Protocol Design Specification

## Executive Summary

Shasta represents a next-generation based rollup protocol designed to minimize on-chain gas costs by shifting computational complexity from Layer 1 (L1) smart contracts to Layer 2 (L2) nodes and provers. This architectural approach optimizes for economic efficiency while maintaining security guarantees through validity proofs. The protocol achieves gas efficiency through:

- Blob-based data availability using EIP-4844
- Minimal on-chain state storage where only hashes are persisted
- Batch proposal and proving mechanisms that amortize transaction costs
- Optimized storage layouts with carefully packed structs to minimize storage slot usage

## Core Design Principles

The protocol adheres to fundamental principles that guide its architecture and implementation. Data efficiency is paramount, with proposal blob data encompassing not only L2 transaction lists but all proposer-configurable parameters required for deterministic L2 block construction. Blobs are referenced by hash and accessed via EIP-4844's blobhash opcode, enabling efficient data availability without on-chain storage overhead.

On-chain validation is strictly limited to essential operations:

- Permission and authorization checks
- Bond payment processing for both provability and liveness bonds
- Validity proof verification
- Claim record hash storage with chain validation

This minimal validation approach significantly reduces gas consumption while maintaining security through cryptographic proofs.

State consistency is maintained through careful protocol design ensuring that finalizing existing proposals does not invalidate preconfirmed but pending proposals. The protocol achieves this through parent claim hash chaining, sequential proposal ID validation, and atomic state updates during finalization. Additionally, the protocol employs a separate storage contract (ShastaInboxStore) to optimize gas costs and enable future upgradability without requiring complex state migrations.

## Terminology

The protocol introduces refined terminology to better capture semantic intent and avoid ambiguity. The term "Proposal" replaces "Batch" to enable proposing multiple proposals in a single transaction without linguistic confusion. "Claim" supersedes "Transition" as it encompasses the complete set of proven assertions, including state transitions and metadata. "Finalized" is used instead of "Verified" to clarify the completion of the proof validation process. Additionally, "ClaimRecord" provides a clearer description than "Metadata" as it contains both the claim and timing information including when the proposal was made and when it was proven.

## System Architecture

### Contract Architecture

The protocol consists of two main contracts working in tandem. The ShastaInbox serves as an abstract contract that handles proposal submission, proof verification, and finalization. It manages bond mechanics for both provability and liveness bonds, emits events for off-chain indexing, and delegates all storage operations to the ShastaInboxStore contract. This separation of concerns allows for cleaner code organization and potential future upgrades.

The ShastaInboxStore contract provides optimized storage with carefully packed variables to minimize slot usage. It implements strict access control where only the inbox contract can modify state, stores only hashes rather than full data structures to reduce gas costs, and enables future upgradability patterns through its isolated storage design. The storage layout is optimized with three uint48 values packed into a single slot, leaving room for future additions.

### L2 Block Construction

L2 blocks are deterministically constructed from three primary data sources that work together to define the complete execution environment. The parent L2 block state provides the foundation for constructing new blocks, with protocol state management occurring through system calls without requiring associated private keys or contract code. This state includes gas issuance parameters, gas excess for EIP-1559 calculations, and anchor block information linking L2 to L1.

The proposal object emitted on L1 contains essential metadata for block construction and verification. The reference block hash enables L1 state verification through Merkle proofs but does not directly affect L2 block world states, providing flexibility in proof generation while maintaining security. The proposal content, encoded within EIP-4844 blobs, specifies the actual execution parameters including transaction lists, block timestamps, fee recipients, and gas issuance updates.

When blob data is invalid, the system gracefully degrades to a default specification with empty blocks and zero values, ensuring the protocol remains operational even under adverse conditions. This resilience is crucial for maintaining liveness in a decentralized environment where data availability cannot be guaranteed.

### Protocol System Calls

The rollup client executes system calls during block production that do not consume gas, enabling protocol-level operations without impacting user transactions. The block head call executes before the first transaction in each block, validating and setting block parameters. This call:

- Ensures timestamps fall within acceptable ranges based on parent and reference blocks
- Calculates prevRandao by mixing the block number with parent randomness
- Determines fee recipients with fallback to the DAO treasury for zero addresses
- Updates anchor block information when valid new anchors are provided

The timestamp validation ensures blocks cannot be timestamped in the future relative to L1, maintains monotonic time progression, and prevents excessive backdating beyond 128 seconds. The anchor block mechanism allows L2 to reference recent L1 state while preventing reference to blocks that are too old or potentially reorganized.

The block tail call executes after the last transaction in each block, updating protocol state based on execution results. It calculates gas excess using EIP-1559 principles where excess increases with issuance and decreases with usage. On the final block of each proposal, it may update the gas issuance rate within strict bounds of 99% to 101% of the current rate, preventing dramatic economic changes while allowing gradual adaptation to network conditions.

## Block Header Construction

The protocol deterministically constructs L2 block headers based on proposal data and system state, ensuring all nodes arrive at identical results. The parent hash derives from the selected parent block, maintaining the blockchain structure. PrevRandao is calculated by hashing the block number concatenated with parent prevRandao, providing deterministic randomness that changes each block while remaining verifiable.

Fee recipient determination follows a simple rule where zero addresses default to the DAO treasury, ensuring protocol sustainability. Block numbers increment sequentially from the parent, maintaining standard blockchain semantics. Timestamps undergo validation to ensure they cannot exceed the reference block timestamp from L1, must be at least equal to the parent timestamp for monotonicity, and cannot be more than 128 seconds before the reference timestamp to prevent excessive backdating.

The gas limit is fixed at 100 million gas per block, providing ample capacity for transaction execution while preventing DoS through excessive computation. Extra data is currently unused but reserved for future protocol extensions such as encoding proposal IDs for traceability. Base fee per gas calculations follow EIP-1559 mechanisms with gas excess tracking, where issuance increases excess and usage decreases it, creating a self-regulating economic system.

## Claim Management System

Claims represent assertions about L2 state transitions resulting from proposal execution, forming the core of the protocol's validity proof system. Each claim links to a specific proposal through its hash, references a parent claim to form verifiable chains, and contains the final L2 block hash, state root, and block number after executing the proposal. ClaimRecords augment claims with temporal metadata, recording when the original proposal was made and when the specific claim was proven, enabling time-based bond calculations and incentive mechanisms.

The protocol employs hash-based storage where only claim record hashes are stored on-chain, dramatically reducing gas costs compared to storing full data structures. Key characteristics include:

- Claims form chains through parent-child linking, where each claim must reference a valid parent claim hash
- Multiple claims can exist for the same proposal with different parent claims, creating a tree structure
- Claims sharing identical proposal ID and parent claim hash tuples silently replace previous ones
- This design provides flexibility in proving strategies while minimizing gas overhead

The proving process validates proposal hash consistency to ensure claims match their proposals, creates ClaimRecords with current timestamps for bond calculations, stores claim record hashes indexed by proposal ID and parent claim hash for efficient lookups, and verifies validity proofs for all claims in a single batch operation to amortize verification costs.

The finalization process enforces strict sequential validation to maintain protocol integrity. Starting from the last finalized claim hash, it validates each claim's parent matches the expected hash, creating an unbroken chain. It verifies stored claim record hashes match provided data, preventing manipulation of proven claims. Upon successful validation, it updates L2 state on L1 including block number, hash, and state root, making the L2 state observable to L1 contracts. Finally, it advances the finalized proposal ID, permanently committing the state transition.

## Bond Economics

Please see the bonds [document](./BONDS.md) to understand how bonds are handled.

## Gas Economics

The protocol implements a sophisticated gas issuance model that adapts to network conditions while maintaining stability. The system starts with a default issuance rate of 1 million gas per second, providing a baseline for network capacity. Gas issuance can be updated by proposals, but changes are limited to 1% increase or decrease per proposal, preventing dramatic economic shifts that could destabilize the network.

Gas management operates at multiple levels. Each block has a fixed limit of 100 million gas, providing predictable capacity for users and applications. The protocol tracks gas excess using EIP-1559 principles, where excess increases with issuance and decreases with usage, creating a self-balancing system. The target utilization is approximately 50% of the gas limit, with base fees adjusting to maintain this equilibrium over time.

Base fee calculations follow standard EIP-1559 formulas but adapted for the protocol's variable block times. Gas excess updates occur in the block tail call after measuring actual gas usage, ensuring fees reflect real network demand. The base fee derives from gas excess, creating price signals that guide users toward efficient resource utilization.

## Storage Optimization

The ShastaInboxStore contract employs sophisticated optimization techniques to minimize gas costs. Storage slots are carefully packed, with three uint48 values (nextProposalId, lastFinalizedProposalId, and lastL2BlockNumber) sharing a single 256-bit slot, leaving 112 bits available for future use. This packing reduces the number of storage operations required for common updates.

The protocol stores only hashes instead of full data structures, dramatically reducing storage costs while maintaining data integrity through cryptographic commitments. Mapping structures provide efficient O(1) lookups for proposals and claims without requiring iteration. Strict access control ensures only the inbox contract can modify state, preventing unauthorized changes while enabling clean separation of concerns.

Gas cost minimization extends beyond storage layout to operation design. Batch operations allow multiple proposals or proofs in a single transaction, amortizing base transaction costs. Event emission provides off-chain indexing capabilities without on-chain storage overhead. Validation logic is minimized in hot paths, with complex checks deferred to less frequent operations like finalization.

## Security Considerations

The protocol's security rests on three pillars: cryptographic, economic, and protocol-level guarantees.

Cryptographic security is achieved through:

- Abstract verifyProof function allowing integration with various proof systems (ZK-SNARKs, optimistic fraud proofs)
- All data committed through keccak256 hashes providing strong collision resistance
- Reference block hash mechanism enabling Merkle proof verification of L1 state

Economic security derives from bond requirements that create stake-based incentives for honest behavior. Time-based proving windows ensure liveness by incentivizing timely proof submission. Slashing conditions, once implemented, will penalize invalid proofs by forfeiting bonds, creating strong disincentives for attacks.

Protocol-level security measures include:

- Sequential finalization preventing state inconsistencies through ordered claim processing
- Parent claim validation ensuring only valid claim chains can be finalized
- Atomic state updates guaranteeing all-or-nothing finalization

## Implementation Status

The current implementation includes core functionality:

- Proposal submission with blob references via EIP-4844
- Flexible claim proof verification framework
- Sequential finalization logic maintaining state consistency
- Optimized storage architecture minimizing gas costs
- Comprehensive event emission for off-chain services

Several important features remain to be implemented, as noted in code comments:

- Support for anchor blocks on a per-block basis rather than per-proposal
- Full implementation of prover and liveness bond mechanics
- Provability bond collection and distribution systems
- Batch proving optimizations to reduce verification costs
- Multi-step finalization for very large proposals
- Summary approach for aggregating multiple proposals

## Protocol Constants and Configuration

The protocol defines several important constants that govern its operation. The minimum TAIKO token balance of 10,000 tokens ensures participants have sufficient stake in the system. The default gas issuance rate of 1 million gas per second provides baseline capacity. The block gas limit of 100 million ensures bounded computation per block. The TAIKO DAO treasury address receives fees when no specific recipient is designated, ensuring protocol sustainability.

These constants are carefully chosen to balance security, efficiency, and usability. They may be adjusted in future deployments based on real-world usage patterns and community governance decisions.

## Future Considerations

The protocol's modular design enables several upgrade paths. The abstract verifier pattern allows seamless transitions between proof systems as technology advances. Storage separation between inbox and store contracts enables logic upgrades without complex state migrations. Parameter tuning through deployment-time configuration allows adaptation to different network conditions without code changes.

Potential enhancements under consideration include multi-prover support allowing proposal proving by multiple parties for redundancy, dynamic bond pricing that adjusts based on network congestion and risk factors, cross-L2 messaging integration through the signal service for interoperability, and advanced blob handling supporting compression and encryption for improved efficiency and privacy. These enhancements would expand the protocol's capabilities while maintaining its core security properties and gas efficiency.
