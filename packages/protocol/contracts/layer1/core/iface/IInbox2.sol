// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds2 } from "src/shared/libs/LibBonds2.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title IInbox
/// @notice Interface for the Shasta inbox contracts
/// @custom:security-contact security@taiko.xyz
interface IInbox2 {
    /// @notice Configuration struct for Inbox constructor parameters
    struct Config {
        /// @notice The codec used for encoding and hashing
        address codec;
        /// @notice The signal service contract address
        address checkpointStore;
        /// @notice The proof verifier contract
        address proofVerifier;
        /// @notice The proposer checker contract
        address proposerChecker;
        /// @notice The proving window in seconds
        uint40 provingWindow;
        /// @notice The extended proving window in seconds
        uint40 extendedProvingWindow;
        /// @notice The maximum number of finalized proposals in one block
        uint256 maxFinalizationCount;
        /// @notice The finalization grace period in seconds
        uint40 finalizationGracePeriod;
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

    /// @notice Represents a source of derivation data within a Derivation
    struct DerivationSource {
        /// @notice Whether this source is from a forced inclusion.
        bool isForcedInclusion;
        /// @notice Blobs that contain the source's manifest data.
        LibBlobs.BlobSlice blobSlice;
    }

    /// @notice Contains derivation data for a proposal that is not needed during proving.
    /// @dev This data is hashed and stored in the Proposal struct to reduce calldata size.
    struct Derivation {
        /// @notice The L1 block number when the proposal was accepted.
        uint40 originBlockNumber;
        /// @notice The percentage of base fee paid to coinbase.
        uint8 basefeeSharingPctg;
        /// @notice The hash of the origin block.
        bytes32 originBlockHash;
        /// @notice Array of derivation sources, where each can be regular or forced inclusion.
        DerivationSource[] sources;
    }

    /// @notice Represents a proposal for L2 blocks.
    struct Proposal {
        /// @notice Unique identifier for the proposal.
        uint40 id;
        /// @notice The L1 block timestamp when the proposal was accepted.
        uint40 timestamp;
        /// @notice The timestamp of the last slot where the current preconfer can propose.
        uint40 endOfSubmissionWindowTimestamp;
        /// @notice Address of the proposer.
        address proposer;
        /// @notice The current hash of coreState
        bytes32 coreStateHash;
        /// @notice Hash of the Derivation struct containing additional proposal data.
        bytes32 derivationHash;
        /// @notice The hash of the parent proposal
        bytes32 parentProposalHash;
    }

    /// @notice Struct for storing transition record metadata (H=Hash, D=Deadline, S=Span).
    /// @dev Stores transition record hash, finalization deadline, and span.
    struct TransitionRecord {
        bytes26 transitionHash;
        uint40 finalizationDeadline; // TODO(daniel): use uint40 for all timestamps
        uint8 span;
    }

    /// @notice Metadata about the proving of a transition
    /// @dev Separated from Transition to enable out-of-order proving
    struct ProofMetadata {
        address proposer;
        uint40 proposalTimestamp;
        /// @notice The designated prover for this transition.
        address designatedProver;
        /// @notice The actual prover who submitted the proof.
        address actualProver;
    }

    /// @notice Represents a record of a transition with additional metadata.
    struct Transition {
        /// @notice The bond instructions.
        LibBonds2.BondInstruction[] bondInstructions;
        /// @notice The hash of the checkpoint.
        bytes32 endCheckpointHash;
    }

    /// @notice Represents the core state of the inbox.
    struct CoreState {
        /// @notice The next proposal ID to be assigned.
        uint40 nextProposalId;
        /// @notice The last L1 block ID where a proposal was made.
        uint40 lastProposalBlockId;
        /// @notice The ID of the last finalized proposal.
        uint40 lastFinalizedProposalId;
        /// @notice The timestamp when the last checkpoint was saved.
        /// @dev In genesis block, this is set to 0 to allow the first checkpoint to be saved.
        uint40 lastCheckpointTimestamp;
        /// @notice The hash of the last finalized transition.
        bytes32 lastFinalizedTransitionHash;
        /// @notice The hash of all bond instructions.
        bytes32 bondInstructionsHashOld;
        bytes32 bondInstructionsHashNew;
    }

    /// @notice Input data for the propose function
    struct ProposeInput {
        /// @notice The deadline timestamp for transaction inclusion (0 = no deadline).
        uint40 deadline;
        /// @notice The current core state before this proposal.
        CoreState coreState;
        /// @notice Array of existing proposals for validation (1-2 elements).
        Proposal[] parentProposals;
        /// @notice Blob reference for proposal data.
        LibBlobs.BlobReference blobReference;
        /// @notice Array of transition records for finalization.
        Transition[] transitions;
        /// @notice The checkpoint for finalization.
        ICheckpointStore.Checkpoint checkpoint;
        /// @notice The number of forced inclusions that the proposer wants to process.
        /// @dev This can be set to 0 if no forced inclusions are due, and there's none in the queue
        /// that he wants to include.
        uint8 numForcedInclusions;
    }

    struct ProveInput {
        Proposal endProposal;
        ICheckpointStore.Checkpoint endCheckpoint;
        ProofMetadata[] proofMetadatas;
        bytes32 parentTransitionHash;
    }

    /// @notice Payload data emitted in the Proposed event
    struct ProposedEventPayload {
        /// @notice The proposal that was created.
        Proposal proposal;
        /// @notice The derivation data for the proposal.
        Derivation derivation;
        /// @notice The core state after the proposal.
        CoreState coreState;
        /// @notice Bond instructions finalized while processing this proposal.
        LibBonds2.BondInstruction[] bondInstructions;
    }

    /// @notice Payload data emitted in the Proved event
    struct ProvedEventPayload {
        /// @notice The proposal ID that was proven.
        uint40 proposalId;
        /// @notice The transition record containing additional metadata.
        Transition transition;
        /// @notice The metadata containing prover information.
        TransitionRecord record;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed.
    /// @param data The encoded ProposedEventPayload
    event Proposed(bytes data);

    /// @notice Emitted when a proof is submitted
    /// @param data The encoded ProvedEventPayload
    event Proved(bytes data);

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Proposes new proposals of L2 blocks.
    /// @param _lookahead Encoded data forwarded to the proposer checker (i.e. lookahead payloads).
    /// @param _data The encoded ProposeInput struct.
    function propose(bytes calldata _lookahead, bytes calldata _data) external;

    /// @notice Proves a transition about some properties of a proposal, including its state
    /// transition.
    /// @param _data The encoded ProveInput struct.
    /// @param _proof Validity proof for the transitions.
    function prove(bytes calldata _data, bytes calldata _proof) external;

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @notice Returns the proposal hash for a given proposal ID.
    /// @param _proposalId The proposal ID to look up.
    /// @return proposalHash_ The hash stored at the proposal's ring buffer slot.
    function getProposalHash(uint40 _proposalId) external view returns (bytes32 proposalHash_);

    /// @notice Returns the transition record hash for a given proposal ID and parent transition
    /// hash.
    /// @param _proposalId The proposal ID.
    /// @param _parentTransitionHash The parent transition hash.
    /// @return transitionRecord_ The transition record metadata.
    function getTransitionRecord(
        uint40 _proposalId,
        bytes32 _parentTransitionHash
    )
        external
        view
        returns (TransitionRecord memory transitionRecord_);

    /// @notice Returns the configuration parameters of the Inbox contract
    /// @return config_ The configuration struct containing all immutable parameters
    function getConfig() external view returns (Config memory config_);
}
