// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../lib/LibBlobs.sol";

/// @title IInbox
/// @notice Interface for the Shasta Inbox contract that manages L2 block proposals and proofs
/// @dev Implements a based rollup architecture with contestable validity proofs
/// @custom:security-contact security@taiko.xyz
interface IInbox {
    /// @notice Represents a proposal for a batch of L2 blocks
    /// @dev Proposals contain block data and metadata needed for proving and finalization
    struct Proposal {
        /// @notice Unique sequential identifier for the proposal
        uint48 id;
        /// @notice Address that submitted the proposal and posted bonds
        address proposer;
        /// @notice Bond amount in gwei ensuring the proposal can be proven
        /// @dev Slashed if the proposal cannot be proven within the extended window
        uint48 provabilityBondGwei;
        /// @notice Bond amount in gwei ensuring timely proof submission
        /// @dev Slashed if the designated prover fails to prove within the proving window
        uint48 livenessBondGwei;
        /// @notice L1 timestamp when the proposal was submitted
        /// @dev Used to calculate proving windows and validate L2 block timestamps
        uint48 originTimestamp;
        /// @notice L1 block number when the proposal was submitted
        /// @dev Used as the anchor block for L2 blocks in this proposal
        uint48 originBlockNumber;
        /// @notice Flag indicating if this proposal contains forced transactions
        bool isForcedInclusion;
        /// @notice Blob data frame containing the compressed L2 block data
        LibBlobs.BlobFrame frame;
    }

    /// @notice Bond decision based on proof submission timing and prover identity
    /// @dev Determines bond distribution: refunds, rewards, or slashing
    /// Aggregatable decisions allow gas-efficient batch processing
    enum BondDecision {
        /// @dev No bond operation needed (proposer proved on time)
        NoOp,
        /// @dev Refund liveness bond to designated prover on L2 (different from proposer)
        L2RefundLiveness,
        /// @dev Reward actual prover with portion of liveness bond on L2
        L2RewardProver,
        /// @dev Slash proposer's liveness bond and reward actual prover on L1
        L1SlashLivenessRewardProver,
        /// @dev Slash provability bond, reward prover, and refund L2 liveness bond
        L1SlashProvabilityRewardProverL2RefundLiveness,
        /// @dev Slash provability bond and reward actual prover on L1
        L1SlashProvabilityRewardProver
    }

    /// @notice Claim asserting the state transition result of a proposal
    /// @dev Claims form a chain linking proposals through parent-child relationships
    struct Claim {
        /// @notice Hash of the proposal being proven
        bytes32 proposalHash;
        /// @notice Hash of the parent claim to maintain chain continuity
        /// @dev Must match the last finalized claim hash for the claim to be finalizable
        bytes32 parentClaimHash;
        /// @notice Final L2 block number in this proposal batch
        uint48 endBlockNumber;
        /// @notice Hash of the final L2 block in this proposal batch
        bytes32 endBlockHash;
        /// @notice State root after executing all blocks in this proposal
        bytes32 endStateRoot;
        /// @notice Address assigned to prove this proposal (may differ from proposer)
        address designatedProver;
        /// @notice Address that actually submitted the proof
        address actualProver;
    }

    /// @notice Extended claim data with metadata for finalization and bond processing
    /// @dev May represent aggregated claims for gas efficiency
    struct ClaimRecord {
        /// @notice The claim data including state transition results
        Claim claim;
        /// @notice Original proposer address for bond operations
        address proposer;
        /// @notice Liveness bond amount (may be aggregated across multiple proposals)
        uint48 livenessBondGwei;
        /// @notice Provability bond amount from the proposal
        uint48 provabilityBondGwei;
        /// @notice ID of the next proposal (for aggregation tracking)
        uint48 nextProposalId;
        /// @notice Bond decision determining refunds, rewards, or slashing
        BondDecision bondDecision;
    }

    /// @notice Core state tracking proposal progression and finalization
    /// @dev Hashed and stored on-chain to ensure state consistency
    struct CoreState {
        /// @notice Next sequential ID to assign to new proposals
        uint48 nextProposalId;
        /// @notice Most recent proposal that has been finalized
        uint48 lastFinalizedProposalId;
        /// @notice Hash of the claim for the last finalized proposal
        /// @dev New claims must chain from this hash to be finalizable
        bytes32 lastFinalizedClaimHash;
        /// @notice Aggregated hash of all bond operations for verification
        bytes32 bondOperationAggregationHash;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a new proposal is submitted
    /// @param proposal The submitted proposal containing L2 block data
    /// @param coreState Updated core state after proposal submission
    event Proposed(Proposal proposal, CoreState coreState);

    /// @notice Emitted when a proof is submitted for a proposal
    /// @param proposal The proposal that was proven
    /// @param claimRecord Claim record with proof details and bond decision
    event Proved(Proposal proposal, ClaimRecord claimRecord);

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @notice Submits a new proposal containing L2 block data
    /// @dev Handles forced inclusions, validates state, and may finalize previous proposals
    /// @param _lookahead Reserved for future lookahead mechanism (currently unused)
    /// @param _data Encoded data containing:
    ///   - CoreState: Current state for validation
    ///   - BlobLocator: Reference to blob data
    ///   - ClaimRecord[]: Claims for finalization
    function propose(bytes calldata _lookahead, bytes calldata _data) external;

    /// @notice Submits proofs for one or more proposals
    /// @dev Proofs can be aggregated for gas efficiency when conditions allow
    /// @param _data Encoded array of proposals and corresponding claims
    /// @param _proof Aggregated validity proof covering all claims
    function prove(bytes calldata _data, bytes calldata _proof) external;
}
