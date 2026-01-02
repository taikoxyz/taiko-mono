// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../libs/LibBlobs.sol";

/// @title IInbox
/// @notice Interface for the Shasta inbox contracts
/// @custom:security-contact security@taiko.xyz
interface IInbox {
    /// @notice Configuration struct for Inbox constructor parameters
    struct Config {
        /// @notice The proof verifier contract
        address proofVerifier;
        /// @notice The proposer checker contract
        address proposerChecker;
        /// @notice The prover auction contract
        address proverAuction;
        /// @notice The signal service contract address
        address signalService;
        /// @notice The proving window in seconds
        uint48 provingWindow;
        /// @notice Maximum delay allowed between consecutive proofs to still be on time.
        /// @dev Must be shorter than the expected proposal cadence to prevent backlog growth.
        uint48 maxProofSubmissionDelay;
        /// @notice The ring buffer size for storing proposal hashes
        uint256 ringBufferSize;
        /// @notice The percentage of basefee paid to coinbase
        uint8 basefeeSharingPctg;
        /// @notice The minimum number of forced inclusions that the proposer is forced to process
        /// if they are due
        uint256 minForcedInclusionCount;
        /// @notice The delay for forced inclusions measured in seconds
        uint16 forcedInclusionDelay;
        /// @notice The base fee for forced inclusions in Gwei used in dynamic fee calculation
        uint64 forcedInclusionFeeInGwei;
        /// @notice Queue size at which the fee doubles
        uint64 forcedInclusionFeeDoubleThreshold;
        /// @notice The minimum delay between checkpoints in seconds
        /// @dev Must be less than or equal to finalization grace period
        uint16 minCheckpointDelay;
        /// @notice The multiplier to determine when a forced inclusion is too old so that proposing
        /// becomes permissionless
        uint8 permissionlessInclusionMultiplier;
    }

    /// @notice Represents a source of derivation data within a Proposal
    struct DerivationSource {
        /// @notice Whether this source is from a forced inclusion.
        bool isForcedInclusion;
        /// @notice Blobs that contain the source's manifest data.
        LibBlobs.BlobSlice blobSlice;
    }

    /// @notice Represents a proposal for L2 blocks.
    struct Proposal {
        /// @notice Unique identifier for the proposal.
        uint48 id;
        /// @notice The L1 block timestamp when the proposal was accepted.
        uint48 timestamp;
        /// @notice The timestamp of the last slot where the current preconfer can propose.
        uint48 endOfSubmissionWindowTimestamp;
        /// @notice Address of the proposer.
        address proposer;
        /// @notice Address of the designated prover from the auction.
        address designatedProver;
        /// @notice Hash of the parent proposal (zero for genesis).
        bytes32 parentProposalHash;
        /// @notice The L1 block number when the proposal was accepted.
        uint48 originBlockNumber;
        /// @notice The hash of the origin block.
        bytes32 originBlockHash;
        /// @notice The percentage of base fee paid to coinbase.
        uint8 basefeeSharingPctg;
        /// @notice Array of derivation sources, where each can be regular or forced inclusion.
        DerivationSource[] sources;
    }

    /// @notice Represents the core state of the inbox.
    /// @dev All 5 uint48 fields (30 bytes) pack into a single storage slot.
    struct CoreState {
        /// @notice The next proposal ID to be assigned.
        uint48 nextProposalId;
        /// @notice The last L1 block ID where a proposal was made.
        uint48 lastProposalBlockId;
        /// @notice The ID of the last finalized proposal.
        uint48 lastFinalizedProposalId;
        /// @notice The timestamp when the last proposal was finalized.
        uint48 lastFinalizedTimestamp;
        /// @notice The timestamp when the last checkpoint was saved.
        /// @dev In genesis block, this is set to 0 to allow the first checkpoint to be saved.
        uint48 lastCheckpointTimestamp;
        /// @notice The block hash of the last finalized proposal.
        bytes32 lastFinalizedBlockHash;
    }

    /// @notice Input data for the propose function
    struct ProposeInput {
        /// @notice The deadline timestamp for transaction inclusion (0 = no deadline).
        uint48 deadline;
        /// @notice Blob reference for proposal data.
        LibBlobs.BlobReference blobReference;
        /// @notice The number of forced inclusions that the proposer wants to process.
        /// @dev This can be set to 0 if no forced inclusions are due, and there's none in the queue
        /// that he wants to include.
        uint8 numForcedInclusions;
    }

    /// @notice Transition data for a proposal used in prove
    struct Transition {
        /// @notice Address of the designated prover.
        address designatedProver;
        /// @notice Timestamp of the proposal.
        uint48 timestamp;
        /// @notice end block hash for the proposal.
        bytes32 blockHash;
    }

    /// @notice Commitment data that the prover commits to when submitting a proof.
    struct Commitment {
        /// @notice The ID of the first proposal being proven.
        uint48 firstProposalId;
        /// @notice The checkpoint hash of the parent of the first proposal, this is used
        /// to verify checkpoint continuity in the proof.
        bytes32 firstProposalParentBlockHash;
        /// @notice The hash of the last proposal being proven.
        bytes32 lastProposalHash;
        /// @notice The actual prover who generated the proof.
        address actualProver;
        /// @notice The block number for the end L2 block in this proposal.
        uint48 endBlockNumber;
        /// @notice The state root for the end L2 block in this proposal.
        bytes32 endStateRoot;
        /// @notice Array of transitions for each proposal in the proof range.
        Transition[] transitions;
    }

    /// @notice Input data for the prove function.
    /// @dev This struct contains two categories of data:
    ///      1. Commitment data - What the prover is actually proving. This must be fully
    ///         determined before proof generation and is the only input to the prover's
    ///         guest program.
    ///      2. Usage options - Parameters that can be decided after proof generation
    ///         (e.g., whether to proactively write a checkpoint). The prover system can
    ///         choose or adjust these options using additional data during or after
    ///         proof generation.
    struct ProveInput {
        /// @notice The commitment data that the proof verifies.
        Commitment commitment;
        /// @notice Whether to force syncing the last checkpoint even if the minimum
        /// delay has not passed.
        /// @dev This allows checkpoint synchronization ahead of schedule.
        bool forceCheckpointSync;
    }

    /// @notice Payload data emitted in the Proved event
    struct ProvedEventPayload {
        /// @notice The ID of the first proposal being proven.
        uint48 firstProposalId;
        /// @notice The ID of the first proposal that had not been proven before.
        uint48 firstNewProposalId;
        /// @notice The ID of the last proposal being proven.
        uint48 lastProposalId;
        /// @notice The actual prover who generated the proof.
        address actualProver;
        /// @notice Whether the checkpoint was synced.
        bool checkpointSynced;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed.
    /// @param id Unique identifier for the proposal.
    /// @param data The encoded proposal data (Proposal struct without the id field).
    event Proposed(uint48 indexed id, bytes data);

    /// @notice Emitted when a proof is submitted
    /// @param firstProposalId The first proposal ID covered by the proof (may include finalized ids)
    /// @param firstNewProposalId The first proposal ID that was newly proven by this proof
    /// @param lastProposalId The last proposal ID covered by the proof
    /// @param actualProver The prover that submitted the proof
    /// @param checkpointSynced Whether a checkpoint was synced as part of this proof
    event Proved(
        uint48 firstProposalId,
        uint48 firstNewProposalId,
        uint48 lastProposalId,
        address indexed actualProver,
        bool checkpointSynced
    );

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Proposes new L2 blocks and forced inclusions to the rollup using blobs for DA.
    /// @dev The proposer must send ETH to pay the designated prover's fee. Any excess ETH
    ///      will be refunded to the proposer.
    /// @param _lookahead Encoded data forwarded to the proposer checker (i.e. lookahead payloads).
    /// @param _data The encoded ProposeInput struct.
    function propose(bytes calldata _lookahead, bytes calldata _data) external payable;

    /// @notice Verifies a batch proof covering multiple consecutive proposals and finalizes them.
    /// @param _data The encoded ProveInput struct.
    /// @param _proof The validity proof for the batch of proposals.
    function prove(bytes calldata _data, bytes calldata _proof) external;

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @notice Returns the configuration parameters of the Inbox contract
    /// @return config_ The configuration struct containing all immutable parameters
    function getConfig() external view returns (Config memory config_);

    /// @notice Returns the current core state.
    /// @return The core state struct.
    function getCoreState() external view returns (CoreState memory);

    /// @notice Returns the proposal hash for a given proposal ID.
    /// @param _proposalId The proposal ID to look up.
    /// @return proposalHash_ The hash stored at the proposal's ring buffer slot.
    function getProposalHash(uint256 _proposalId) external view returns (bytes32 proposalHash_);
}
