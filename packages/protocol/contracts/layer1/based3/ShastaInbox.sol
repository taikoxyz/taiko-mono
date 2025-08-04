// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IShastaInbox } from "./IShastaInbox.sol";
import { LibState } from "./LibState.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture.
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaInbox is IShastaInbox {
    // TODO
    // - [x] support anchor per block
    // - [x] support prover and liveness bond
    // - [x] support provability bond
    // - [x] support batch proving
    // - [x] support multi-step finalization
    // - [ ] support Summary approach
    // - [ ] if no anchor block find, default to empty content.

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    /// @notice The complete protocol state.
    State private state;

    uint48 public immutable provabilityBond;
    uint48 public immutable livenessBond;
    uint48 public immutable provingWindow;
    uint48 public immutable extendedProvingWindow;
    uint256 public immutable minBondBalance;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        uint48 _provabilityBond,
        uint48 _livenessBond,
        uint48 _provingWindow,
        uint48 _extendedProvingWindow,
        uint256 _minBondBalance
    ) {
        provabilityBond = _provabilityBond;
        livenessBond = _livenessBond;
        provingWindow = _provingWindow;
        extendedProvingWindow = _extendedProvingWindow;
        minBondBalance = _minBondBalance;

        LibState.initialize(state);
    }

    // -------------------------------------------------------------------------
    // External Transactional Functions
    // -------------------------------------------------------------------------

    /// @dev msg.sender is always the proposer.
    function propose(bytes calldata _data) external {
        (
            CoreState memory coreState,
            BlobLocator[] memory blobLocators,
            ClaimRecord[] memory claimRecords
        ) = abi.decode(_data, (CoreState, BlobLocator[], ClaimRecord[]));

        if (!_isValidProposer(msg.sender)) revert Unauthorized();
        if (_getBondBalance(msg.sender) < minBondBalance) revert InsufficientBond();
        if (keccak256(abi.encode(coreState)) != LibState.getCoreStateHash(state)) {
            revert InvalidState();
        }

        for (uint256 i; i < blobLocators.length; ++i) {
            BlobSegment memory blobSegment = _validateBlobLocator(blobLocators[i]);
            coreState = _propose(coreState, blobSegment);
        }

        SyncedBlock memory syncedBlock;
        (coreState, syncedBlock) = _finalize(coreState, claimRecords);

        LibState.setCoreStateHash(state, keccak256(abi.encode(coreState)));
        LibState.setSyncedBlock(state, syncedBlock);
    }

    function prove(bytes calldata _data, bytes calldata _proof) external {
        (Proposal[] memory proposals, Claim[] memory claims) =
            abi.decode(_data, (Proposal[], Claim[]));

        if (proposals.length != claims.length) revert InconsistentParams();

        for (uint256 i; i < proposals.length; ++i) {
            Proposal memory proposal = proposals[i];

            bytes32 proposalHash = keccak256(abi.encode(proposal));
            if (proposalHash != claims[i].proposalHash) revert ProposalHashMismatch();
            if (proposalHash != LibState.getProposalHash(state, proposal.id)) {
                revert ProposalHashMismatch();
            }

            ProofTiming proofTiming = block.timestamp <= proposal.timestamp + provingWindow
                ? ProofTiming.InProvingWindow
                : block.timestamp <= proposal.timestamp + extendedProvingWindow
                    ? ProofTiming.InExtendedProvingWindow
                    : ProofTiming.OutOfExtendedProvingWindow;

            ClaimRecord memory claimRecord = ClaimRecord({
                claim: claims[i],
                proposer: proposal.proposer,
                livenessBond: proposal.livenessBond,
                provabilityBond: proposal.provabilityBond,
                proofTiming: proofTiming
            });

            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
            LibState.setClaimRecordHash(
                state, proposal.id, claims[i].parentClaimHash, claimRecordHash
            );
            emit Proved(proposal, claimRecord);
        }

        bytes32 claimsHash = keccak256(abi.encode(claims));
        verifyProof(claimsHash, _proof);
    }

    /// @dev Finalizes proposals by verifying claim records and updating state.
    /// @param _coreState The current core state.
    /// @param _claimRecords The claim records to finalize.
    /// @return The updated core state and synced block.
    function _finalize(
        CoreState memory _coreState,
        ClaimRecord[] memory _claimRecords
    )
        private
        returns (CoreState memory, SyncedBlock memory)
    {
        if (keccak256(abi.encode(_coreState)) != LibState.getCoreStateHash(state)) {
            revert InvalidState();
        }

        SyncedBlock memory syncedBlock;
        for (uint256 i; i < _claimRecords.length; ++i) {
            ClaimRecord memory claimRecord = _claimRecords[i];
            Claim memory claim = claimRecord.claim;

            if (claim.parentClaimHash != _coreState.lastFinalizedClaimHash) {
                revert InvalidClaimChain();
            }

            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));

            uint48 proposalId = ++_coreState.lastFinalizedProposalId;

            bytes32 storedClaimRecordHash =
                LibState.getClaimRecordHash(state, proposalId, claim.parentClaimHash);

            if (storedClaimRecordHash != claimRecordHash) revert ClaimRecordHashMismatch();

            _coreState.lastFinalizedClaimHash = keccak256(abi.encode(claim));
            _coreState.bondOperationsHash =
                _processBonds(proposalId, claimRecord, _coreState.bondOperationsHash);

            emit Finalized(proposalId, claimRecord);

            syncedBlock = SyncedBlock({
                blockNumber: claim.endBlockNumber,
                blockHash: claim.endBlockHash,
                stateRoot: claim.endStateRoot
            });
        }

        return (_coreState, syncedBlock);
    }

    // -------------------------------------------------------------------------
    // Internal Functions - Abstract
    // -------------------------------------------------------------------------

    /// @dev Verifies a validity proof for a state transition. This function must revert if the
    /// proof is invalid.
    /// @param _claimsHash The hash of the claims to verify.
    /// @param _proof The proof for the claims.
    function verifyProof(bytes32 _claimsHash, bytes calldata _proof) internal virtual;

    /// @dev Debits a bond from an address with best effort.
    /// @param _address The address to debit the bond from.
    /// @param _bond The amount of bond to debit.
    /// @return amountDebited_ The actual amount debited.
    function _debitBond(
        address _address,
        uint48 _bond
    )
        internal
        virtual
        returns (uint48 amountDebited_)
    { }

    /// @dev Credits a bond to an address.
    /// @param _address The address to credit the bond to.
    /// @param _bond The amount of bond to credit.
    function _creditBond(address _address, uint48 _bond) internal virtual { }

    /// @dev Checks if an address is a valid proposer.
    /// @param _address The address to check.
    /// @return True if the address is a valid proposer, false otherwise.
    function _isValidProposer(address _address) internal view virtual returns (bool) { }

    /// @dev Gets the bond balance of an address.
    /// @param _address The address to get the bond balance for.
    /// @return The bond balance of the address.
    function _getBondBalance(address _address) internal view virtual returns (uint256) { }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @dev Proposes a new proposal of L2 blocks.
    /// @param _coreState The core state of the inbox.
    /// @param _content The content of the proposal.
    /// @return The updated core state.
    function _propose(
        CoreState memory _coreState,
        BlobSegment memory _content
    )
        private
        returns (CoreState memory)
    {
        uint48 proposalId = _coreState.nextProposalId++;
        uint48 timestamp = uint48(block.timestamp);
        uint48 referenceBlockNumber = uint48(block.number);

        Proposal memory proposal = Proposal({
            id: proposalId,
            proposer: msg.sender,
            provabilityBond: provabilityBond,
            livenessBond: livenessBond,
            timestamp: timestamp,
            proposedBlockNumber: referenceBlockNumber,
            content: _content
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal));
        LibState.setProposalHash(state, proposalId, proposalHash);

        emit Proposed(proposal);
        return _coreState;
    }

    /// @dev Handles bond refunds and penalties based on proof timing and prover identity.
    /// @param _proposalId The ID of the proposal.
    /// @param _claimRecord The claim record containing bond and timing information.
    /// @param _bondOperationsHash The hash of the bond operations.
    /// @return bondOperationsHash_ The updated hash of the bond operations.
    function _processBonds(
        uint48 _proposalId,
        ClaimRecord memory _claimRecord,
        bytes32 _bondOperationsHash
    )
        private
        returns (bytes32 bondOperationsHash_)
    {
        uint48 credit;
        address receiver;

        Claim memory claim = _claimRecord.claim;
        if (_claimRecord.proofTiming == ProofTiming.InProvingWindow) {
            // Proof submitted within the designated proving window (on-time proof)
            // The designated prover successfully proved the block on time

            if (claim.designatedProver == _claimRecord.proposer) {
                // Proposer and designated prover are the same entity
                // No L2 bond transfers needed since all bonds were handled on L1
            } else {
                // Proposer and designated prover are different entities
                // The designated prover paid a liveness bond on L2 that needs to be refunded
                credit = _claimRecord.livenessBond;
                receiver = claim.designatedProver;
            }
        } else if (_claimRecord.proofTiming == ProofTiming.InExtendedProvingWindow) {
            // Proof submitted during extended window (late but acceptable proof)
            // The designated prover failed to prove on time, but another prover stepped in

            if (claim.designatedProver == _claimRecord.proposer) {
                _debitBond(_claimRecord.proposer, _claimRecord.livenessBond);
                // Proposer was also the designated prover who failed to prove on time
                // Forfeit their liveness bond but reward the actual prover with half
                _creditBond(claim.actualProver, _claimRecord.livenessBond / 2);
            } else {
                // Reward the actual prover with half of the liveness bond on L2
                credit = _claimRecord.livenessBond / 2;
                receiver = claim.actualProver;
            }
        } else {
            // Proof submitted after extended window (very late proof)
            // Block was difficult to prove, forfeit provability bond but reward prover
            _debitBond(_claimRecord.proposer, _claimRecord.provabilityBond);
            _creditBond(claim.actualProver, _claimRecord.provabilityBond / 2);

            // Forfeit proposer's provability bond but give half to the actual prover
            if (claim.designatedProver == _claimRecord.proposer) {
                // Proposer was the designated prover
                // Refund their liveness bond since the block was hard to prove
            } else {
                // Proposer and designated prover are different entities
                // Refund the designated prover's L2 liveness bond
                credit = _claimRecord.livenessBond;
                receiver = claim.designatedProver;
            }
        }

        if (credit == 0) {
            return _bondOperationsHash;
        } else {
            return keccak256(abi.encode(_bondOperationsHash, _proposalId, receiver, credit));
        }
    }

    /// @dev Validates a blob locator and converts it to a blob segment.
    /// @param _blobLocator The blob locator to validate.
    /// @return The blob segment.
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
    error ClaimRecordHashMismatch();
    error InconsistentParams();
    error InsufficientBond();
    error InvalidBlobLocator();
    error InvalidClaimChain();
    error InvalidState();
    error ProposalHashMismatch();
    error Unauthorized();
}
