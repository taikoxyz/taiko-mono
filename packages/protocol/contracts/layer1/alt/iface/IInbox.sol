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
        /// @notice The proof verifier contract
        address proofVerifier;
        /// @notice The proposer checker contract
        address proposerChecker;
        /// @notice The checkpoint store contract address
        address checkpointStore;
        /// @notice The signal service contract address
        address signalService;
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
        /// @notice The minimum delay in proposals between two syncs
        uint16 minSyncDelay;
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

    /// @notice Represents a record of a transition with additional metadata.
    struct Transition {
        /// @notice The hash of the bond instructions
        bytes32 bondInstructionHash;
        /// @notice The hash of the checkpoint
        bytes32 checkpointHash;
    }

    /// @notice Struct for storing transition record metadata (H=Hash, D=Deadline, S=Span).
    /// @dev Stores transition record hash, finalization deadline, and span.
    struct TransitionRecord {
        bytes27 transitionHash;
        uint40 finalizationDeadline;
    }

    /// @notice Metadata about the proving of a transition
    /// @dev Separated from Transition to enable out-of-order proving
    struct TransitionMetadata {
        /// @notice The designated prover for this transition.
        address designatedProver;
        /// @notice The actual prover who submitted the proof.
        address actualProver;
    }

    struct BondInstructionHashMessage {
        /// @notice The start proposal ID when the change occurred.
        uint40 startProposalId;
        /// @notice The end proposal ID when the change occurred.
        uint40 endProposalId;
        /// @notice The hash of the bond instructions.
        bytes32 bondInstructionsHash;
    }

    /// @notice Represents the core state of the inbox.
    struct CoreState {
        /// @notice The ID of the most recent proposal.
        uint40 proposalHead;
        /// @notice The last L1 block ID where a proposal was made.
        uint40 proposalHeadContainerBlock;
        /// @notice The ID of the last finalized proposal.
        uint40 finalizationHead;
        /// @notice The proposal ID when the last sync occurred.
        uint40 synchronizationHead;
        /// @notice The hash of the last finalized transition.
        bytes27 finalizationHeadTransitionHash;
        /// @notice The hash of all bond instructions.
        bytes32 aggregatedBondInstructionsHash;
    }

    /// @notice Input data for the propose function
    struct ProposeInput {
        /// @notice The deadline timestamp for transaction inclusion (0 = no deadline).
        uint40 deadline;
        /// @notice The current core state before this proposal.
        CoreState coreState;
        /// @notice Array of existing proposals for validation (1-2 elements).
        Proposal[] headProposalAndProof;
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
        Proposal proposal;
        ICheckpointStore.Checkpoint checkpoint;
        TransitionMetadata metadata;
        bytes27 parentTransitionHash;
    }

    /// @notice Payload data emitted in the Proposed event
    struct ProposedEventPayload {
        /// @notice The proposal that was created.
        Proposal proposal;
        /// @notice The derivation data for the proposal.
        Derivation derivation;
        /// @notice The core state after the proposal.
        CoreState coreState;
        Transition[] transitions;
    }

    /// @notice Payload data emitted in the Proved event
    struct ProvedEventPayload {
        uint40 finalizationDeadline;
        ICheckpointStore.Checkpoint checkpoint;
        LibBonds.BondInstruction[] bondInstructions;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed.
    /// @param proposalId The ID of the proposed proposal
    /// @param data The encoded ProposedEventPayload
    event Proposed(uint40 indexed proposalId, bytes data);

    /// @notice Emitted when a proof is submitted
    /// @param proposalId The ID of the proven proposal
    /// @param parentTransitionHash The hash of the parent transition
    /// @param data The encoded ProvedEventPayload
    event Proved(uint40 indexed proposalId, bytes27 indexed parentTransitionHash, bytes data);

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Proposes new proposals that contains L2 blocks.
    /// @param _lookahead Encoded data forwarded to the proposer checker (i.e. lookahead payloads).
    /// @param _data The encoded ProposeInput struct.
    function propose(bytes calldata _lookahead, bytes calldata _data) external;

    /// @notice Proves state transitions for one or more proposals. The proposals proved do not need to be consecutive.
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
    /// @return record_ The transition record metadata.
    function getTransitionRecord(
        uint40 _proposalId,
        bytes27 _parentTransitionHash
    )
        external
        view
        returns (TransitionRecord memory record_);

    /// @notice Returns the configuration parameters of the Inbox contract
    /// @return config_ The configuration struct containing all immutable parameters
    function getConfig() external view returns (Config memory config_);
}
