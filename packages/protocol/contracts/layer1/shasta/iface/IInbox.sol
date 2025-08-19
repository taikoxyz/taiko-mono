// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

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
        address syncedBlockManager;
        address proofVerifier;
        address proposerChecker;
        address forcedInclusionStore;
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
        /// @notice Address of the proposer.
        address proposer;
        /// @notice The L1 block timestamp when the proposal was accepted.
        uint48 timestamp;
        /// @notice The current hash of coreState
        bytes32 coreStateHash;
        /// @notice Hash of the Derivation struct containing additional proposal data.
        bytes32 derivationHash;
    }

    struct BlockMiniHeader {
        uint48 number;
        /// @notice The block hash for the end (last) L2 block in this proposal.
        bytes32 hash;
        /// @notice The state root for the end (last) L2 block in this proposal.
        bytes32 stateRoot;
    }

    /// @notice Represents a claim about the state transition of a proposal.
    struct Claim {
        /// @notice The proposal's hash.
        bytes32 proposalHash;
        /// @notice The parent claim's hash, this is used to link the claim to its parent claim to
        /// finalize the corresponding proposal.
        bytes32 parentClaimHash;
        /// @notice The end block header containing number, hash, and state root.
        BlockMiniHeader endBlockMiniHeader;
        /// @notice The designated prover.
        address designatedProver;
        /// @notice The actual prover.
        address actualProver;
    }

    /// @notice Represents a record of a claim with additional metadata.
    struct ClaimRecord {
        /// @notice The span indicating how many proposals this claim record covers.
        uint8 span;
        /// @notice The bond instructions.
        LibBonds.BondInstruction[] bondInstructions;
        /// @notice The parent claim's hash, this is used to link the claim to its parent claim to
        /// finalize the corresponding proposal.
        bytes32 parentClaimHash; // TODO (danielw) REMOVE
        /// @notice The claim's hash
        bytes32 claimHash;
        /// @notice The hash of the end block mini header.
        bytes32 endBlockMiniHeaderHash;
    }

    /// @notice Represents the core state of the inbox.
    struct CoreState {
        /// @notice The next proposal ID to be assigned.
        uint48 nextProposalId;
        /// @notice The ID of the last finalized proposal.
        uint48 lastFinalizedProposalId;
        /// @notice The hash of the last finalized claim.
        bytes32 lastFinalizedClaimHash;
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
        /// @notice Array of claim records for finalization.
        ClaimRecord[] claimRecords;
        /// @notice The end block mini header for finalization.
        BlockMiniHeader endBlockMiniHeader;
    }

    /// @notice Input data for the prove function
    struct ProveInput {
        /// @notice Array of proposals to prove.
        Proposal[] proposals;
        /// @notice Array of claims containing proof details.
        Claim[] claims;
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
        /// @notice The claim that was proven.
        Claim claim;
        /// @notice The claim record containing additional metadata.
        ClaimRecord claimRecord;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed.
    /// @param data The encoded (Proposal, Derivation, CoreState)
    event Proposed(bytes data);

    /// @notice Emitted when a proof is submitted
    /// @param data The encoded (ClaimRecord, BlockMiniHeader)
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

    /// @notice Proves a claim about some properties of a proposal, including its state transition.
    /// @param _data The encoded ProveInput struct.
    /// @param _proof Validity proof for the claims.
    function prove(bytes calldata _data, bytes calldata _proof) external;

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @notice Returns the proposal hash for a given proposal ID.
    /// @param _proposalId The proposal ID to look up.
    /// @return proposalHash_ The hash stored at the proposal's ring buffer slot.
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_);

    /// @notice Returns the claim record hash for a given proposal ID and parent claim hash.
    /// @param _proposalId The proposal ID.
    /// @param _parentClaimHash The parent claim hash.
    /// @return claimRecordHash_ The hash of the claim record.
    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        external
        view
        returns (bytes32 claimRecordHash_);

    /// @notice Gets the capacity for unfinalized proposals.
    /// @return The maximum number of unfinalized proposals that can exist.
    function getCapacity() external view returns (uint256);
}
