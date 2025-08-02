// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IShastaInbox
/// @notice Interface for the ShastaInbox contract
/// @custom:security-contact security@taiko.xyz
interface IShastaInbox {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct BlobLocator {
        uint48 blobStartIndex;
        uint32 numBlobs;
        uint32 offset;
        uint32 size;
    }

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
        /// @dev Address of the designated prover. This is needed on L1 to handle
        /// liveness bond and proving fee.
        address prover;
        /// @dev Provability bond for the proposal, paid by the proposer.
        uint48 provabilityBond;
        /// @dev Liveness bond for the proposal, paid by the designated prover.
        uint48 livenessBond;
        /// @dev Timestamp when the proposal was made. This is needed on L1 to verify
        /// the timing of the claim used to finalize the proposal for correct bond payments.
        uint48 proposedBlockTimestamp;
        /// @dev The L1 block number when the proposal was made.
        uint48 proposedBlockNumber;
        /// @dev Latest known L1 block hash. This is used to verify all L1 data used in this
        /// proposal's L2 blocks. However, this block hash does not affect the L2 blocks' world
        /// states. Using a more recent L1 block hash as the reference block hash will not
        /// invalidate any pre-confirmed L2 blocks. This value should not be confused with a L2
        /// block's anchor block hash.
        bytes32 referenceBlockHash;
        bytes32 bondCreditHash;
        /// @dev The proposal's content.
        BlobSegment content;
    }

    enum ProofTiming {
        InProvingWindow,
        InExtendedProvingWindow,
        OutOfExtendedProvingWindow
    }

    struct Claim {
        bytes32 proposalHash;
        bytes32 parentClaimHash;
        bytes32 endL2BlockHash;
        bytes32 endL2StateRoot;
        uint48 endL2BlockNumber;
        address designatedProver;
        address actualProver;
    }

    struct ClaimRecord {
        Claim claim;
        address proposer;
        uint48 livenessBond;
        uint48 provabilityBond;
        ProofTiming proofTiming;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed
    event Proposed(uint48 indexed proposalId, Proposal proposal);

    /// @notice Emitted when a proof is submitted for a proposal
    event Proved(uint48 indexed proposalId, Proposal proposal, ClaimRecord claimRecord);

    /// @notice Emitted when a proposal is finalized on L1
    event Finalized(uint48 indexed proposalId, Claim claim);

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes new proposals of L2 blocks
    /// @param _blobLocators The locators of the blobs containing the proposal's content
    function propose(BlobLocator[] memory _blobLocators) external;

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

    /// @notice Finalizes verifiable claims and updates the L2 chain state
    /// @param _claimRecords The proven claims to finalize
    function finalize(ClaimRecord[] memory _claimRecords) external;

    // -------------------------------------------------------------------------
    // External View Functions
    // -------------------------------------------------------------------------

    function provingWindow() external view returns (uint48 provingWindow_);
}
