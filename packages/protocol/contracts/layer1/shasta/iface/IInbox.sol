// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IInbox
/// @notice Interface for the Shasta Inbox contract that manages L2 block proposals and proofs
/// @dev The Inbox is a critical component of Taiko's based rollup architecture that:
/// - Accepts L2 block proposals from proposers
/// - Manages validity proofs with support for claim record aggregation
/// - Handles bond operations for provability and liveness guarantees
/// - Supports gas-efficient batch processing through claim aggregation
/// @custom:security-contact security@taiko.xyz
interface IInbox {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Represents a segment of data that is stored in multiple consecutive blobs created
    /// in this transaction.
    /// @dev Used to locate proposal data within EIP-4844 blobs for efficient data availability
    struct BlobLocator {
        /// @notice The starting index of the blob.
        uint48 blobStartIndex;
        /// @notice The number of blobs.
        uint32 numBlobs;
        /// @notice The offset within the blob data.
        uint32 offset;
        /// @notice The size of the data segment.
        uint32 size;
    }

    /// @notice Represents a frame of data that is stored in multiple blobs
    /// @dev The size is encoded as a bytes32 at the offset location. This structure
    /// enables efficient retrieval of proposal data from blob storage
    struct Frame {
        /// @notice The blobs containing the proposal's content.
        bytes32[] blobHashes;
        /// @notice The offset of the proposal's content in the containing blobs.
        uint32 offset;
    }

    /// @notice Represents a proposal for L2 blocks
    /// @dev Proposals contain L2 block data and associated bonds. Multiple proposals
    /// can be submitted in a single transaction for efficiency
    struct Proposal {
        /// @notice Unique identifier for the proposal.
        uint48 id;
        /// @notice Address of the proposer. This is needed on L1 to handle provability bond
        /// and proving fee.
        address proposer;
        /// @notice Provability bond for the proposal, paid by the proposer on L1.
        uint48 provabilityBond;
        /// @notice Liveness bond for the proposal, paid by the proposer on L1 and potentially
        /// also by the designated prover on L2.
        uint48 livenessBond;
        /// @notice The L1 block timestamp when the proposal was made. This is needed on L2 to
        /// verify each block's timestamp in the proposal's content.
        uint48 originTimestamp;
        /// @notice The L1 block number when the proposal was made. This is needed on L2 to verify
        /// each block's anchor block number in the proposal's content.
        uint48 originBlockNumber;
        /// @notice The proposal's frame.
        Frame frame;
    }

    /// @notice Represents the bond decision based on proof submission timing and prover identity
    /// @dev Bond decisions determine how provability and liveness bonds are distributed
    /// based on whether proofs are submitted on time and by the correct party
    enum BondDecision {
        NoOp, // Aggregatable
        L2RefundLiveness, // Aggregatable
        L2RewardProver, // Aggregatable
        L1SlashLivenessRewardProver, // Non-aggregatable
        L1SlashProvabilityRewardProverL2RefundLiveness, // Non-aggregatable
        L1SlashProvabilityRewardProver // Non-aggregatable

    }

    /// @notice Represents a claim about the state transition of a proposal
    /// @dev Claims link together to form a chain of state transitions. Multiple claims
    /// can be proven in a single transaction for gas efficiency
    struct Claim {
        /// @notice The proposal's hash.
        bytes32 proposalHash;
        /// @notice The parent claim's hash, this is used to link the claim to its parent claim to
        /// finalize the corresponding proposal.
        bytes32 parentClaimHash;
        /// @notice The block number for the end (last) L2 block in this proposal.
        uint48 endBlockNumber;
        /// @notice The block hash for the end (last) L2 block in this proposal.
        bytes32 endBlockHash;
        /// @notice The state root for the end (last) L2 block in this proposal.
        bytes32 endStateRoot;
        /// @notice The designated prover.
        address designatedProver;
        /// @notice The actual prover.
        address actualProver;
    }

    /// @notice Represents a record of a claim with additional metadata
    /// @dev ClaimRecords can be aggregated when they have compatible properties,
    /// significantly reducing gas costs when proving multiple consecutive proposals
    struct ClaimRecord {
        /// @notice The claim.
        Claim claim;
        /// @notice The proposer, copied from the proposal.
        address proposer;
        /// @notice The liveness bond, copied from the proposal.
        uint48 livenessBond;
        /// @notice The provability bond, copied from the proposal.
        uint48 provabilityBond;
        /// @notice The bond decision.
        BondDecision bondDecision;
        /// @notice The next proposal ID.
        uint48 nextProposalId;
    }

    /// @notice Represents the core state of the inbox
    /// @dev This state is updated atomically during propose operations to maintain
    /// consistency across proposal submission and finalization
    struct CoreState {
        /// @notice The next proposal ID to be assigned.
        uint48 nextProposalId;
        /// @notice The ID of the last finalized proposal.
        uint48 lastFinalizedProposalId;
        /// @notice The hash of the last finalized claim.
        bytes32 lastFinalizedClaimHash;
        /// @notice The hash of all bond operations.
        bytes32 bondOperationsHash;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed.
    /// @param proposal The proposal that was proposed.
    /// @param coreState The core state of the inbox.
    event Proposed(Proposal proposal, CoreState coreState);

    /// @notice Emitted when a proof is submitted for a proposal.
    /// @param proposal The proposal that was proven.
    /// @param claimRecord The claim record containing the proof details.
    event Proved(Proposal proposal, ClaimRecord claimRecord);

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes new L2 blocks and optionally finalizes previously proven proposals
    /// @dev This function enables atomic proposal submission and finalization in a single
    /// transaction. The finalization process supports claim record aggregation to reduce
    /// gas costs when multiple consecutive proposals share the same prover and bond decision
    /// @param _lookahead The data to post a new lookahead (reserved for future use)
    /// @param _data The encoded data containing:
    ///   - CoreState: Current state that must match on-chain state
    ///   - BlobLocator: Location of proposal data in blobs
    ///   - ClaimRecord[]: Previously proven claims to finalize (can be aggregated)
    function propose(bytes calldata _lookahead, bytes calldata _data) external;

    /// @notice Proves claims about L2 state transitions for one or more proposals
    /// @dev This function supports batch proving and automatic claim record aggregation.
    /// When proving multiple consecutive proposals with the same designated prover and
    /// bond decision, the system automatically aggregates them into a single claim record
    /// to minimize storage operations and gas costs
    /// @param _data The encoded data containing:
    ///   - Proposal[]: Array of proposals to prove
    ///   - Claim[]: Corresponding claims for each proposal
    /// @param _proof The validity proof that verifies all claims in the batch
    function prove(bytes calldata _data, bytes calldata _proof) external;
}
