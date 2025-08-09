// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBondOperation } from "contracts/shared/shasta/libs/LibBondOperation.sol";

/// @title IInbox
/// @notice Interface for the ShastaInbox contract
/// @custom:security-contact security@taiko.xyz
interface IInbox {
    /// @notice Represents a proposal for L2 blocks.
    struct Proposal {
        /// @notice Unique identifier for the proposal.
        uint48 id;
        /// @notice Address of the proposer.
        address proposer;
        /// @notice Provability bond for the proposal.
        uint48 provabilityBondGwei;
        /// @notice Liveness bond for the proposal, paid by the designated prover.
        uint48 livenessBondGwei;
        /// @notice The L1 block timestamp when the proposal was accepted.
        uint48 originTimestamp;
        /// @notice The L1 block number when the proposal was accepted.
        uint48 originBlockNumber;
        /// @notice Whether the proposal is from a forced inclusion.
        bool isForcedInclusion;
        /// @notice The proposal's chunk.
        LibBlobs.BlobSlice blobSlice;
    }

    /// @notice Represents the bond decision based on proof submission timing and prover identity.
    /// @dev Bond decisions determine how provability and liveness bonds are distributed based on
    /// whether proofs are submitted on time and by the correct party.
    enum BondDecision {
        NoOp,
        L1SlashLivenessRewardProver,
        L1SlashProvabilityRewardProver,
        L2SlashLivenessRewardProver
    }

    /// @notice Represents a claim about the state transition of a proposal.
    struct Claim {
        /// @notice The proposal's hash.
        bytes32 proposalHash;
        /// @notice The parent claim's hash, this is used to link the claim to its parent claim to
        /// finalize the corresponding proposal.
        bytes32 parentClaimHash;
        /// @notice The block number for the end (last) L2 block in this proposal.
        uint48 endBlockNumber;
        /// @notice The block hash for the end (last) L2 block in this proposal.
        bytes32 endBlockHash;
        /// @notice The state root for the end (last) L2 block in this proposal.
        bytes32 endStateRoot;
        /// @notice The designated prover.
        address designatedProver;
        /// @notice The actual prover.
        address actualProver;
    }

    /// @notice Represents a record of a claim with additional metadata.
    struct ClaimRecord {
        /// @notice The claim.
        Claim claim;
        /// @notice The proposer, copied from the proposal.
        address proposer;
        /// @notice The liveness bond, copied from the proposal.
        uint48 livenessBondGwei;
        /// @notice The provability bond, copied from the proposal.
        uint48 provabilityBondGwei;
        /// @notice The next proposal ID.
        uint48 nextProposalId;
        /// @notice The proof timing.
        BondDecision bondDecision;
    }

    /// @notice Represents the core state of the inbox.
    struct CoreState {
        /// @notice The next proposal ID to be assigned.
        uint48 nextProposalId;
        /// @notice The ID of the last finalized proposal.
        uint48 lastFinalizedProposalId;
        /// @notice The hash of the last finalized claim.
        bytes32 lastFinalizedClaimHash;
        /// @notice The hash of all bond operations.
        bytes32 bondOperationsHash;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new proposal is proposed.
    /// @param proposal The proposal that was proposed.
    event Proposed(Proposal proposal, CoreState coreState);

    /// @notice Emitted when a proof is submitted for a proposal.
    /// @param proposal The proposal that was proven.
    /// @param claimRecord The claim record containing the proof details.
    event Proved(Proposal proposal, ClaimRecord claimRecord);

    /// @notice Emitted when a bond operation is instructed
    /// @param bondOperation The bond operation that needs to be performed.
    event BondRequest(LibBondOperation.BondOperation bondOperation);

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Proposes new proposals of L2 blocks.
    /// @param _lookahead The data to post a new lookahead (currently unused).
    /// @param _data The data containing the core state, blob locator, and claim records.
    function propose(bytes calldata _lookahead, bytes calldata _data) external;

    /// @notice Proves a claim about some properties of a proposal, including its state transition.
    /// @param _data The data containing the proposals and claims to be proven.
    /// @param _proof Validity proof for the claims.
    function prove(bytes calldata _data, bytes calldata _proof) external;
}
