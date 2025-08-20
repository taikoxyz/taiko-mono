// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ISyncedBlockManager } from "src/shared/based/iface/ISyncedBlockManager.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title Inbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture.
/// @custom:security-contact security@taiko.xyz

abstract contract Inbox is EssentialContract, IInbox {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when bond is withdrawn from the contract
    /// @param user The user whose bond was withdrawn
    /// @param amount The amount of bond withdrawn
    event BondWithdrawn(address indexed user, uint256 amount);

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Extended claim record that stores both the claim hash and encoded metadata.
    /// @dev The metadata includes the proposal ID and partial parent claim hash for efficient
    /// lookups.
    struct ExtendedClaimRecord {
        bytes32 claimRecordHash;
        uint256 slotReuseMarker;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    /// @dev Empty slot marker to distinguish uninitialized slots from actual proposal hashes.
    /// keccak256("EMPTY_PROPOSAL_SLOT_V1")
    bytes32 private constant _EMPTY_SLOT_MARKER =
        0x8159ea2f8547d3aac786e3dd5558567ed0f292248b867bfd642489b7ec86aea9;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Ring buffer for storing proposal hashes.
    /// This variable reuse the `batches slot in pacaya fork.
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev This variable is no longer used.
    mapping(uint256 bufferSlot => mapping(bytes32 parentHash => uint24 transitionId)) private
        __transitionIdsPacaya;

    /// @dev Ring buffer for storing claim records.
    /// This variable reuse the `transitions` slot in pacaya fork.
    mapping(uint256 bufferSlot => mapping(bytes32 compositeKey => ExtendedClaimRecord record))
        internal _claimHashLookup;

    /// @dev Deprecated slots used by Pacaya inbox that contains:
    /// - `__reserve1`
    /// - `stats1`
    /// - `stats2`
    uint256[3] private __slotsUsedByPacaya;

    /// @notice Bond balance for each account used in Pacaya inbox.
    /// @dev This is not used in Shasta. It is kept so users can withdraw their bond.
    /// @dev Bonds are now handled entirely on L2, by the `BondManager` contract.
    mapping(address account => uint256 bond) public bondBalance;

    uint256[43] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    constructor() EssentialContract() { }

    /// @notice Initializes the Inbox contract with genesis block
    /// @param _owner The owner of this contract
    /// @param _genesisBlockHash The hash of the genesis block
    function init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Essential_init(_owner);
        Config memory config = getConfig();

        Claim memory claim;
        claim.endBlockHash = _genesisBlockHash;

        CoreState memory coreState;
        coreState.nextProposalId = 1;
        coreState.lastFinalizedClaimHash = _hashClaim(claim);

        Derivation memory derivation;

        Proposal memory proposal;
        proposal.coreStateHash = _hashCoreState(coreState);
        proposal.derivationHash = _hashDerivation(derivation);

        // Set the genesis proposal at slot 0
        _setProposalHash(config, 0, _hashProposal(proposal));

        // Initialize remaining ring buffer slots with empty marker to distinguish them
        // from data from previous fork's storage. This is a one-time cost during deployment.
        for (uint256 i = 1; i < config.ringBufferSize; ++i) {
            _proposalHashes[i] = _EMPTY_SLOT_MARKER;
        }

        emit Proposed(encodeProposedEventData(proposal, derivation, coreState));
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInbox
    /// @dev This function handles both forced inclusions and regular proposals:
    ///      - If a forced inclusion is due, it processes exactly one (the oldest) before the
    /// regular proposal
    ///      - Forced inclusions are only processed when due, they cannot be processed early.
    function propose(
        bytes calldata,
        /*_lookahead*/
        bytes calldata _data
    )
        external
        nonReentrant
    {
        Config memory config = getConfig();

        // Validate proposer
        IProposerChecker(config.proposerChecker).checkProposer(msg.sender);

        // Decode and validate input data
        (
            uint64 deadline,
            CoreState memory coreState,
            Proposal[] memory parentProposals,
            LibBlobs.BlobReference memory blobReference,
            ClaimRecord[] memory claimRecords
        ) = decodeProposeData(_data);

        _validateProposeInputs(deadline, coreState, parentProposals);

        // Verify parentProposals[0] is actually the last proposal stored on-chain.
        _verifyChainHead(config, parentProposals);

        // IMPORTANT: Finalize first to free ring buffer space and prevent deadlock
        coreState = _finalize(config, coreState, claimRecords);

        // Verify capacity for new proposals
        uint256 availableCapacity = _getAvailableCapacity(config, coreState);
        require(availableCapacity > 0, ExceedsUnfinalizedProposalCapacity());

        if (availableCapacity > 1) {
            // Process forced inclusion if required
            coreState = _processForcedInclusion(config, coreState);
        }

        // Create regular proposal
        LibBlobs.BlobSlice memory blobSlice =
            LibBlobs.validateBlobReference(blobReference, _getBlobHash);
        _propose(config, coreState, blobSlice, false);
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        Config memory config = getConfig();

        // Decode and validate input
        (Proposal[] memory proposals, Claim[] memory claims) = decodeProveData(_data);
        require(proposals.length != 0, EmptyProposals());
        require(proposals.length == claims.length, InconsistentParams());

        // Build claim records with validation and bond calculations
        ClaimRecord[] memory claimRecords = _buildClaimRecords(config, proposals, claims);

        // Store claim records and emit events
        _storeClaimRecords(config, claimRecords);
        // Verify the proof
        IProofVerifier(config.proofVerifier).verifyProof(_hashClaimsArray(claims), _proof);
    }

    /// @notice Withdraws bond balance for the caller.
    function withdrawBond() external nonReentrant {
        uint256 amount = bondBalance[msg.sender];
        require(amount > 0, NoBondToWithdraw());

        // Clear balance before transfer (checks-effects-interactions)
        bondBalance[msg.sender] = 0;

        // Transfer the bond
        IERC20(getConfig().bondToken).safeTransfer(msg.sender, amount);

        emit BondWithdrawn(msg.sender, amount);
    }

    /// @notice Gets the proposal hash for a given proposal ID.
    /// @param _proposalId The proposal ID to look up.
    /// @return proposalHash_ The hash stored at the proposal's ring buffer slot.
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_) {
        Config memory config = getConfig();
        uint256 bufferSlot = _proposalId % config.ringBufferSize;
        proposalHash_ = _proposalHashes[bufferSlot];
    }

    /// @notice Gets the claim record hash for a given proposal and parent claim.
    /// @param _proposalId The proposal ID to look up.
    /// @param _parentClaimHash The parent claim hash to look up.
    /// @return claimRecordHash_ The claim record hash, or bytes32(0) if not found.
    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        external
        view
        returns (bytes32 claimRecordHash_)
    {
        Config memory config = getConfig();
        return _getClaimRecordHash(config, _proposalId, _parentClaimHash);
    }

    /// @notice Gets the capacity for unfinalized proposals.
    /// @return _ The maximum number of unfinalized proposals that can exist.
    function getCapacity() external view returns (uint256) {
        Config memory config = getConfig();
        return _getCapacity(config);
    }

    /// @notice Gets the configuration for this Inbox contract
    /// @dev This function must be overridden by subcontracts to provide their specific
    /// configuration
    /// @return _ The configuration struct
    function getConfig() public view virtual returns (Config memory);

    /// @notice Decodes proposal data
    /// @param _data The encoded data
    /// @return deadline_ The decoded deadline timestamp. If non-zero, the transaction will revert
    /// if included after this time,
    ///                   protecting proposers from their transactions landing on-chain later than
    /// intended
    /// @return coreState_ The decoded CoreState representing the current state before this new
    /// proposal.
    ///                    Its hash must match the coreStateHash stored in proposals_[0]
    /// @return parentProposals_ The decoded array of existing proposals for validation. Always
    /// contains 1 or 2 elements:
    ///                         - parentProposals_[0]: The last proposal on-chain (must match stored
    /// hash)
    ///                         - parentProposals_[1]: Only present for ring buffer wraparound -
    /// when the next slot
    ///                                              contains an older proposal (with smaller ID)
    /// that must be validated
    /// @return blobReference_ The decoded BlobReference
    /// @return claimRecords_ The decoded array of ClaimRecords
    function decodeProposeData(bytes calldata _data)
        public
        pure
        virtual
        returns (
            uint48 deadline_,
            CoreState memory coreState_,
            Proposal[] memory parentProposals_,
            LibBlobs.BlobReference memory blobReference_,
            ClaimRecord[] memory claimRecords_
        )
    {
        (deadline_, coreState_, parentProposals_, blobReference_, claimRecords_) = abi.decode(
            _data, (uint48, CoreState, Proposal[], LibBlobs.BlobReference, ClaimRecord[])
        );
    }

    /// @notice Decodes data into Proposal array and Claim array
    /// @param _data The encoded data
    /// @return proposals_ The decoded array of Proposals
    /// @return claims_ The decoded array of Claims
    function decodeProveData(bytes calldata _data)
        public
        pure
        virtual
        returns (Proposal[] memory proposals_, Claim[] memory claims_)
    {
        (proposals_, claims_) = abi.decode(_data, (Proposal[], Claim[]));
    }

    /// @dev Encodes the proposed event data
    /// @param _proposal The proposal to encode
    /// @param _derivation The derivation data to encode
    /// @param _coreState The core state to encode
    /// @return The encoded data
    function encodeProposedEventData(
        Proposal memory _proposal,
        Derivation memory _derivation,
        CoreState memory _coreState
    )
        public
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(_proposal, _derivation, _coreState);
    }

    /// @dev Encodes the proved event data
    /// @param _claimRecord The claim record to encode
    /// @return The encoded data
    function encodeProveEventData(ClaimRecord memory _claimRecord)
        public
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(_claimRecord);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Builds claim records for multiple proposals and claims.
    /// @param _config The configuration parameters.
    /// @param _proposals The proposals to prove.
    /// @param _claims The claims containing the proof details.
    /// @return claimRecords_ The built claim records.
    function _buildClaimRecords(
        Config memory _config,
        Proposal[] memory _proposals,
        Claim[] memory _claims
    )
        internal
        view
        virtual
        returns (ClaimRecord[] memory claimRecords_)
    {
        claimRecords_ = new ClaimRecord[](_proposals.length);
        for (uint256 i; i < _proposals.length; ++i) {
            Proposal memory proposal = _proposals[i];
            Claim memory claim = _claims[i];

            _validateClaim(_config, proposal, claim);

            LibBonds.BondInstruction[] memory bondInstructions =
                _calculateBondInstructions(_config, proposal, claim);

            claimRecords_[i] = ClaimRecord({
                proposalId: proposal.id,
                claim: claim,
                span: 1,
                bondInstructions: bondInstructions
            });
        }
    }

    /// @dev Gets the hash of a blob index.
    /// @param _blobIndex The blob index to hash.
    /// @return _ The hash of the blob index.
    /// @dev This function is virtual so that it can be overridden by subcontracts to provide their
    /// specific blob hash function.
    function _getBlobHash(uint256 _blobIndex) internal view virtual returns (bytes32) {
        return blobhash(_blobIndex);
    }

    /// @dev Validates that a claim is valid for a given proposal.
    /// @param _config The configuration parameters.
    /// @param _proposal The proposal to validate.
    /// @param _claim The claim to validate.
    function _validateClaim(
        Config memory _config,
        Proposal memory _proposal,
        Claim memory _claim
    )
        internal
        view
    {
        bytes32 proposalHash = _checkProposalHash(_config, _proposal);
        require(proposalHash == _claim.proposalHash, ProposalHashMismatchWithClaim());
    }

    /// @dev Calculates the bond instructions based on proof timing and prover identity
    /// @notice Bond instructions determine how provability and liveness bonds are handled:
    /// - On-time proofs: Bonds may be refunded or remain unchanged
    /// - Late proofs: Liveness bonds may be slashed and redistributed
    /// - Very late proofs: Provability bonds may also be slashed and redistributed
    /// @param _config The configuration parameters.
    /// @param _proposal The proposal containing timing and proposer information
    /// @param _claim The claim containing the proof details.
    /// @return bondInstructions_ The bond instructions that affect aggregation eligibility
    function _calculateBondInstructions(
        Config memory _config,
        Proposal memory _proposal,
        Claim memory _claim
    )
        internal
        view
        returns (LibBonds.BondInstruction[] memory bondInstructions_)
    {
        unchecked {
            uint256 proofTimestamp = block.timestamp;
            uint256 windowEnd = _proposal.timestamp + _config.provingWindow;

            // On-time proof - no bond instructions needed
            if (proofTimestamp <= windowEnd) {
                return new LibBonds.BondInstruction[](0);
            }

            // Late or very late proof - determine bond type and parties
            uint256 extendedWindowEnd = _proposal.timestamp + _config.extendedProvingWindow;
            bool isWithinExtendedWindow = proofTimestamp <= extendedWindowEnd;

            // Check if bond instruction is needed
            bool needsBondInstruction = isWithinExtendedWindow
                ? (_claim.designatedProver != _claim.actualProver)
                : (_proposal.proposer != _claim.actualProver);

            if (!needsBondInstruction) {
                return new LibBonds.BondInstruction[](0);
            }

            // Create single bond instruction
            bondInstructions_ = new LibBonds.BondInstruction[](1);
            bondInstructions_[0] = LibBonds.BondInstruction({
                proposalId: _proposal.id,
                bondType: isWithinExtendedWindow
                    ? LibBonds.BondType.LIVENESS
                    : LibBonds.BondType.PROVABILITY,
                payer: isWithinExtendedWindow ? _claim.designatedProver : _proposal.proposer,
                receiver: _claim.actualProver
            });
        }
    }

    /// @dev Sets the proposal hash for a given proposal ID.
    function _setProposalHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _proposalHash
    )
        internal
    {
        _proposalHashes[_proposalId % _config.ringBufferSize] = _proposalHash;
    }

    /// @dev Sets the claim record hash for a given proposal and parent claim.
    function _setClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
        virtual
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        bytes32 compositeKey = _composeClaimKey(_proposalId, _parentClaimHash);
        _claimHashLookup[bufferSlot][compositeKey].claimRecordHash = _claimRecordHash;
    }

    /// @dev Gets the capacity for unfinalized proposals.
    function _getCapacity(Config memory _config) internal pure returns (uint256) {
        // The ring buffer can hold ringBufferSize proposals total, but we need to ensure
        // unfinalized proposals are not overwritten. Therefore, the maximum number of
        // unfinalized proposals is ringBufferSize - 1.
        unchecked {
            return _config.ringBufferSize - 1;
        }
    }

    /// @dev Gets the available capacity for new proposals.
    /// @param _config The configuration parameters.
    /// @param _coreState The core state.
    /// @return _ The available capacity for new proposals.
    function _getAvailableCapacity(
        Config memory _config,
        CoreState memory _coreState
    )
        private
        pure
        returns (uint256)
    {
        unchecked {
            uint256 numUnfinalizedProposals =
                _coreState.nextProposalId - _coreState.lastFinalizedProposalId - 1;
            return _getCapacity(_config) - numUnfinalizedProposals;
        }
    }

    /// @dev Gets the claim record hash for a given proposal and parent claim.
    function _getClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        internal
        view
        virtual
        returns (bytes32 claimRecordHash_)
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        bytes32 compositeKey = _composeClaimKey(_proposalId, _parentClaimHash);
        claimRecordHash_ = _claimHashLookup[bufferSlot][compositeKey].claimRecordHash;
    }

    /// @dev Checks if a proposal matches the stored hash and reverts if not.
    /// @param _config The configuration parameters.
    /// @param _proposal The proposal to check.
    /// @return proposalHash_ The hash of the proposal.
    function _checkProposalHash(
        Config memory _config,
        Proposal memory _proposal
    )
        internal
        view
        returns (bytes32 proposalHash_)
    {
        proposalHash_ = _hashProposal(_proposal);
        bytes32 storedProposalHash = _proposalHashes[_proposal.id % _config.ringBufferSize];
        require(proposalHash_ == storedProposalHash, ProposalHashMismatch());
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Validates the basic inputs for propose function
    /// @param _deadline The deadline timestamp for transaction inclusion (0 = no deadline).
    /// @param _coreState The current core state before this proposal, which must match the previous
    /// proposal's stored hash.
    /// @param _parentProposals Array of existing proposals for validation (1-2 elements).
    ///                        parentProposals[0] is the last proposal, parentProposals[1] handles
    /// ring buffer wraparound.
    function _validateProposeInputs(
        uint64 _deadline,
        CoreState memory _coreState,
        Proposal[] memory _parentProposals
    )
        private
        view
    {
        require(_deadline == 0 || block.timestamp <= _deadline, DeadlineExceeded());
        require(_parentProposals.length > 0, EmptyProposals());
        require(_hashCoreState(_coreState) == _parentProposals[0].coreStateHash, InvalidState());
    }

    /// @dev Processes forced inclusion if required
    /// @param _config The configuration parameters.
    /// @param _coreState The core state.
    /// @return  The updated core state or the same core state if no forced inclusion is due.
    function _processForcedInclusion(
        Config memory _config,
        CoreState memory _coreState
    )
        private
        returns (CoreState memory)
    {
        IForcedInclusionStore store = IForcedInclusionStore(_config.forcedInclusionStore);

        if (!store.isOldestForcedInclusionDue()) {
            return _coreState;
        }

        IForcedInclusionStore.ForcedInclusion memory forcedInclusion =
            store.consumeOldestForcedInclusion(msg.sender);

        return _propose(_config, _coreState, forcedInclusion.blobSlice, true);
    }

    /// @dev Stores claim records and emits events
    /// @param _config The configuration parameters.
    /// @param _claimRecords The claim records to store.
    function _storeClaimRecords(
        Config memory _config,
        ClaimRecord[] memory _claimRecords
    )
        private
    {
        for (uint256 i; i < _claimRecords.length; ++i) {
            bytes32 claimRecordHash = _hashClaimRecord(_claimRecords[i]);

            _setClaimRecordHash(
                _config,
                _claimRecords[i].proposalId,
                _claimRecords[i].claim.parentClaimHash,
                claimRecordHash
            );

            emit Proved(encodeProveEventData(_claimRecords[i]));
        }
    }

    /// @dev Verifies that parentProposals[0] is the chain head (last proposal)
    /// @param _config The configuration parameters.
    /// @param _parentProposals The parent proposals array to verify (1-2 elements).
    /// parentProposals[0] is the last proposal stored on-chain and parentProposals[1](if present)
    /// is the previous proposal stored in the ring buffer.
    function _verifyChainHead(
        Config memory _config,
        Proposal[] memory _parentProposals
    )
        private
        view
    {
        // First verify parentProposals[0] matches what's stored on-chain
        _checkProposalHash(_config, _parentProposals[0]);

        // Then verify it's actually the chain head
        uint256 nextBufferSlot = (_parentProposals[0].id + 1) % _config.ringBufferSize;
        bytes32 storedNextProposalHash = _proposalHashes[nextBufferSlot];

        if (storedNextProposalHash != _EMPTY_SLOT_MARKER) {
            // Next slot in the ring buffer is occupied (after wraparound), need to prove
            // it contains an older proposal (smaller proposal id)
            require(
                _parentProposals[1].id < _parentProposals[0].id,
                NextProposalIdSmallerThanLastProposalId()
            );
            _checkProposalHash(_config, _parentProposals[1]);
        }
    }

    /// @dev Proposes a new proposal of L2 blocks.
    /// @param _config The configuration parameters.
    /// @param _coreState The core state of the inbox (potentially updated by finalization/forced
    /// inclusion).
    ///                   This state's hash will be stored in the new proposal.
    /// @param _blobSlice The blob slice of the proposal.
    /// @param _isForcedInclusion Whether the proposal is a forced inclusion.
    /// @return The updated core state.
    function _propose(
        Config memory _config,
        CoreState memory _coreState,
        LibBlobs.BlobSlice memory _blobSlice,
        bool _isForcedInclusion
    )
        private
        returns (CoreState memory)
    {
        unchecked {
            uint256 parentBlockNumber = block.number - 1;

            Derivation memory derivation = Derivation({
                originBlockNumber: uint48(parentBlockNumber),
                originBlockHash: blockhash(parentBlockNumber),
                isForcedInclusion: _isForcedInclusion,
                basefeeSharingPctg: _config.basefeeSharingPctg,
                blobSlice: _blobSlice
            });

            Proposal memory proposal = Proposal({
                id: _coreState.nextProposalId++,
                proposer: msg.sender,
                timestamp: uint48(block.timestamp),
                coreStateHash: _hashCoreState(_coreState),
                derivationHash: _hashDerivation(derivation)
            });

            _setProposalHash(_config, proposal.id, _hashProposal(proposal));
            emit Proposed(encodeProposedEventData(proposal, derivation, _coreState));

            return _coreState;
        }
    }

    /// @dev Finalizes proposals by verifying claim records and updating state.
    /// @dev This function enforces that proposers finalize the maximum possible number of proposals
    /// up to `maxFinalizationCount`.
    /// The enforcement works by attempting to finalize one more proposal than claim records
    /// provided.
    /// If that extra proposal can be finalized, the transaction reverts, forcing proposers to
    /// provide
    /// sufficient claim records.
    /// @param _config The configuration parameters.
    /// @param _coreState The current core state.
    /// @param _claimRecords The claim records to finalize.
    /// @return _ The updated core state
    function _finalize(
        Config memory _config,
        CoreState memory _coreState,
        ClaimRecord[] memory _claimRecords
    )
        private
        returns (CoreState memory)
    {
        uint48 nextToFinalize = _coreState.lastFinalizedProposalId + 1;
        uint256 finalizedCount;
        ClaimRecord memory lastFinalizedRecord;

        // Process all provided claim records up to `maxFinalizationCount`
        uint256 recordsToProcess = _claimRecords.length < _config.maxFinalizationCount
            ? _claimRecords.length
            : _config.maxFinalizationCount;

        for (uint256 i; i < recordsToProcess; ++i) {
            // Stop if no more proposals to finalize
            if (nextToFinalize >= _coreState.nextProposalId) break;

            // Try to finalize with the provided claim record
            bool finalized;
            (finalized, nextToFinalize) =
                _tryFinalize(nextToFinalize, _config, _coreState, _claimRecords[i]);

            // If finalization failed, stop trying
            if (!finalized) break;

            // Update state for successful finalization
            lastFinalizedRecord = _claimRecords[i];
            finalizedCount++;
        }

        // Make sure we are not finalizing less proposals than possible.
        _enforceMaximumFinalization(
            _config, _coreState, _claimRecords.length, finalizedCount, nextToFinalize
        );

        // Update synced block if any proposals were finalized
        if (finalizedCount > 0) {
            ISyncedBlockManager(_config.syncedBlockManager).saveSyncedBlock(
                lastFinalizedRecord.claim.endBlockNumber,
                lastFinalizedRecord.claim.endBlockHash,
                lastFinalizedRecord.claim.endStateRoot
            );
        }

        return _coreState;
    }

    /// @dev Enforces that proposers provide all available claim records.
    /// @param _config The configuration parameters.
    /// @param _coreState The core state.
    /// @param _providedClaimRecordsCount Number of claim records provided.
    /// @param _finalizedCount Number of proposals finalized.
    /// @param _nextToFinalize Next proposal ID to finalize.
    function _enforceMaximumFinalization(
        Config memory _config,
        CoreState memory _coreState,
        uint256 _providedClaimRecordsCount,
        uint256 _finalizedCount,
        uint48 _nextToFinalize
    )
        private
        view
    {
        // Not even all records were used. There's no more to finalize
        if (_finalizedCount < _providedClaimRecordsCount) return;

        // Hit the max limit
        if (_finalizedCount >= _config.maxFinalizationCount) return;

        // No more proposals exist - we're done
        if (_nextToFinalize >= _coreState.nextProposalId) return;

        // We used all records, haven't hit max, and more proposals exist
        // Check if the next proposal has a finalizable claim
        bytes32 nextClaimHash =
            _getClaimRecordHash(_config, _nextToFinalize, _coreState.lastFinalizedClaimHash);

        // If a claim exists, proposer should have provided it
        require(nextClaimHash == 0, InsufficientClaimRecordsProvided());
    }

    /// @dev Attempts to finalize a single proposal
    /// @param _proposalId The proposal ID to finalize.
    /// @param _config The configuration parameters.
    /// @param _coreState The core state to update.
    /// @param _claimRecord The claim record for this proposal.
    /// @return finalized_ Whether the proposal was successfully finalized.
    /// @return nextProposalId_ The next proposal ID to process.
    function _tryFinalize(
        uint48 _proposalId,
        Config memory _config,
        CoreState memory _coreState,
        ClaimRecord memory _claimRecord
    )
        private
        returns (bool finalized_, uint48 nextProposalId_)
    {
        // Check if claim record exists in storage
        bytes32 storedHash =
            _getClaimRecordHash(_config, _proposalId, _coreState.lastFinalizedClaimHash);

        // No claim exists for this proposal - cannot finalize
        if (storedHash == 0) return (false, _proposalId);

        // Verify the provided claim record matches what's stored
        bytes32 claimRecordHash = _hashClaimRecord(_claimRecord);
        require(claimRecordHash == storedHash, ClaimRecordHashMismatchWithStorage());

        // Update core state
        _coreState.lastFinalizedProposalId = _proposalId;
        _coreState.lastFinalizedClaimHash = _hashClaim(_claimRecord.claim);

        // Process bond instructions
        _processBondInstructions(_coreState, _claimRecord.bondInstructions);

        // This should never happen, but we check just in case
        require(_claimRecord.span > 0, InvalidSpan());
        nextProposalId_ = _proposalId + _claimRecord.span;
        // This should never happen, but we check just in case
        require(nextProposalId_ <= _coreState.nextProposalId, SpanOutOfBounds());

        return (true, nextProposalId_);
    }

    /// @dev Processes bond instructions and updates core state
    /// @param _coreState The core state to update.
    /// @param _instructions The bond instructions to process.
    function _processBondInstructions(
        CoreState memory _coreState,
        LibBonds.BondInstruction[] memory _instructions
    )
        private
    {
        if (_instructions.length == 0) return;

        emit BondInstructed(_instructions);

        for (uint256 i; i < _instructions.length; ++i) {
            _coreState.bondInstructionsHash =
                LibBonds.aggregateBondInstruction(_coreState.bondInstructionsHash, _instructions[i]);
        }
    }

    /// @dev Computes the composite key for claim record lookups.
    /// @param _proposalId The proposal ID.
    /// @param _parentClaimHash The parent claim hash.
    /// @return _ The composite key for the mapping.
    function _composeClaimKey(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_proposalId, _parentClaimHash));
    }

    /// @dev Hashes a Claim struct.
    /// @param _claim The claim to hash.
    /// @return _ The hash of the claim.
    function _hashClaim(Claim memory _claim) private pure returns (bytes32) {
        return keccak256(abi.encode(_claim));
    }

    /// @dev Hashes a Proposal struct.
    /// @param _proposal The proposal to hash.
    /// @return _ The hash of the proposal.
    function _hashProposal(Proposal memory _proposal) private pure returns (bytes32) {
        return keccak256(abi.encode(_proposal));
    }

    /// @dev Hashes a CoreState struct.
    /// @param _coreState The core state to hash.
    /// @return _ The hash of the core state.
    function _hashCoreState(CoreState memory _coreState) private pure returns (bytes32) {
        return keccak256(abi.encode(_coreState));
    }

    /// @dev Hashes a ClaimRecord struct.
    /// @param _claimRecord The claim record to hash.
    /// @return _ The hash of the claim record.
    function _hashClaimRecord(ClaimRecord memory _claimRecord) private pure returns (bytes32) {
        return keccak256(abi.encode(_claimRecord));
    }

    /// @dev Hashes a Derivation struct.
    /// @param _derivation The derivation to hash.
    /// @return _ The hash of the derivation.
    function _hashDerivation(Derivation memory _derivation) private pure returns (bytes32) {
        return keccak256(abi.encode(_derivation));
    }

    /// @dev Hashes an array of Claims.
    /// @param _claims The claims array to hash.
    /// @return _ The hash of the claims array.
    function _hashClaimsArray(Claim[] memory _claims) private pure returns (bytes32) {
        return keccak256(abi.encode(_claims));
    }
}

// ---------------------------------------------------------------
// Errors
// ---------------------------------------------------------------
error ProposalHashMismatchWithClaim();
error ProposalHashMismatchWithStorage();
error ClaimRecordHashMismatchWithStorage();
error DeadlineExceeded();
error EmptyProposals();
error ExceedsUnfinalizedProposalCapacity();
error ForkNotActive();
error InconsistentParams();
error InsufficientBond();
error InsufficientClaimRecordsProvided();
error InvalidForcedInclusion();
error InvalidSpan();
error InvalidState();
error LastProposalHashMismatch();
error LastProposalProofNotEmpty();
error NextProposalHashMismatch();
error NextProposalIdSmallerThanLastProposalId();
error NoBondToWithdraw();
error ProposalHashMismatch();
error ProposalIdMismatch();
error ProposerBondInsufficient();
error RingBufferSizeZero();
error SpanOutOfBounds();
error Unauthorized();
