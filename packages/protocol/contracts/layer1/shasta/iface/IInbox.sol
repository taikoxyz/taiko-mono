// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";

/// @title IInbox
/// @notice Interface for the Shasta inbox contracts
/// @custom:security-contact security@taiko.xyz
interface IInbox {
    /// @notice Configuration parameters for the Inbox contract
    struct Config {
        address bondToken;
        uint48 provingWindow;
        uint48 extendedProvingWindow;
        uint256 maxFinalizationCount;
        uint256 ringBufferSize;
        uint8 basefeeSharingPctg;
        address checkpointManager;
        address proofVerifier;
        address proposerChecker;
        /// @notice The minimum number of forced inclusions that the proposer is forced to process
        /// if they are due.
        uint256 minForcedInclusionCount;
        uint64 forcedInclusionDelay; // measured in seconds
        uint64 forcedInclusionFeeInGwei;
    }

    /// @notice Contains derivation data for a proposal that is not needed during proving.
    /// @dev This data is hashed and stored in the Proposal struct to reduce calldata size.
    struct Derivation {
        /// @notice The L1 block number when the proposal was accepted.
        uint48 originBlockNumber;
        /// @notice The hash of the origin block.
        bytes32 originBlockHash;
        /// @notice Whether the proposal is from a forced inclusion.
        bool isForcedInclusion;
        /// @notice The percentage of base fee paid to coinbase.
        uint8 basefeeSharingPctg;
        /// @notice Blobs that contains the proposal's manifest data.
        LibBlobs.BlobSlice blobSlice;
    }

    /// @notice Represents a proposal for L2 blocks.
    struct Proposal {
        /// @notice Unique identifier for the proposal.
        uint48 id;
        /// @notice The L1 block timestamp when the proposal was accepted.
        uint48 timestamp;
        /// @notice The timestamp of the last slot where the current preconfer can propose.
        uint48 lookaheadSlotTimestamp;
        /// @notice Address of the proposer.
        address proposer;
        /// @notice The current hash of coreState
        bytes32 coreStateHash;
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
        ICheckpointManager.Checkpoint checkpoint;
        /// @notice The designated prover.
        address designatedProver;
        /// @notice The actual prover.
        address actualProver;
    }

    /// @notice Represents a record of a transition with additional metadata.
    struct TransitionRecord {
        /// @notice The span indicating how many proposals this transition record covers.
        uint8 span;
        /// @notice The bond instructions.
        LibBonds.BondInstruction[] bondInstructions;
        /// @notice The transition's hash
        bytes32 transitionHash;
        /// @notice The hash of the checkpoint.
        bytes32 checkpointHash;
    }

    /// @notice Represents the core state of the inbox.
    struct CoreState {
        /// @notice The next proposal ID to be assigned.
        uint48 nextProposalId;
        /// @notice The ID of the last finalized proposal.
        uint48 lastFinalizedProposalId;
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
        ICheckpointManager.Checkpoint checkpoint;
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
    }

    /// @notice Payload data emitted in the Proposed event
    struct ProposedEventPayload {
        /// @notice The proposal that was created.
        Proposal proposal;
        /// @notice The derivation data for the proposal.
        Derivation derivation;
        /// @notice The core state after the proposal.
        CoreState coreState;
    }

    /// @notice Payload data emitted in the Proved event
    struct ProvedEventPayload {
        /// @notice The proposal ID that was proven.
        uint48 proposalId;
        /// @notice The transition that was proven.
        Transition transition;
        /// @notice The transition record containing additional metadata.
        TransitionRecord transitionRecord;
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

    /// @notice Emitted when bond instructions are issued
    /// @param instructions The bond instructions that need to be performed.
    event BondInstructed(LibBonds.BondInstruction[] instructions);

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Proposes new proposals of L2 blocks.
    /// @param _lookahead The data to post a new lookahead (currently unused).
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
    /// @return transitionRecordHash_ The hash of the transition record.
    function getTransitionRecordHash(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        external
        view
        returns (bytes32 transitionRecordHash_);

    /// @notice Gets the capacity for unfinalized proposals.
    /// @return The maximum number of unfinalized proposals that can exist.
    function getCapacity() external view returns (uint256);
}
