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

        // Create a new proposal.
        // Note that the blobDataHash is not checked here to empty proposal without data.
        Proposal memory proposal = Proposal({
            proposer: msg.sender,
            proposedAt: uint48(block.timestamp),
            id: proposalId,
            latestL1BlockHash: blockhash(block.number - 1),
            blobDataHash: blobhash(_blobIndex)
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal));
        store.setProposalHash(proposalId, proposalHash);

        emit Proposed(proposalId, proposal);
    }

    /// @notice Submits a proof for a proposal's state transition
    /// @param _proposal Original proposal data
    /// @param _claim State transition claim being proven
    /// @param _proof Validity proof for the state transition
    function prove(
        Proposal memory _proposal,
        Claim memory _claim,
        bytes calldata _proof
    )
        external
    {
        bytes32 proposalHash = keccak256(abi.encode(_proposal));
        if (proposalHash != _claim.proposalHash) revert ProposalHashMismatch();
        if (proposalHash != store.getProposalHash(_proposal.id)) revert ProposalHashMismatch();

        ClaimRecord memory record = ClaimRecord({
            claim: _claim,
            proposedAt: _proposal.proposedAt,
            provedAt: uint48(block.timestamp)
        });

        bytes32 recordHash = keccak256(abi.encode(record));
        store.setClaimRecordHash(_proposal.id, _claim.parentClaimHash, recordHash);
        emit Proved(_proposal.id, _proposal, _claim);

        verifyProof(_claim, _proof);
    }

    /// @notice Finalizes the next verifiable proposal and updates the L2 chain state
    /// @param _record The proven claim to finalize
    function finalize(ClaimRecord memory _record) external {
        Claim memory claim = _record.claim;

        if (claim.parentClaimHash != store.getLastFinalizedClaimHash()) {
            revert InvalidClaimChain();
        }

        uint48 proposalId = store.getLastFinalizedProposalId() + 1;
        bytes32 recordHash = keccak256(abi.encode(_record));

        bytes32 storedRecordHash = store.getClaimRecordHash(proposalId, claim.parentClaimHash);
        if (storedRecordHash != recordHash) revert ClaimNotFound();

        // Advance the last finalized proposal ID and update the last finalized ClaimRecord hash.
        store.setLastFinalized(proposalId, recordHash);

        // Sync L2 block data to L1
        store.setLastL2BlockData(claim.endL2BlockNumber, claim.endL2BlockHash, claim.endL2StateRoot);

        // Instruct L2 block builder to refund bond to the designated prover or the actual prover.
        L2BondPayment memory refund = _calculateBondPayment(_record);

        // Aggregate the refund with all historical refunds instructions to a verifiable hash.
        store.aggregateL2BondPayment(keccak256(abi.encode(refund)));

        emit Finalized(proposalId, claim, refund);
    }

    // -------------------------------------------------------------------------
    // Internal Functions - Abstract
    // -------------------------------------------------------------------------

    /// @dev Verifies a validity proof for a state transition. This function must revert if the
    /// proof is invalid.
    /// @param _claim The claim to verify
    /// @param _proof The proof for the claim
    function verifyProof(Claim memory _claim, bytes calldata _proof) internal virtual;

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    function _calculateBondPayment(ClaimRecord memory _record)
        private
        view
        returns (L2BondPayment memory refund_)
    {
        bool provedWithinLivenessWindow = _record.provedAt <= _record.proposedAt + provingWindow;

        if (provedWithinLivenessWindow) {
            refund_.recipient = _record.claim.designatedProver;
            refund_.refundAmount = _record.claim.proverBond;
        } else {
            refund_.recipient = _record.claim.actualProver;
            refund_.refundAmount = _record.claim.proverBond / 2;
        }

        refund_.timestamp = uint48(block.timestamp);
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ProposalHashMismatch();
    error InvalidClaimChain();
    error ClaimNotFound();
}
