// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IShastaInbox
/// @notice Interface for the ShastaInbox contract
/// @custom:security-contact security@taiko.xyz
interface IShastaInbox {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @dev RRepresents a segment of data that is stored in multiple consecutive blobs created in
    /// this transaction.
    struct BlobLocator {
        /// @dev The starting index of the blob.
        uint48 blobStartIndex;
        /// @dev The number of blobs.
        uint32 numBlobs;
        /// @dev The offset within the blob.
        uint32 offset;
        /// @dev The size of the blob.
        uint32 size;
    }

    /// @dev Represents a segment of data that is stored in multiple blobs.
    struct BlobSegment {
        /// @dev The blobs containing the proposal's content.
        bytes32[] blobHashes;
        /// @dev The offset of the proposal's content in the containing blobs.
        uint32 offset;
        /// @dev The size of the proposal's content in the containing blobs.
        uint32 size;
    }

    struct Proposal {
        /// @dev Unique identifier for the proposal.
        uint48 id;
        /// @dev Address of the proposer. This is needed on L1 to handle provability bond
        /// and proving fee.
        address proposer;
        /// @dev Provability bond for the proposal, paid by the proposer on L1.
        uint48 provabilityBond;
        /// @dev Liveness bond for the proposal, paid by the proposer on L1 and potentially also by
        /// the designated prover on L2.
        uint48 livenessBond;
        /// @dev The L1 block timestamp when the proposal was made. This is needed on L2 to verify
        /// each block's timestamp in the proposal's content.
        uint48 timestamp;
        /// @dev The L1 block number when the proposal was made. This is needed on L2 to verify
        /// each block's anchor block number in the proposal's content.
        uint48 proposedBlockNumber;
        /// @dev The proposal's content identifier.
        BlobSegment content;
    }

    enum ProofTiming {
        InProvingWindow,
        InExtendedProvingWindow,
        OutOfExtendedProvingWindow
    }

    struct Claim {
        /// @dev The proposal's hash.
        bytes32 proposalHash;
        /// @dev The parent claim's hash, this is used to link the claim to its parent claim to
        /// finalize the corresponding proposal.
        bytes32 parentClaimHash;
        /// @dev The block number for the end (last) L2 block in this proposal.
        uint48 endBlockNumber;
        /// @dev The block hash for the end (last) L2 block in this proposal.
        bytes32 endBlockHash;
        /// @dev The state root for the end (last) L2 block in this proposal.
        bytes32 endStateRoot;
        /// @dev The designated prover.
        address designatedProver;
        /// @dev The actual prover.
        address actualProver;
    }

    struct ClaimRecord {
        /// @dev The claim.
        Claim claim;
        /// @dev The proposer, copied from the proposal.
        address proposer;
        /// @dev The liveness bond, copied from the proposal.
        uint48 livenessBond;
        /// @dev The provability bond, copied from the proposal.
        uint48 provabilityBond;
        /// @dev The proof timing.
        ProofTiming proofTiming;
    }

    struct SyncedBlock {
        uint48 blockNumber;
        bytes32 blockHash;
        bytes32 stateRoot;
    }

    struct State {
        uint48 nextProposalId;
        uint48 lastFinalizedProposalId;
        bytes32 lastFinalizedClaimHash;
        bytes32 bondOperationsHash;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed
    event Proposed(Proposal proposal);

    /// @notice Emitted when a proof is submitted for a proposal
    event Proved(Proposal proposal, ClaimRecord claimRecord);

    /// @notice Emitted when a proposal is finalized on L1
    event Finalized(uint48 indexed proposalId, ClaimRecord claimRecord);

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes new proposals of L2 blocks
    /// @param _state The state of the inbox
    /// @param _blobLocators The locators of the blobs containing the proposal's content
    /// @param _claimRecords The claim records to be proven
    function propose(
        State memory _state,
        BlobLocator[] memory _blobLocators,
        ClaimRecord[] memory _claimRecords
    )
        external;

    /// @notice Proves a claim about some properties of a proposal, including its state transition.
    /// @param _proposals Original proposal data
    /// @param _claims State transition claims being proven
    /// @param _proof Validity proof for the claim
    function prove(
        Proposal[] memory _proposals,
        Claim[] memory _claims,
        bytes calldata _proof
    )
        external;

    // -------------------------------------------------------------------------
    // External View Functions
    // -------------------------------------------------------------------------

    function provingWindow() external view returns (uint48 provingWindow_);
}
