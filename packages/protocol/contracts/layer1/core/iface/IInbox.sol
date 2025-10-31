// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title IInbox
/// @notice Interface for the Shasta inbox contracts
/// @custom:security-contact security@taiko.xyz
interface IInbox {
    /// @notice Configuration struct for Inbox constructor parameters
    struct Config {
        /// @notice The codec used for encoding and hashing
        address codec;
        /// @notice The token used for bonds
        address bondToken;
        /// @notice The signal service contract address
        address checkpointStore;
        /// @notice The proof verifier contract
        address proofVerifier;
        /// @notice The proposer checker contract
        address proposerChecker;
        /// @notice The proving window in seconds
        uint48 provingWindow;
        /// @notice The extended proving window in seconds
        uint48 extendedProvingWindow;
        /// @notice The maximum number of finalized proposals in one block
        uint256 maxFinalizationCount;
        /// @notice The finalization grace period in seconds
        uint48 finalizationGracePeriod;
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
        /// @notice Version identifier for composite key generation
        uint16 compositeKeyVersion;
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
        uint48 originBlockNumber;
        /// @notice The hash of the origin block.
        bytes32 originBlockHash;
        /// @notice The percentage of base fee paid to coinbase.
        uint8 basefeeSharingPctg;
        /// @notice Array of derivation sources, where each can be regular or forced inclusion.
        DerivationSource[] sources;
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
        /// @notice The current hash of coreState
        bytes32 coreStateHash;
        /// @notice Hash of the Derivation struct containing additional proposal data.
        bytes32 derivationHash;
    }

    /// @notice Represents a transition about the state transition of a proposal.
    /// @dev Prover information has been moved to TransitionMetadata for out-of-order proving
    /// support
    struct Transition {
        /// @notice The proposal's hash.
        bytes32 proposalHash;
        /// @notice The parent transition's hash, this is used to link the transition to its parent
        /// transition to
        /// finalize the corresponding proposal.
        bytes32 parentTransitionHash;
        /// @notice The end block header containing number, hash, and state root.
        ICheckpointStore.Checkpoint checkpoint;
    }

    /// @notice Metadata about the proving of a transition
    /// @dev Separated from Transition to enable out-of-order proving
    struct TransitionMetadata {
        /// @notice The designated prover for this transition.
        address designatedProver;
        /// @notice The actual prover who submitted the proof.
        address actualProver;
    }

    /// @notice Represents a record of a transition with additional metadata.
    struct TransitionRecord {
        /// @notice The span indicating how many proposals this transition record covers.
        uint8 span;
        /// @notice The bond instructions.
        LibBonds.BondInstruction[] bondInstructions;
        /// @notice The hash of the last transition in the span.
        bytes32 transitionHash;
        /// @notice The hash of the last checkpoint in the span.
        bytes32 checkpointHash;
    }

    /// @notice Represents the core state of the inbox.
    struct CoreState {
        /// @notice The next proposal ID to be assigned.
        uint48 nextProposalId;
        /// @notice The last block ID where a proposal was made.
        uint48 lastProposalBlockId;
        /// @notice The ID of the last finalized proposal.
        uint48 lastFinalizedProposalId;
        /// @notice The timestamp when the last checkpoint was saved.
        /// @dev In genesis block, this is set to 0 to allow the first checkpoint to be saved.
        uint48 lastCheckpointTimestamp;
        /// @notice The hash of the last finalized transition.
        bytes32 lastFinalizedTransitionHash;
        /// @notice The hash of all bond instructions.
        bytes32 bondInstructionsHash;
    }

    /// @notice Input data for the propose function
    struct ProposeInput {
        /// @notice The deadline timestamp for transaction inclusion (0 = no deadline).
        uint48 deadline;
        /// @notice The current core state before this proposal.
        CoreState coreState;
        /// @notice Array of existing proposals for validation (1-2 elements).
        Proposal[] parentProposals;
        /// @notice Blob reference for proposal data.
        LibBlobs.BlobReference blobReference;
        /// @notice Array of transition records for finalization.
        TransitionRecord[] transitionRecords;
        /// @notice The checkpoint for finalization.
        ICheckpointStore.Checkpoint checkpoint;
        /// @notice The number of forced inclusions that the proposer wants to process.
        /// @dev This can be set to 0 if no forced inclusions are due, and there's none in the queue
        /// that he wants to include.
        uint8 numForcedInclusions;
    }

    /// @notice Input data for the prove function
    struct ProveInput {
        /// @notice Array of proposals to prove.
        Proposal[] proposals;
        /// @notice Array of transitions containing proof details.
        Transition[] transitions;
        /// @notice Array of metadata for prover information.
        /// @dev Must have same length as transitions array.
        TransitionMetadata[] metadata;
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
        LibBonds.BondInstruction[] bondInstructions;
    }

    /// @notice Payload data emitted in the Proved event
    struct ProvedEventPayload {
        /// @notice The proposal ID that was proven.
        uint48 proposalId;
        /// @notice The transition that was proven.
        Transition transition;
        /// @notice The transition record containing additional metadata.
        TransitionRecord transitionRecord;
        /// @notice The metadata containing prover information.
        TransitionMetadata metadata;
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

    /// @notice Emitted when a conflicting transition is detected. This event will be followed by a
    /// Proved event.
    event TransitionConflictDetected();

    /// @notice Emitted when a transition is proved again. This event will be followed by a Proved
    /// event.
    event TransitionDuplicateDetected();

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
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_);

    /// @notice Returns the transition record hash for a given proposal ID and parent transition
    /// hash.
    /// @param _proposalId The proposal ID.
    /// @param _parentTransitionHash The parent transition hash.
    /// @return finalizationDeadline_ The timestamp when finalization is enforced.
    /// @return recordHash_ The hash of the transition record.
    function getTransitionRecordHash(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        external
        view
        returns (uint48 finalizationDeadline_, bytes26 recordHash_);

    /// @notice Returns the configuration parameters of the Inbox contract
    /// @return config_ The configuration struct containing all immutable parameters
    function getConfig() external view returns (Config memory config_);
}
