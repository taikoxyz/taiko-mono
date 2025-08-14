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

/// @title ShastaInbox
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

    /// @notice Stores proposal data and associated claim records.
    /// @dev Each proposal can have multiple claims associated with it, indexed by a composite key
    /// of proposal ID and parent claim hash.
    struct ProposalRecord {
        /// @dev Hash of the proposal data
        bytes32 proposalHash;
        /// @dev Maps composite keys (keccak256(proposalId, parentClaimHash)) to their corresponding
        /// claim record hashes
        mapping(bytes32 compositeKey => ExtendedClaimRecord claimRecordHash) claimHashLookup;
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    // 5 slots are used by the State object defined in Pacaya inbox:
    // mapping(uint256 batchId_mod_batchRingBufferSize => Batch batch) batches;
    // mapping(uint256 batchId => mapping(bytes32 parentHash => uint24 transitionId)) transitionIds;
    // mapping(uint256 batchId_mod_batchRingBufferSize => mapping(uint24 transitionId =>
    //         TransitionState ts)) transitions;
    // bytes32 __reserve1;
    // Stats1 stats1;
    uint256[5] private __slotsUsedByPacaya;

    // Reserved slot for future migration compatibility
    uint256 private __reservedSlot;

    mapping(address account => uint256 bond) public bondBalance;

    /// @dev Ring buffer for storing proposal records.
    mapping(uint256 bufferSlot => ProposalRecord proposalRecord) private _proposalRingBuffer;

    uint256[42] private __gap;

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

        Claim memory claim;
        claim.endBlockHash = _genesisBlockHash;

        CoreState memory coreState;
        coreState.nextProposalId = 1;
        coreState.lastFinalizedClaimHash = _hashClaim(claim);

        Proposal memory proposal;
        proposal.coreStateHash = _hashCoreState(coreState);
        _setProposalHash(getConfig(), 0, _hashProposal(proposal));

        emit Proposed(encodeProposedEventData(proposal, coreState));
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInbox
    function propose(bytes calldata, /*_lookahead*/ bytes calldata _data) external nonReentrant {
        Config memory config = getConfig();

        // Validate proposer
        IProposerChecker(config.proposerChecker).checkProposer(msg.sender);

        // Decode and validate input data
        (
            uint64 deadline,
            CoreState memory coreState,
            Proposal[] memory proposals,
            LibBlobs.BlobReference memory blobReference,
            ClaimRecord[] memory claimRecords
        ) = decodeProposeData(_data);

        _validateProposeInputs(deadline, coreState, proposals);

        // Validate proposals against storage
        _checkProposalHash(config, proposals[0]);
        _verifyLastProposal(config, proposals);

        // Finalize proved proposals to make room for new ones
        coreState = _finalize(config, coreState, claimRecords);

        // Verify capacity for new proposals
        _verifyCapacity(config, coreState);

        // Process forced inclusion if required
        coreState = _processForcedInclusion(config, coreState);

        // Create regular proposal
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(blobReference);
        _propose(config, coreState, blobSlice, false);
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        Config memory config = getConfig();

        // Decode and validate input
        (Proposal[] memory proposals, Claim[] memory claims) = decodeProveData(_data);
        _validateProveInputs(proposals, claims);

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
        ProposalRecord storage proposalRecord = _proposalRecord(config, _proposalId);
        proposalHash_ = proposalRecord.proposalHash;
    }

    /// @notice Gets the claim record hash for a given proposal and parent claim.
    /// @param _proposalId The proposal ID to look up.
    /// @param _parentClaimHash The parent claim hash to look up.
    /// @return claimRecordHash_ The claim record hash, or bytes32(0) if not found.
    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        public
        view
        returns (bytes32 claimRecordHash_)
    {
        Config memory config = getConfig();
        return _getClaimRecordHash(config, _proposalId, _parentClaimHash);
    }

    /// @notice Gets the capacity for unfinalized proposals.
    /// @return _ The maximum number of unfinalized proposals that can exist.
    function getCapacity() public view returns (uint256) {
        Config memory config = getConfig();
        return _getCapacity(config);
    }

    /// @notice Gets the configuration for this Inbox contract
    /// @dev This function must be overridden by subcontracts to provide their specific
    /// configuration
    /// @return _ The configuration struct
    function getConfig() public view virtual returns (Config memory);

    /// @notice Decodes data into CoreState, BlobReference array, and ClaimRecord array
    /// @param _data The encoded data
    /// @return deadline_ The decoded deadline
    /// @return coreState_ The decoded CoreState
    /// @return proposals_ The decoded array of Proposals
    /// @return blobReference_ The decoded BlobReference
    /// @return claimRecords_ The decoded array of ClaimRecords
    function decodeProposeData(bytes calldata _data)
        public
        pure
        virtual
        returns (
            uint64 deadline_,
            CoreState memory coreState_,
            Proposal[] memory proposals_,
            LibBlobs.BlobReference memory blobReference_,
            ClaimRecord[] memory claimRecords_
        )
    {
        (deadline_, coreState_, proposals_, blobReference_, claimRecords_) = abi.decode(
            _data, (uint64, CoreState, Proposal[], LibBlobs.BlobReference, ClaimRecord[])
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
    /// @param proposal The proposal to encode
    /// @param coreState The core state to encode
    /// @return The encoded data
    function encodeProposedEventData(
        Proposal memory proposal,
        CoreState memory coreState
    )
        public
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(proposal, coreState);
    }

    /// @dev Encodes the proved event data
    /// @param claimRecord The claim record to encode
    /// @return The encoded data
    function encodeProveEventData(ClaimRecord memory claimRecord)
        public
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(claimRecord);
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
            uint256 windowEnd = _proposal.originTimestamp + _config.provingWindow;

            // On-time proof - no bond instructions needed
            if (proofTimestamp <= windowEnd) {
                return new LibBonds.BondInstruction[](0);
            }

            // Late or very late proof - determine bond type and parties
            uint256 extendedWindowEnd = _proposal.originTimestamp + _config.extendedProvingWindow;
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
        _proposalRecord(_config, _proposalId).proposalHash = _proposalHash;
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
        ProposalRecord storage proposalRecord = _proposalRecord(_config, _proposalId);
        bytes32 compositeKey = _composeClaimKey(_proposalId, _parentClaimHash);
        proposalRecord.claimHashLookup[compositeKey].claimRecordHash = _claimRecordHash;
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
        ProposalRecord storage proposalRecord = _proposalRecord(_config, _proposalId);
        bytes32 compositeKey = _composeClaimKey(_proposalId, _parentClaimHash);
        claimRecordHash_ = proposalRecord.claimHashLookup[compositeKey].claimRecordHash;
    }

    /// @dev Checks if a proposal matches the stored hash and reverts if not.
    /// @param _config The configuration parameters.
    /// @param _proposal The proposal to check.
    function _checkProposalHash(
        Config memory _config,
        Proposal memory _proposal
    )
        internal
        view
        returns (bytes32)
    {
        bytes32 proposalHash = _hashProposal(_proposal);
        bytes32 storedHash = _proposalRecord(_config, _proposal.id).proposalHash;
        require(proposalHash == storedHash, ProposalHashMismatch());
        return proposalHash;
    }

    /// @dev Reads a proposal record from the ring buffer at the specified proposal ID.
    /// @param _config The configuration parameters.
    /// @param _proposalId The proposal ID to read.
    /// @return _ The proposal record at the calculated buffer slot.
    function _proposalRecord(
        Config memory _config,
        uint48 _proposalId
    )
        internal
        view
        returns (ProposalRecord storage)
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        return _proposalRingBuffer[bufferSlot];
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Validates the basic inputs for propose function
    /// @param _deadline The deadline for the proposal.
    /// @param _coreState The core state.
    /// @param _proposals The proposals array.
    function _validateProposeInputs(
        uint64 _deadline,
        CoreState memory _coreState,
        Proposal[] memory _proposals
    )
        private
        view
    {
        require(_deadline == 0 || block.timestamp <= _deadline, DeadlineExceeded());
        require(_proposals.length > 0, EmptyProposals());
        require(_hashCoreState(_coreState) == _proposals[0].coreStateHash, InvalidState());
    }

    /// @dev Verifies that new proposals won't exceed capacity
    /// @param _config The configuration parameters.
    /// @param _coreState The core state.
    function _verifyCapacity(Config memory _config, CoreState memory _coreState) private pure {
        require(
            _coreState.nextProposalId <= _getCapacity(_config) + _coreState.lastFinalizedProposalId,
            ExceedsUnfinalizedProposalCapacity()
        );
    }

    /// @dev Processes forced inclusion if required
    /// @param _config The configuration parameters.
    /// @param _coreState The core state.
    /// @return The updated core state.
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

    /// @dev Validates the inputs for prove function
    /// @param _proposals The proposals to prove.
    /// @param _claims The claims for the proposals.
    function _validateProveInputs(
        Proposal[] memory _proposals,
        Claim[] memory _claims
    )
        private
        pure
    {
        require(_proposals.length == _claims.length, InconsistentParams());
        require(_proposals.length != 0, EmptyProposals());
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

    /// @dev Verifies the proposal is the last one proposed
    /// @param _config The configuration parameters.
    /// @param _proposals The proposals array to verify.
    function _verifyLastProposal(
        Config memory _config,
        Proposal[] memory _proposals
    )
        private
        view
    {
        bytes32 storedNextProposalHash = _proposalRecord(_config, _proposals[0].id + 1).proposalHash;

        if (storedNextProposalHash == bytes32(0)) {
            // Next slot is empty, only one proposal expected
            require(_proposals.length == 1, IncorrectProposalCount());
        } else {
            // Next slot is occupied, need to prove it contains a smaller proposal id
            require(_proposals.length == 2, IncorrectProposalCount());
            require(_proposals[1].id < _proposals[0].id, NextProposalIdSmallerThanLastProposalId());
            _checkProposalHash(_config, _proposals[1]);
        }
    }

    /// @dev Proposes a new proposal of L2 blocks.
    /// @param _config The configuration parameters.
    /// @param _coreState The core state of the inbox.
    /// @param _blobSlice The blob slice of the proposal.
    /// @param _isForcedInclusion Whether the proposal is a forced inclusion.
    /// @return  _ The updated core state.
    function _propose(
        Config memory _config,
        CoreState memory _coreState,
        LibBlobs.BlobSlice memory _blobSlice,
        bool _isForcedInclusion
    )
        private
        returns (CoreState memory)
    {
        Proposal memory proposal = Proposal({
            id: _coreState.nextProposalId++,
            proposer: msg.sender,
            originTimestamp: uint48(block.timestamp),
            originBlockNumber: uint48(block.number),
            isForcedInclusion: _isForcedInclusion,
            basefeeSharingPctg: _config.basefeeSharingPctg,
            blobSlice: _blobSlice,
            coreStateHash: _hashCoreState(_coreState)
        });

        _setProposalHash(_config, proposal.id, _hashProposal(proposal));
        emit Proposed(encodeProposedEventData(proposal, _coreState));

        return _coreState;
    }

    /// @dev Finalizes proposals by verifying claim records and updating state.
    /// @param _config The configuration parameters.
    /// @param _coreState The current core state.
    /// @param _claimRecords The claim records to finalize.
    /// @return coreState_ The updated core state
    function _finalize(
        Config memory _config,
        CoreState memory _coreState,
        ClaimRecord[] memory _claimRecords
    )
        private
        returns (CoreState memory coreState_)
    {
        ClaimRecord memory lastFinalizedRecord;
        uint48 currentProposalId = _coreState.lastFinalizedProposalId + 1;
        uint256 finalizedCount;

        for (uint256 i; i < _config.maxFinalizationCount; ++i) {
            // Check if there are more proposals to finalize
            if (currentProposalId >= _coreState.nextProposalId) break;

            // Try to finalize the current proposal
            (bool finalized, uint48 nextProposalId) = _finalizeProposal(
                _config,
                _coreState,
                currentProposalId,
                i < _claimRecords.length ? _claimRecords[i] : lastFinalizedRecord,
                i < _claimRecords.length
            );

            if (!finalized) break;

            // Update state for successful finalization
            lastFinalizedRecord = _claimRecords[i];
            currentProposalId = nextProposalId;
            finalizedCount++;
        }

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

    /// @dev Attempts to finalize a single proposal
    /// @param _config The configuration parameters.
    /// @param _coreState The core state to update.
    /// @param _proposalId The proposal ID to finalize.
    /// @param _claimRecord The claim record for this proposal.
    /// @param _hasClaimRecord Whether a claim record was provided.
    /// @return finalized_ Whether the proposal was successfully finalized.
    /// @return nextProposalId_ The next proposal ID to process.
    function _finalizeProposal(
        Config memory _config,
        CoreState memory _coreState,
        uint48 _proposalId,
        ClaimRecord memory _claimRecord,
        bool _hasClaimRecord
    )
        private
        returns (bool finalized_, uint48 nextProposalId_)
    {
        // Check if claim record exists in storage
        bytes32 storedHash =
            _getClaimRecordHash(_config, _proposalId, _coreState.lastFinalizedClaimHash);

        if (storedHash == 0) return (false, _proposalId);

        // Verify claim record was provided
        require(_hasClaimRecord, ClaimRecordNotProvided());

        // Verify claim record hash matches
        bytes32 claimRecordHash = _hashClaimRecord(_claimRecord);
        require(claimRecordHash == storedHash, ClaimRecordHashMismatchWithStorage());

        // Update core state
        _coreState.lastFinalizedProposalId = _proposalId;
        _coreState.lastFinalizedClaimHash = _hashClaim(_claimRecord.claim);

        // Process bond instructions
        _processBondInstructions(_coreState, _claimRecord.bondInstructions);

        // Validate and calculate next proposal ID
        require(_claimRecord.span > 0, InvalidSpan());
        nextProposalId_ = _proposalId + _claimRecord.span;
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
error ClaimRecordNotProvided();
error DeadlineExceeded();
error EmptyProposals();
error ExceedsUnfinalizedProposalCapacity();
error ForkNotActive();
error IncorrectProposalCount();
error InconsistentParams();
error InsufficientBond();
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
