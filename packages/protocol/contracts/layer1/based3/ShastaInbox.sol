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
    uint48 public immutable extendedProvingWindow;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        IShastaInboxStore _store,
        uint48 _provabilityBond,
        uint48 _livenessBond,
        uint48 _provingWindow,
        uint48 _extendedProvingWindow
    ) {
        store = _store;
        provabilityBond = _provabilityBond;
        livenessBond = _livenessBond;
        provingWindow = _provingWindow;
        extendedProvingWindow = _extendedProvingWindow;
        store.initialize();
    }

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IShastaInbox
    function propose(BlobLocator[] memory _blobLocators) external {
        bytes32 bondCreditsHash = store.getBondCreditsHash();
        for (uint48 i; i < _blobLocators.length; ++i) {
            _propose(bondCreditsHash, _validateBlockLocator(_blobLocators[i]));
        }

        // We assume the proposer is the designated prover
        uint48 bondAmount = (provabilityBond + livenessBond) * uint48(_blobLocators.length);
        _debitBond(msg.sender, bondAmount);
    }

    /// @inheritdoc IShastaInbox
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

            ProofTiming proofTiming = block.timestamp
                < proposal.proposedBlockTimestamp + provingWindow
                ? ProofTiming.InProvingWindow
                : block.timestamp < proposal.proposedBlockTimestamp + extendedProvingWindow
                    ? ProofTiming.InExtendedProvingWindow
                    : ProofTiming.OutOfExtendedProvingWindow;

            ClaimRecord memory claimRecord = ClaimRecord({
                claim: claim,
                proposer: proposal.proposer,
                livenessBond: proposal.livenessBond,
                provabilityBond: proposal.provabilityBond,
                proofTiming: proofTiming
            });

            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
            store.setClaimRecordHash(proposal.id, claim.parentClaimHash, claimRecordHash);
            emit Proved(proposal.id, proposal, claimRecord);
        }

        bytes32 claimsHash = keccak256(abi.encode(_claims));
        verifyProof(claimsHash, _proof);
    }

    /// @inheritdoc IShastaInbox
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

            // Handle bond paymento
            (uint48 bondCredit, address receiver) = _handleBondPayment(claimRecord);
            if (bondCredit > 0) {
                store.aggregateBondCredits(receiver, bondCredit);
            }
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

    function _debitBond(address _address, uint48 _bond) internal virtual { }

    function _creditBond(address _address, uint48 _bond) internal virtual { }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a new proposal of L2 blocks
    /// @param _content The content of the proposal
    function _propose(bytes32 _bondCreditsHash, BlobSegment memory _content) private {
        uint48 proposalId = store.incrementAndGetProposalId();

        // Create a new proposal.
        // Note that the contentHash is not checked here to empty proposal data.
        uint48 proposedBlockTimestamp = uint48(block.timestamp - 128);
        uint48 proposedBlockNumber = uint48(block.number - 1);

        Proposal memory proposal = Proposal({
            id: proposalId,
            proposer: msg.sender,
            prover: msg.sender,
            provabilityBond: provabilityBond,
            livenessBond: livenessBond,
            proposedBlockTimestamp: proposedBlockTimestamp,
            proposedBlockNumber: proposedBlockNumber,
            referenceBlockHash: blockhash(proposedBlockNumber),
            // Design flaw: the current _bondCreditsHash depends on the when the prooposal is
            // proposed, it may change preconf-ed blocks.
            // We should use anchor blocks here, somehow.
            bondCreditHash: _bondCreditsHash,
            content: _content
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal));
        store.setProposalHash(proposalId, proposalHash);

        // TODO: debit provability bond from proposer and liveness bond from prover.

        emit Proposed(proposalId, proposal);
    }

    function _validateBlockLocator(BlobLocator memory _blobLocator)
        private
        view
        returns (BlobSegment memory)
    {
        if (_blobLocator.numBlobs == 0) revert InvalidBlobLocator();

        bytes32[] memory blobHashes = new bytes32[](_blobLocator.numBlobs);
        for (uint48 i; i < _blobLocator.numBlobs; ++i) {
            blobHashes[i] = blobhash(_blobLocator.blobStartIndex + i);
            if (blobHashes[i] == 0) revert BlobNotFound();
        }

        return BlobSegment({
            blobHashes: blobHashes,
            offset: _blobLocator.offset,
            size: _blobLocator.size
        });
    }

    function _handleBondPayment(ClaimRecord memory _claimRecord)
        private
        returns (uint48 l2BondCredit_, address l2BondCreditReceiver_)
    { }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ClaimNotFound();
    error BlobNotFound();
    error ProposalsAndClaimsLengthMismatch();
    error ProposalHashMismatch();
    error InvalidClaimChain();
    error InvalidBlobLocator();
}
