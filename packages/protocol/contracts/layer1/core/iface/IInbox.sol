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
        /// @notice The proof verifier contract
        address proofVerifier;
        /// @notice The proposer checker contract
        address proposerChecker;
        /// @notice The signal service contract address
        address signalService;
        /// @notice The proving window in seconds
        uint48 provingWindow;
        /// @notice The extended proving window in seconds
        uint48 extendedProvingWindow;
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
        /// @notice The minimum number of proposals that must be finalized in a single prove2 call
        uint8 minProposalsToFinalize;
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
        /// @notice Hash of the parent proposal (zero for genesis).
        bytes32 parentProposalHash;
        /// @notice Hash of the Derivation struct containing additional proposal data.
        bytes32 derivationHash;
    }

    /// @notice Represents a transition about the state transition of a proposal.
    struct Transition {
        /// @notice The proposal's hash.
        bytes32 proposalHash;
        /// @notice The parent transition's hash, this is used to link the transition to its parent
        /// transition to
        /// finalize the corresponding proposal.
        bytes32 parentTransitionHash;
        /// @notice The end block header containing number, hash, and state root.
        ICheckpointStore.Checkpoint checkpoint;
        /// @notice The designated prover for this transition.
        address designatedProver;
        /// @notice The actual prover who submitted the proof.
        address actualProver;
    }

    /// @notice Represents the core state of the inbox.
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
        /// @notice The hash of the last finalized transition.
        bytes32 lastFinalizedTransitionHash;
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

    /// @notice Input data for the prove function
    struct ProveInput {
        /// @notice Array of proposals to prove.
        Proposal[] proposals;
        /// @notice Array of transitions containing proof details.
        Transition[] transitions;
        /// @notice Whether to sync the checkpoint from the last transition.
        /// This has to be set to `true` if `_minCheckpointDelay` has passed, but can be set to `true`
        /// before if you want to sync the checkpoint early.
        bool syncCheckpoint;
    }

    /// @notice Input data for the prove2 function
    struct ProveInput2 {
        /// @notice The ID of the last proposal being proven.
        uint48 lastProposalId;
        /// @notice The checkpoint from the last transition.
        ICheckpointStore.Checkpoint lastCheckpoint;
        /// @notice Array of transition hashes (N+1 for N proposals).
        bytes32[] transitionHashs;
    }

    /// @notice Payload data emitted in the Proposed event
    struct ProposedEventPayload {
        /// @notice The proposal that was created.
        Proposal proposal;
        /// @notice The derivation data for the proposal.
        Derivation derivation;
    }

    /// @notice Payload data emitted in the Proved event
    struct ProvedEventPayload {
        /// @notice The proposal ID that was proven.
        uint48 proposalId;
        /// @notice The transition that was proven.
        Transition transition;
        /// @notice The bond instruction associated with the proof (BondType.NONE when unused).
        LibBonds.BondInstruction bondInstruction;
        /// @notice Signal hash emitted to L2 for bond processing (zero when unused).
        bytes32 bondSignal;
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

    /// @notice Proposes new L2 blocks and forced inclusions to the rollup using blobs for DA.
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

    /// @notice Returns the configuration parameters of the Inbox contract
    /// @return config_ The configuration struct containing all immutable parameters
    function getConfig() external view returns (Config memory config_);

    /// @notice Returns the current core state snapshot.
    function getState() external view returns (CoreState memory state_);
}
