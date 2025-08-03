// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IShastaInbox } from "./IShastaInbox.sol";
import { IShastaInboxStore } from "./IShastaInboxStore.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaInbox is IShastaInbox {
    // TODO
    // - [x] support anchor per block
    // - [x] support prover and liveness bond
    // - [x] support provability bond
    // - [x] support batch proving
    // - [x] support multi-step finalization
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
    /// @dev msg.sender is always the proposer
    function propose(BlobLocator[] memory _blobLocators) external {
        if (!_isValidProposer(msg.sender)) revert Unauthorized();

        for (uint256 i; i < _blobLocators.length; ++i) {
            _propose(_validateBlobLocator(_blobLocators[i]));
        }
    }

    /// @inheritdoc IShastaInbox
    function prove(
        Proposal[] memory _proposals,
        Claim[] memory _claims,
        bytes calldata _proof
    )
        external
    {
        if (_proposals.length != _claims.length) revert InconsistentParams();

        for (uint256 i; i < _proposals.length; ++i) {
            Proposal memory proposal = _proposals[i];
            Claim memory claim = _claims[i];

            bytes32 proposalHash = keccak256(abi.encode(proposal));
            if (proposalHash != claim.proposalHash) revert ProposalHashMismatch1();
            if (proposalHash != store.getProposalHash(proposal.id)) revert ProposalHashMismatch2();

            ProofTiming proofTiming = block.timestamp <= proposal.timestamp + provingWindow
                ? ProofTiming.InProvingWindow
                : block.timestamp <= proposal.timestamp + extendedProvingWindow
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
            emit Proved(proposal, claimRecord);
        }

        bytes32 claimsHash = keccak256(abi.encode(_claims));
        verifyProof(claimsHash, _proof);
    }

    /// @inheritdoc IShastaInbox
    function finalize(ClaimRecord[] memory _claimRecords) external {
        bytes32 lastFinalizedClaimHash = store.getLastFinalizedClaimHash();
        uint48 proposalId = store.getLastFinalizedProposalId() + 1;
        Claim memory claim;

        for (uint256 i; i < _claimRecords.length; ++i) {
            ClaimRecord memory claimRecord = _claimRecords[i];
            claim = claimRecord.claim;

            if (claim.parentClaimHash != lastFinalizedClaimHash) revert InvalidClaimChain();

            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));

            bytes32 storedClaimRecordHash =
                store.getClaimRecordHash(proposalId, claim.parentClaimHash);

            if (storedClaimRecordHash != claimRecordHash) revert ClaimRecordHashMismatch();

            lastFinalizedClaimHash = keccak256(abi.encode(claim));

            (uint48 credit, address receiver) = _handleBondPayment(claimRecord);
            if (credit > 0) {
                store.aggregateBondCredits(proposalId, receiver, credit);
            }

            emit Finalized(proposalId, claimRecord);
            ++proposalId;
        }

        // Advance the last finalized proposal ID and update the last finalized ClaimRecord hash.
        store.setLastFinalizedProposalId(proposalId);
        store.setLastFinalizedClaimHash(lastFinalizedClaimHash);

        // TODO: for both L1 and L2, lets try not use signal service as it writes to new slots for
        // each new synced block.
        store.setLastL2BlockData(claim.endBlockNumber, claim.endBlockHash, claim.endStateRoot);
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

    function _isValidProposer(address _address) internal view virtual returns (bool) { }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a new proposal of L2 blocks
    /// @param _content The content of the proposal
    function _propose(BlobSegment memory _content) private {
        uint48 proposalId = store.incrementAndGetProposalId();

        // Create a new proposal.
        // Note that the contentHash is not checked here to empty proposal data.
        uint48 timestamp = uint48(block.timestamp - 128);
        uint48 proposedBlockNumber = uint48(block.number - 1);

        Proposal memory proposal = Proposal({
            id: proposalId,
            proposer: msg.sender,
            provabilityBond: provabilityBond,
            livenessBond: livenessBond,
            timestamp: timestamp,
            proposedBlockNumber: proposedBlockNumber,
            content: _content
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal));
        store.setProposalHash(proposalId, proposalHash);

        emit Proposed(proposal);
    }

    /// @dev Handles bond refunds and penalties based on proof timing and prover identity
    /// @param _claimRecord The claim record containing bond and timing information
    /// @return l2BondCredit_ Amount of bond to credit on L2
    /// @return l2BondCreditReceiver_ Address to receive the L2 bond credit
    function _handleBondPayment(ClaimRecord memory _claimRecord)
        private
        returns (uint48 l2BondCredit_, address l2BondCreditReceiver_)
    {
        Claim memory claim = _claimRecord.claim;
        if (_claimRecord.proofTiming == ProofTiming.InProvingWindow) {
            // Proof submitted within the designated proving window (on-time proof)
            // The designated prover successfully proved the block on time

            if (claim.designatedProver != _claimRecord.proposer) {
                // Proposer and designated prover are different entities
                // The designated prover paid a liveness bond on L2 that needs to be refunded
                l2BondCredit_ = _claimRecord.livenessBond;
                l2BondCreditReceiver_ = claim.designatedProver;
            }
        } else if (_claimRecord.proofTiming == ProofTiming.InExtendedProvingWindow) {
            // Proof submitted during extended window (late but acceptable proof)
            // The designated prover failed to prove on time, but another prover stepped in
            if (claim.designatedProver == _claimRecord.proposer) {
                // Proposer was also the designated prover who failed to prove on time
                // Forfeit their liveness bond but reward the actual prover with half
                _debitBond(_claimRecord.proposer, _claimRecord.livenessBond);
                _creditBond(claim.actualProver, _claimRecord.livenessBond / 2);
            } else {
                // Proposer and designated prover are different entities
                // Reward the actual prover with half of the liveness bond on L2
                l2BondCredit_ = _claimRecord.livenessBond / 2;
                l2BondCreditReceiver_ = claim.actualProver;
            }
        } else {
            // Proof submitted after extended window (very late proof)
            // Block was difficult to prove, forfeit provability bond but reward prover

            // Forfeit proposer's provability bond but give half to the actual prover
            _debitBond(_claimRecord.proposer, _claimRecord.provabilityBond);
            _creditBond(claim.actualProver, _claimRecord.provabilityBond / 2);

            if (claim.designatedProver != _claimRecord.proposer) {
                // Proposer and designated prover are different entities
                // Refund the designated prover's L2 liveness bond
                l2BondCredit_ = _claimRecord.livenessBond;
                l2BondCreditReceiver_ = claim.designatedProver;
            }
        }
    }

    function _validateBlobLocator(BlobLocator memory _blobLocator)
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

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error BlobNotFound();
    error InconsistentParams();
    error ProposalHashMismatch1();
    error ProposalHashMismatch2();
    error ClaimRecordHashMismatch();
    error InvalidClaimChain();
    error InvalidBlobLocator();
    error Unauthorized();
}
