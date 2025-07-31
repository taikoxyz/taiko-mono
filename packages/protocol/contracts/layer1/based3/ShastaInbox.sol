// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IShastaInbox } from "./IShastaInbox.sol";
import { IShastaInboxStore } from "./IShastaInboxStore.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaInbox is IShastaInbox {
    // TODO
    // - [ ] support anchor per block
    // - [ ] support prover and liveness bond
    // - [ ] support provability bond
    // - [ ] support batch proving
    // - [ ] support multi-step finalization
    // - [ ] support Summary approach

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    IShastaInboxStore public immutable store;
    uint48 public immutable provingWindow;
    uint48 public immutable livenessBond;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(IShastaInboxStore _store, uint48 _provingWindow, uint48 _livenessBond) {
        store = _store;
        provingWindow = _provingWindow;
        livenessBond = _livenessBond;
        store.initialize();
    }

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a new proposal of L2 blocks
    /// @param _blobIndices Array of blob indices in the current transaction
    function propose(uint256[] calldata _blobIndices) external {
        uint48 proposalId = store.incrementAndGetProposalId();
        bytes32[] memory blobHashes = _getBlobHashes(_blobIndices);

        // Create a new proposal.
        Proposal memory proposal = Proposal({
            proposer: msg.sender,
            prover: msg.sender,
            livenessBond: livenessBond,
            proposedAt: uint48(block.timestamp),
            id: proposalId,
            referenceL1BlockHash: blockhash(block.number - 1),
            blobDataHashes: blobHashes
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
        store.setLastFinalizedProposalId(proposalId);

        // Sync L2 block data to L1
        store.setLastL2BlockData(claim.endL2BlockNumber, claim.endL2BlockHash, claim.endL2StateRoot);

        emit Finalized(proposalId, claim);
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

    function _getBlobHashes(uint256[] calldata blobIndices)
        private
        view
        returns (bytes32[] memory)
    {
        if (blobIndices.length == 0) revert NoBlobsProvided();

        bytes32[] memory blobhashes = new bytes32[](blobIndices.length);
        for (uint256 i; i < blobIndices.length; ++i) {
            blobhashes[i] = blobhash(blobIndices[i]);
            if (blobhashes[i] == bytes32(0)) revert InvalidBlobHash();
        }

        return blobhashes;
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ClaimNotFound();
    error ProposalHashMismatch();
    error InvalidClaimChain();
    error NoBlobsProvided();
    error InvalidBlobHash();
}
