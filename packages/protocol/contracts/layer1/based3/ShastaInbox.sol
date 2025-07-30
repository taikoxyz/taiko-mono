// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IShastaInbox } from "./IShastaInbox.sol";
import { ShastaInboxState } from "./ShastaInboxState.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaInbox is IShastaInbox {
    using ShastaInboxState for ShastaInboxState.State;

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    ShastaInboxState.State private state;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() {
        state.initialize();
    }

    // -------------------------------------------------------------------------
    // Public View Functions
    // -------------------------------------------------------------------------

    function nextProposalId() public view returns (uint48) {
        return state.getNextProposalId();
    }

    function lastFinalizedProposalId() public view returns (uint48) {
        return state.getLastFinalizedProposalId();
    }

    function lastFinalizedClaimHash() public view returns (bytes32) {
        return state.getLastFinalizedClaimHash();
    }

    function lastL2BlockNumber() public view returns (uint48) {
        return state.getLastL2BlockNumber();
    }

    function lastL2BlockHash() public view returns (bytes32) {
        return state.getLastL2BlockHash();
    }

    function lastL2StateRoot() public view returns (bytes32) {
        return state.getLastL2StateRoot();
    }

    function bondRefundsHash() public view returns (bytes32) {
        return state.getBondRefundsHash();
    }

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a new proposal of L2 blocks
    /// @param blobIndex Index of the blob in the current transaction
    function propose(uint48 blobIndex) external {
        uint48 proposalId = state.incrementAndGetProposalId();
        Proposal memory proposal = Proposal({
            proposer: msg.sender,
            proposedAt: uint48(block.timestamp),
            latestL1BlockHash: blockhash(block.number - 1),
            blobDataHash: blobhash(blobIndex)
        });

        if (proposal.blobDataHash == 0) revert InvalidBlobData();
        bytes32 proposalHash = keccak256(abi.encode(proposal));
        state.setProposalHash(proposalId, proposalHash);

        emit Proposed(proposalId, proposal);
    }

    /// @notice Submits a proof for a proposal's state transition
    /// @param proposalId ID of the proposal being proven
    /// @param proposal Original proposal data
    /// @param claim State transition claim being proven
    /// @param proof Validity proof for the state transition
    function prove(
        uint48 proposalId,
        Proposal memory proposal,
        Claim memory claim,
        bytes calldata proof
    )
        external
    {
        bytes32 proposalHash = keccak256(abi.encode(proposal));
        if (proposalHash != claim.proposalHash) revert ProposalHashMismatchWithClaim();
        if (proposalHash != state.getProposalHash(proposalId)) {
            revert ProposalHashMismatchWithSavedHash();
        }

        ClaimRecord memory record = ClaimRecord({
            claim: claim,
            proposedAt: proposal.proposedAt,
            provedAt: uint48(block.timestamp)
        });

        bytes32 recordHash = keccak256(abi.encode(record));
        state.setClaimRecordHash(proposalId, claim.parentClaimHash, recordHash);

        emit Proved(proposalId, proposal, claim);

        verifyProof(recordHash, proof);
    }

    /// @notice Finalizes a proven proposal and updates the L2 chain state
    /// @param record The proven claim to finalize
    function finalize(ClaimRecord memory record) external {
        Claim memory claim = record.claim;

        bytes32 lastFinalizedClaimHash_ = state.getLastFinalizedClaimHash();
        if (claim.parentClaimHash != lastFinalizedClaimHash_) {
            revert InvalidClaimChain();
        }

        uint48 proposalId = state.getLastFinalizedProposalId() + 1;
        bytes32 recordHash = keccak256(abi.encode(record));

        bytes32 storedRecordHash = state.getClaimRecordHash(proposalId, lastFinalizedClaimHash_);
        if (storedRecordHash != recordHash) {
            revert ClaimNotFoundInTree();
        }

        state.setLastFinalized(proposalId, recordHash);
        state.setLastL2BlockData(
            claim.endL2BlockNumber, claim.endL2BlockHash, claim.endL2StateRoot
        );

        L2ProverBondPayment memory refund = calculateBondRefund(proposalId, record);
        bytes32 currentBondRefundsHash = state.getBondRefundsHash();
        state.setBondRefundsHash(keccak256(abi.encode(currentBondRefundsHash, refund)));

        emit Finalized(proposalId, claim, refund);
    }

    // -------------------------------------------------------------------------
    // Internal Functions - Bond Management
    // -------------------------------------------------------------------------

    function calculateBondRefund(
        uint48 proposalId,
        ClaimRecord memory record
    )
        internal
        pure
        returns (L2ProverBondPayment memory)
    {
        bool provedWithinLivenessWindow = record.provedAt < record.proposedAt + 1 hours;
        return provedWithinLivenessWindow
            ? L2ProverBondPayment({
                recipient: record.claim.designatedProver,
                proposalId: proposalId,
                refundAmount: record.claim.proverBond
            })
            : L2ProverBondPayment({
                recipient: record.claim.actualProver,
                proposalId: proposalId,
                refundAmount: record.claim.proverBond / 2
            });
    }

    // -------------------------------------------------------------------------
    // Internal Functions - Abstract
    // -------------------------------------------------------------------------

    /// @dev Verifies a validity proof for a state transition
    function verifyProof(bytes32 claimHash, bytes calldata proof) internal virtual;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error InvalidBlobData();
    error ProposalHashMismatchWithClaim();
    error ProposalHashMismatchWithSavedHash();
    error InvalidClaimChain();
    error ClaimNotFoundInTree();
}
