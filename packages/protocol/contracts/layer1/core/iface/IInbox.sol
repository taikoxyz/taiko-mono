// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title IInbox
/// @notice Interface for the Inbox contract that manages L2 block proposals and proving.
/// @dev The Inbox contract is the main entry point for proposers and provers to interact with
/// the rollup. It handles proposal submission, proof verification, and finalization.
/// @custom:security-contact security@taiko.xyz
interface IInbox {
    /// @notice Configuration parameters for the Inbox contract.
    /// @dev All parameters are immutable after construction.
    struct Config {
        /// @notice Address of the codec contract for encoding/decoding and hashing.
        address codec;
        /// @notice Address of the proof verifier contract.
        address proofVerifier;
        /// @notice Address of the proposer checker contract for lookahead validation.
        address proposerChecker;
        /// @notice Address of the checkpoint store contract.
        address checkpointStore;
        /// @notice Address of the signal service contract for cross-chain messaging.
        address signalService;
        /// @notice Duration in seconds for the designated prover to submit a proof.
        uint40 provingWindow;
        /// @notice Extended duration in seconds if designated prover misses the initial window.
        uint40 extendedProvingWindow;
        /// @notice Maximum number of proposals that can be finalized in a single block.
        uint256 maxFinalizationCount;
        /// @notice Grace period in seconds after proving before finalization is enforced.
        uint40 finalizationGracePeriod;
        /// @notice Size of the ring buffer for storing proposal hashes.
        uint256 ringBufferSize;
        /// @notice Percentage of L2 base fee paid to L1 coinbase (0-100).
        uint8 basefeeSharingPctg;
        /// @notice Minimum number of due forced inclusions a proposer must process per proposal.
        uint256 minForcedInclusionCount;
        /// @notice Delay in seconds before a forced inclusion becomes due.
        uint16 forcedInclusionDelay;
        /// @notice Base fee in Gwei for forced inclusion requests.
        uint64 forcedInclusionFeeInGwei;
        /// @notice Queue size threshold at which the forced inclusion fee doubles.
        uint64 forcedInclusionFeeDoubleThreshold;
        /// @notice Minimum proposal delay between checkpoint synchronizations.
        uint16 minSyncDelay;
        /// @notice Multiplier applied to forcedInclusionDelay to determine when proposing becomes
        /// permissionless due to stale forced inclusions.
        uint8 permissionlessInclusionMultiplier;
    }

    /// @notice Represents a single source of derivation data within a Derivation.
    /// @dev Each source can be either a regular proposer submission or a forced inclusion.
    struct DerivationSource {
        /// @notice True if this source is from a forced inclusion request.
        bool isForcedInclusion;
        /// @notice Blob data containing the source's transaction manifest.
        LibBlobs.BlobSlice blobSlice;
    }

    /// @notice Contains L1-anchored derivation data for a proposal.
    /// @dev This data is hashed and stored in Proposal.derivationHash to reduce calldata size
    /// during proving. The full data is emitted in the Proposed event for derivation.
    struct Derivation {
        /// @notice L1 block number when the proposal was accepted.
        uint40 originBlockNumber;
        /// @notice Percentage of L2 base fee paid to L1 coinbase (0-100).
        uint8 basefeeSharingPctg;
        /// @notice Hash of the L1 origin block for anchor verification.
        bytes32 originBlockHash;
        /// @notice Array of derivation sources (regular submissions and/or forced inclusions).
        DerivationSource[] sources;
    }

    /// @notice Represents a proposal containing one or more L2 blocks.
    /// @dev Proposals form a linked list via parentProposalHash for fork choice.
    struct Proposal {
        /// @notice Unique sequential identifier for this proposal.
        uint40 id;
        /// @notice L1 block timestamp when the proposal was accepted.
        uint40 timestamp;
        /// @notice Deadline timestamp for the current preconfer's submission window.
        uint40 endOfSubmissionWindowTimestamp;
        /// @notice Address of the proposer who submitted this proposal.
        address proposer;
        /// @notice Hash of the CoreState at the time of this proposal.
        bytes32 coreStateHash;
        /// @notice Hash of the Derivation struct for this proposal.
        bytes32 derivationHash;
        /// @notice Hash of the parent proposal (forms proposal chain).
        bytes32 parentProposalHash;
    }

    /// @notice Represents a state transition for a proposal.
    /// @dev Contains the cryptographic commitments needed to verify the transition.
    struct Transition {
        /// @notice Hash of the bond instructions for this transition.
        bytes32 bondInstructionHash;
        /// @notice Hash of the checkpoint (block number, hash, and state root).
        bytes32 checkpointHash;
    }

    /// @notice Storage-optimized record of a proven transition.
    /// @dev Uses bytes27 for transitionHash to fit with uint40 deadline in a single slot.
    struct TransitionRecord {
        /// @notice Truncated hash of the transition (first 27 bytes).
        bytes27 transitionHash;
        /// @notice Timestamp deadline for finalization.
        uint40 finalizationDeadline;
    }

    /// @notice Metadata about the prover of a transition.
    /// @dev Separated from Transition to support out-of-order proving.
    struct TransitionMetadata {
        /// @notice Address of the prover designated at proposal time.
        address designatedProver;
        /// @notice Address of the prover who actually submitted the proof.
        address actualProver;
    }

    /// @notice Message struct for signaling bond instruction changes to L2.
    /// @dev Sent via signal service to enable L2 bond settlement.
    struct BondInstructionMessage {
        /// @notice First proposal ID in the range of finalized proposals.
        uint40 firstProposalId;
        /// @notice Last proposal ID in the range of finalized proposals.
        uint40 lastProposalId;
        /// @notice Aggregated hash of all bond instructions in the range.
        bytes32 aggregatedBondInstructionsHash;
    }

    /// @notice Core state tracking proposal and finalization progress.
    /// @dev This state is hashed and included in each proposal for state validation.
    struct CoreState {
        /// @notice ID of the most recently accepted proposal.
        uint40 proposalHead;
        /// @notice L1 block number containing the most recent proposal.
        uint40 proposalHeadContainerBlock;
        /// @notice ID of the last finalized proposal.
        uint40 finalizationHead;
        /// @notice Proposal ID when the last checkpoint synchronization occurred.
        uint40 synchronizationHead;
        /// @notice Transition hash of the finalization head (truncated to 27 bytes).
        bytes27 finalizationHeadTransitionHash;
        /// @notice Rolling hash of all bond instructions from finalized proposals.
        bytes32 aggregatedBondInstructionsHash;
    }

    /// @notice Input parameters for the propose function.
    /// @dev Encoded and passed as calldata to minimize gas costs.
    struct ProposeInput {
        /// @notice Transaction inclusion deadline timestamp (0 = no deadline).
        uint40 deadline;
        /// @notice Expected core state before this proposal (for validation).
        CoreState coreState;
        /// @notice Parent proposal(s) for validation (typically 1, may be 2 for fork resolution).
        Proposal[] headProposalAndProof;
        /// @notice Reference to blob data containing the proposal content.
        LibBlobs.BlobReference blobReference;
        /// @notice Array of transitions to finalize during this proposal.
        Transition[] transitions;
        /// @notice Checkpoint data for finalization validation.
        ICheckpointStore.Checkpoint checkpoint;
        /// @notice Number of forced inclusions to process (0 if none due or desired).
        uint8 numForcedInclusions;
    }

    /// @notice Input parameters for the prove function.
    /// @dev Each ProveInput proves a single proposal's state transition.
    struct ProveInput {
        /// @notice The proposal being proven.
        Proposal proposal;
        /// @notice Checkpoint containing the end state (block number, hash, state root).
        ICheckpointStore.Checkpoint checkpoint;
        /// @notice Prover metadata (designated and actual prover addresses).
        TransitionMetadata metadata;
        /// @notice Hash of the parent transition this proof builds upon.
        bytes27 parentTransitionHash;
    }

    /// @notice Payload data emitted in the Proposed event.
    /// @dev Contains all data needed for L2 nodes to derive the proposed blocks.
    struct ProposedEventPayload {
        /// @notice The proposal that was created.
        Proposal proposal;
        /// @notice Full derivation data for block derivation.
        Derivation derivation;
        /// @notice Core state after accepting this proposal.
        CoreState coreState;
        /// @notice Transitions finalized during this proposal.
        Transition[] transitions;
    }

    /// @notice Payload data emitted in the Proved event.
    /// @dev Contains proof result data for indexers and L2 nodes.
    struct ProvedEventPayload {
        /// @notice Timestamp deadline for finalization.
        uint40 finalizationDeadline;
        /// @notice Checkpoint containing the proven end state.
        ICheckpointStore.Checkpoint checkpoint;
        /// @notice Bond instructions for this proven transition.
        LibBonds.BondInstruction[] bondInstructions;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new proposal is accepted.
    /// @param proposalId The unique identifier of the proposal.
    /// @param data ABI-encoded ProposedEventPayload containing proposal details.
    event Proposed(uint40 indexed proposalId, bytes data);

    /// @notice Emitted when a proof is successfully submitted.
    /// @param proposalId The ID of the proven proposal.
    /// @param parentTransitionHash The parent transition hash this proof builds upon.
    /// @param data ABI-encoded ProvedEventPayload containing proof details.
    event Proved(uint40 indexed proposalId, bytes27 indexed parentTransitionHash, bytes data);

    /// @notice Emitted when a conflicting transition is detected. This event will be followed by a
    /// Proved event.
    /// @param proposalId The ID of the proposal with the conflict.
    /// @param parentTransitionHash The parent transition hash identifying the transition path.
    /// @param oldTransitionHash The existing transition hash before the conflict.
    /// @param newTransitionHash The new conflicting transition hash.
    event TransitionConflictDetected(
        uint40 indexed proposalId,
        bytes27 indexed parentTransitionHash,
        bytes27 oldTransitionHash,
        bytes27 newTransitionHash
    );

    /// @notice Emitted when a duplicate transition proof is skipped.
    /// @param proposalId The ID of the proposal.
    /// @param parentTransitionHash The parent transition hash.
    event DuplicateTransitionSkipped(
        uint40 indexed proposalId, bytes27 indexed parentTransitionHash
    );

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Submits a new proposal containing L2 blocks.
    /// @dev Validates proposer authorization, processes forced inclusions, and finalizes
    /// pending transitions. Emits Proposed event on success.
    /// @param _lookahead Encoded lookahead data forwarded to the proposer checker for validation.
    /// @param _data ABI-encoded ProposeInput struct containing proposal parameters.
    function propose(bytes calldata _lookahead, bytes calldata _data) external;

    /// @notice Submits validity proofs for one or more proposals.
    /// @dev Proposals do not need to be consecutive. Each proof is verified against
    /// the configured proof verifier. Emits Proved event for each successful proof.
    /// @param _data ABI-encoded array of ProveInput structs.
    /// @param _proof Validity proof data for the batch of transitions.
    function prove(bytes calldata _data, bytes calldata _proof) external;

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @notice Retrieves the stored hash for a proposal.
    /// @dev Returns the hash from the ring buffer slot for the given proposal ID.
    /// @param _proposalId The proposal ID to look up.
    /// @return proposalHash_ The stored proposal hash (zero if slot is empty or overwritten).
    function getProposalHash(uint40 _proposalId) external view returns (bytes32 proposalHash_);

    /// @notice Retrieves the transition record for a proposal and parent transition.
    /// @dev Used to check proof status and finalization deadline.
    /// @param _proposalId The proposal ID.
    /// @param _parentTransitionHash The parent transition hash identifying the transition path.
    /// @return record_ The transition record containing hash and finalization deadline.
    function getTransitionRecord(
        uint40 _proposalId,
        bytes27 _parentTransitionHash
    )
        external
        view
        returns (TransitionRecord memory record_);

    /// @notice Returns the immutable configuration parameters.
    /// @return config_ The configuration struct with all Inbox parameters.
    function getConfig() external view returns (Config memory config_);
}
