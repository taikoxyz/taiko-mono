// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IShastaInbox } from "./IShastaInbox.sol";
import { IShastaInboxStore } from "./IShastaInboxStore.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaInbox is IShastaInbox {
    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    IShastaInboxStore public immutable store;
    uint48 public immutable provingWindow;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(IShastaInboxStore _store, uint48 _provingWindow) {
        store = _store;
        provingWindow = _provingWindow;
        store.initialize();
    }

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a new proposal of L2 blocks
    /// @param _blobIndex Index of the blob in the current transaction
    function propose(uint48 _blobIndex) external {
        uint48 proposalId = store.incrementAndGetProposalId();
        Proposal memory proposal = Proposal({
            proposer: msg.sender,
            proposedAt: uint48(block.timestamp),
            id: proposalId,
            latestL1BlockHash: blockhash(block.number - 1),
            blobDataHash: blobhash(_blobIndex)
        });

        if (proposal.blobDataHash == 0) revert InvalidBlobData();
        bytes32 proposalHash = keccak256(abi.encode(proposal));
        store.setProposalHash(proposalId, proposalHash);

        emit Proposed(proposalId, proposal);
    }

    /// @notice Submits a proof for a proposal's state transition
    /// @param _proposal Original proposal data
    /// @param _claim State transition claim being proven
    /// @param _proof Validity proof for the state transition
    function prove(
        uint48 _proposalId,
        Proposal memory _proposal,
        Claim memory _claim,
        bytes calldata _proof
    )
        external
    {
        bytes32 proposalHash = keccak256(abi.encode(_proposal));
        if (proposalHash != _claim.proposalHash) revert ProposalHashMismatch();
        if (proposalHash != store.getProposalHash(_proposalId)) revert ProposalHashMismatch();

        ClaimRecord memory record = ClaimRecord({
            claim: _claim,
            proposedAt: _proposal.proposedAt,
            provedAt: uint48(block.timestamp)
        });

        bytes32 recordHash = keccak256(abi.encode(record));
        store.setClaimRecordHash(_proposal.id, _claim.parentClaimRecordHash, recordHash);
        emit Proved(_proposal.id, _proposal, _claim);

        verifyProof(recordHash, _proof);
    }

    /// @notice Finalizes a proven proposal and updates the L2 chain state
    /// @param _record The proven claim to finalize
    function finalize(ClaimRecord memory _record) external {
        Claim memory claim = _record.claim;

        if (claim.parentClaimRecordHash != store.getLastFinalizedClaimHash()) {
            revert InvalidClaimChain();
        }

        uint48 proposalId = store.getLastFinalizedProposalId() + 1;
        bytes32 recordHash = keccak256(abi.encode(_record));

        if (recordHash != store.getClaimRecordHash(proposalId, claim.parentClaimRecordHash)) {
            revert ClaimNotFound();
        }

        // Advance the last finalized proposal ID and update the last finalized ClaimRecord hash.
        store.setLastFinalized(proposalId, recordHash);

        // Sync L2 block data to L1
        store.setLastL2BlockData(claim.endL2BlockNumber, claim.endL2BlockHash, claim.endL2StateRoot);

        // Instruct L2 block builder to refund bond to the designated prover or the actual prover.
        L2ProverBondPayment memory refund = _calculateBondRefund(proposalId, _record);
        bytes32 currentBondRefundsHash = store.getL2BondRefundHash();
        store.setL2BondRefundsHash(keccak256(abi.encode(currentBondRefundsHash, refund)));

        emit Finalized(proposalId, claim, refund);
    }

    // -------------------------------------------------------------------------
    // Internal Functions - Abstract
    // -------------------------------------------------------------------------

    /// @dev Verifies a validity proof for a state transition
    function verifyProof(bytes32 _claimHash, bytes calldata _proof) internal virtual;

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    function _calculateBondRefund(
        uint48 _proposalId,
        ClaimRecord memory _record
    )
        private
        view
        returns (L2ProverBondPayment memory refund_)
    {
        bool provedWithinLivenessWindow = _record.provedAt < _record.proposedAt + provingWindow;
        refund_ = provedWithinLivenessWindow
            ? L2ProverBondPayment({
                recipient: _record.claim.designatedProver,
                proposalId: _proposalId,
                refundAmount: _record.claim.proverBond
            })
            : L2ProverBondPayment({
                recipient: _record.claim.actualProver,
                proposalId: _proposalId,
                refundAmount: _record.claim.proverBond / 2
            });
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error InvalidBlobData();
    error ProposalHashMismatch();
    error InvalidClaimChain();
    error ClaimNotFound();
}
