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
    uint48 public immutable provabilityBond;
    uint48 public immutable livenessBond;
    uint48 public immutable provingWindow;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        IShastaInboxStore _store,
        uint48 _provabilityBond,
        uint48 _livenessBond,
        uint48 _provingWindow
    ) {
        store = _store;
        provabilityBond = _provabilityBond;
        livenessBond = _livenessBond;
        provingWindow = _provingWindow;

        store.initialize();
    }

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a new proposal of L2 blocks
    /// @param _blobStartIndex The index of the first blob in the current transaction
    /// @param _numBlobs The number of blobs in the proposal
    /// @param _offset The offset of the proposal's content in the containing blobs
    /// @param _size The size of the proposal's content in the containing blobs
    function propose(
        uint48 _blobStartIndex,
        uint32 _numBlobs,
        uint32 _offset,
        uint32 _size
    )
        external
    {
        bytes32[] memory blobHashes = new bytes32[](_numBlobs);
        for (uint48 i; i < _numBlobs; ++i) {
            blobHashes[i] = blobhash(_blobStartIndex + i);
            if (blobHashes[i] == 0) revert BlobNotFound();
        }

        BlobSegment memory content =
            BlobSegment({ blobHashes: blobHashes, offset: _offset, size: _size });

        _propose(content);
    }

    /// @notice Proves a claim about some properties of a proposal, including its state transition.
    /// @param _proposals Original proposal data
    /// @param _claims State transition claims being proven
    /// @param _proof Validity proof for the claim
    function prove(
        Proposal[] memory _proposals,
        Claim[] memory _claims,
        bytes calldata _proof
    )
        external
    {
        if (_proposals.length != _claims.length) revert ProposalsAndClaimsLengthMismatch();

        for (uint48 i; i < _proposals.length; ++i) {
            Proposal memory proposal = _proposals[i];
            Claim memory claim = _claims[i];

            bytes32 proposalHash = keccak256(abi.encode(proposal));
            if (proposalHash != claim.proposalHash) revert ProposalHashMismatch();
            if (proposalHash != store.getProposalHash(proposal.id)) revert ProposalHashMismatch();

            ClaimRecord memory claimRecord = ClaimRecord({
                claim: claim,
                proposedAt: proposal.proposedAt,
                provedAt: uint48(block.timestamp)
            });

            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
            store.setClaimRecordHash(proposal.id, claim.parentClaimHash, claimRecordHash);
            emit Proved(proposal.id, proposal, claimRecord);
        }

        bytes32 claimsHash = keccak256(abi.encode(_claims));
        verifyProof(claimsHash, _proof);
    }

    /// @notice Finalizes verifiable claims and updates the L2 chain state
    /// @param _claimRecords The proven claims to finalize
    function finalize(ClaimRecord[] memory _claimRecords) external {
        bytes32 lastFinalizedClaimHash = store.getLastFinalizedClaimHash();
        uint48 proposalId = store.getLastFinalizedProposalId() + 1;
        Claim memory claim;

        for (uint48 i; i < _claimRecords.length; ++i) {
            ClaimRecord memory claimRecord = _claimRecords[i];
            claim = claimRecord.claim;
            if (claim.parentClaimHash != lastFinalizedClaimHash) {
                revert InvalidClaimChain();
            }

            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));

            bytes32 storedClaimRecordHash =
                store.getClaimRecordHash(proposalId, claim.parentClaimHash);
            if (storedClaimRecordHash != claimRecordHash) revert ClaimNotFound();

            lastFinalizedClaimHash = keccak256(abi.encode(claim));
            proposalId++;
        }

        // Advance the last finalized proposal ID and update the last finalized ClaimRecord hash.
        store.setLastFinalizedProposalId(proposalId);

        // Sync L2 block data to L1
        // TODO: use signal service
        store.setLastL2BlockData(claim.endL2BlockNumber, claim.endL2BlockHash, claim.endL2StateRoot);

        emit Finalized(proposalId, claim);
    }

    // -------------------------------------------------------------------------
    // Internal Functions - Abstract
    // -------------------------------------------------------------------------

    /// @dev Verifies a validity proof for a state transition. This function must revert if the
    /// proof is invalid.
    /// @param _claimsHash The hash of the claims to verify
    /// @param _proof The proof for the claims
    function verifyProof(bytes32 _claimsHash, bytes calldata _proof) internal virtual;

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a new proposal of L2 blocks
    /// @param _content The content of the proposal
    function _propose(BlobSegment memory _content) private {
        uint48 proposalId = store.incrementAndGetProposalId();

        // Create a new proposal.
        // Note that the contentHash is not checked here to empty proposal data.
        Proposal memory proposal = Proposal({
            id: proposalId,
            proposer: msg.sender,
            prover: msg.sender,
            provabilityBond: provabilityBond,
            livenessBond: livenessBond,
            proposedAt: uint48(block.timestamp),
            referenceBlockHash: blockhash(block.number - 1),
            content: _content
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal));
        store.setProposalHash(proposalId, proposalHash);

        // TODO: debit provability bond from proposer and liveness bond from prover.

        emit Proposed(proposalId, proposal);
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ClaimNotFound();
    error BlobNotFound();
    error ProposalsAndClaimsLengthMismatch();
    error ProposalHashMismatch();
    error InvalidClaimChain();
}
