// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IInbox
/// @notice Interface for the ShastaInbox contract
/// @custom:security-contact security@taiko.xyz
interface IInbox {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Represents a segment of data that is stored in multiple consecutive blobs created
    /// in this transaction.
    struct BlobLocator {
        /// @notice The starting index of the blob.
        uint48 blobStartIndex;
        /// @notice The number of blobs.
        uint32 numBlobs;
        /// @notice The offset within the blob.
        uint32 offset;
        /// @notice The size of the blob.
        uint32 size;
    }

    /// @notice Represents a segment of data that is stored in multiple blobs.
    struct BlobSegment {
        /// @notice The blobs containing the proposal's content.
        bytes32[] blobHashes;
        /// @notice The offset of the proposal's content in the containing blobs.
        uint32 offset;
        /// @notice The size of the proposal's content in the containing blobs.
        uint32 size;
    }

    /// @notice Represents a proposal for L2 blocks.
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
        uint48 timestamp;
        /// @notice The L1 block number when the proposal was made. This is needed on L2 to verify
        /// each block's anchor block number in the proposal's content.
        uint48 proposedBlockNumber;
        /// @notice The proposal's content identifier.
        BlobSegment content;
    }

    /// @notice Represents the timing of when a proof was submitted.
    enum ProofTiming {
        InProvingWindow,
        InExtendedProvingWindow,
        OutOfExtendedProvingWindow
    }

    /// @notice Represents a claim about the state transition of a proposal.
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

    /// @notice Represents a record of a claim with additional metadata.
    struct ClaimRecord {
        /// @notice The claim.
        Claim claim;
        /// @notice The proposer, copied from the proposal.
        address proposer;
        /// @notice The liveness bond, copied from the proposal.
        uint48 livenessBond;
        /// @notice The provability bond, copied from the proposal.
        uint48 provabilityBond;
        /// @notice The proof timing.
        ProofTiming proofTiming;
    }

    /// @notice Represents the core state of the inbox.
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

    /// @notice Represents the complete protocol state including all mappings.
    struct State {
        /// @notice The hash of the core state.
        bytes32 coreStateHash;
        /// @notice Maps proposal ID to proposal hash.
        mapping(uint48 proposalId => bytes32 proposalHash) proposalRegistry;
        /// @notice Maps proposal ID and parent claim hash to claim record hash.
        mapping(uint48 proposalId => mapping(bytes32 parentClaimHash => bytes32 claimRecordHash))
            claimRecordHashLookup;
        /// @notice The hash of bond credits on L2.
        bytes32 bondOperationsHash;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed.
    /// @param proposal The proposal that was proposed.
    event Proposed(Proposal proposal);

    /// @notice Emitted when a proof is submitted for a proposal.
    /// @param proposal The proposal that was proven.
    /// @param claimRecord The claim record containing the proof details.
    event Proved(Proposal proposal, ClaimRecord claimRecord);

    /// @notice Emitted when a proposal is finalized on L1.
    /// @param proposalId The ID of the finalized proposal.
    /// @param claimRecord The claim record of the finalized proposal.
    event Finalized(uint48 indexed proposalId, ClaimRecord claimRecord);

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes new proposals of L2 blocks.
    /// @param _lookahead The data to post a new lookahead.
    /// @param _data The data containing the core state, blob locators, and claim records.
    function propose(bytes calldata _lookahead, bytes calldata _data) external;

    /// @notice Proves a claim about some properties of a proposal, including its state transition.
    /// @param _data The data containing the proposals and claims.
    /// @param _proof Validity proof for the claim.
    function prove(bytes calldata _data, bytes calldata _proof) external;
}
