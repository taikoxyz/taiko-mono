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

        Claim memory claim;
        claim.endBlockMiniHeader.hash = _genesisBlockHash;

        CoreState memory coreState;
        coreState.nextProposalId = 1;
        coreState.lastFinalizedClaimHash = _hashClaim(claim);

        Proposal memory proposal;
        proposal.coreStateHash = _hashCoreState(coreState);

        Derivation memory derivation;
        proposal.derivationHash = _hashDerivation(derivation);

        _setProposalHash(getConfig(), 0, _hashProposal(proposal));
        emit Proposed(
            encodeProposedEventData(
                ProposedEventPayload({
                    proposal: proposal,
                    derivation: derivation,
                    coreState: coreState
                })
            )
        );
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
        ProposeInput memory input = decodeProposeInput(_data);

        _validateProposeInputs(input.deadline, input.coreState, input.parentProposals);

        // Verify parentProposals[0] is actually the last proposal stored on-chain.
        _verifyChainHead(config, input.parentProposals);

        // IMPORTANT: Finalize first to free ring buffer space and prevent deadlock
        CoreState memory coreState =
            _finalize(config, input.coreState, input.claimRecords, input.endBlockMiniHeader);

        // Verify capacity for new proposals
        uint256 availableCapacity = _getAvailableCapacity(config, coreState);
        require(availableCapacity > 0, ExceedsUnfinalizedProposalCapacity());

        // Process forced inclusion if required
        bool forcedInclusionProcessed;
        (coreState, forcedInclusionProcessed) = _processForcedInclusion(config, coreState);

        if (!forcedInclusionProcessed || availableCapacity > 1) {
            // Propose the normal proposal after the potential forced inclusion to match the
            // behavior in Shasta fork.
            LibBlobs.BlobSlice memory blobSlice =
                LibBlobs.validateBlobReference(input.blobReference, _getBlobHash);
            _propose(config, coreState, blobSlice, false);
        }
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        Config memory config = getConfig();

        // Decode and validate input
        ProveInput memory input = decodeProveInput(_data);
        require(input.proposals.length != 0, EmptyProposals());
        require(input.proposals.length == input.claims.length, InconsistentParams());

        // Build claim records with validation and bond calculations
        _buildAndSaveClaimRecords(config, input.proposals, input.claims);

        // Verify the proof
        IProofVerifier(config.proofVerifier).verifyProof(_hashClaimsArray(input.claims), _proof);
    }

    /// @notice Withdraws bond balance to `_address`.
    /// @dev This function allows deposits that were made on Pacaya to be withdrawn.
    /// @param _address The address to withdraw the bond to
    function withdrawBond(address _address) external nonReentrant {
        uint256 amount = bondBalance[_address];
        require(amount > 0, NoBondToWithdraw());
        // Clear balance before transfer (checks-effects-interactions)
        bondBalance[_address] = 0;
        // Transfer the bond
        IERC20(getConfig().bondToken).safeTransfer(_address, amount);
        emit BondWithdrawn(_address, amount);
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

    /// @notice Decodes proposal input data
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput struct containing all proposal data
    function decodeProposeInput(bytes calldata _data)
        public
        pure
        virtual
        returns (ProposeInput memory input_)
    {
        input_ = abi.decode(_data, (ProposeInput));
    }

    /// @notice Decodes prove input data
    /// @param _data The encoded data
    /// @return _ The decoded ProveInput struct containing proposals and claims
    function decodeProveInput(bytes calldata _data)
        public
        pure
        virtual
        returns (ProveInput memory)
    {
        return abi.decode(_data, (ProveInput));
    }

    /// @dev Encodes the proposed event data
    /// @param _payload The ProposedEventPayload object
    /// @return The encoded data
    function encodeProposedEventData(ProposedEventPayload memory _payload)
        public
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(_payload);
    }

    /// @dev Encodes the proved event data
    /// @param _payload The ProvedEventPayload object
    /// @return The encoded data
    function encodeProvedEventData(ProvedEventPayload memory _payload)
        public
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(_payload);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Builds then saves claim records for multiple proposals and claims.
    /// @param _config The configuration parameters.
    /// @param _proposals The proposals to prove.
    /// @param _claims The claims containing the proof details.
    function _buildAndSaveClaimRecords(
        Config memory _config,
        Proposal[] memory _proposals,
        Claim[] memory _claims
    )
        internal
        virtual
    {
        // Declare struct instances outside the loop to avoid repeated memory allocations
        ClaimRecord memory claimRecord;
        Proposal memory proposal;
        Claim memory claim;
        claimRecord.span = 1;

        for (uint256 i; i < _proposals.length; ++i) {
            proposal = _proposals[i];
            claim = _claims[i];

            _validateClaim(_config, proposal, claim);

            // Reuse the same memory location for the claimRecord struct
            claimRecord.bondInstructions = _calculateBondInstructions(_config, proposal, claim);
            claimRecord.claimHash = _hashClaim(claim);
            claimRecord.endBlockMiniHeaderHash = _hashBlockMiniHeader(claim.endBlockMiniHeader);

            // Pass claim and claimRecord to _setClaimRecordHash which will emit the event
            _setClaimRecordHash(_config, proposal.id, claim, claimRecord);
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
        virtual
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

    /// @dev Sets the claim record hash for a given proposal and parent claim, and emits the Proved
    /// event.
    /// @param _config The configuration parameters.
    /// @param _proposalId The proposal ID.
    /// @param _claim The claim data for the event.
    /// @param _claimRecord The claim record data for the event.
    function _setClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        Claim memory _claim,
        ClaimRecord memory _claimRecord
    )
        internal
        virtual
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        bytes32 compositeKey = _composeClaimKey(_proposalId, _claim.parentClaimHash);
        bytes32 claimRecordHash = _hashClaimRecord(_claimRecord);
        _claimHashLookup[bufferSlot][compositeKey].claimRecordHash = claimRecordHash;

        bytes memory payload = encodeProvedEventData(
            ProvedEventPayload({ proposalId: _proposalId, claim: _claim, claimRecord: _claimRecord })
        );
        emit Proved(payload);
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

    /// @dev Hashes a Claim struct.
    /// @param _claim The claim to hash.
    /// @return _ The hash of the claim.
    function _hashClaim(Claim memory _claim) internal pure returns (bytes32) {
        return keccak256(abi.encode(_claim));
    }

    /// @dev Hashes a ClaimRecord struct.
    /// @param _claimRecord The claim record to hash.
    /// @return _ The hash of the claim record.
    function _hashClaimRecord(ClaimRecord memory _claimRecord) internal pure returns (bytes32) {
        return keccak256(abi.encode(_claimRecord));
    }

    /// @dev Hashes a BlockMiniHeader struct.
    /// @param _header The block mini header to hash.
    /// @return _ The hash of the block mini header.
    function _hashBlockMiniHeader(BlockMiniHeader memory _header) internal pure returns (bytes32) {
        return keccak256(abi.encode(_header));
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

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
    /// @return coreState_ The updated core state or the same core state if no forced inclusion is
    /// due.
    /// @return forcedInclusionProcessed_ True if a forced inclusion is processed.
    function _processForcedInclusion(
        Config memory _config,
        CoreState memory _coreState
    )
        private
        returns (CoreState memory coreState_, bool forcedInclusionProcessed_)
    {
        // Use low-level call to handle potential errors gracefully
        (bool success, bytes memory returnData) = _config.forcedInclusionStore.call(
            abi.encodeCall(IForcedInclusionStore.consumeOldestForcedInclusion, (msg.sender))
        );

        // If the call fails, return _coreState as is
        if (!success) {
            return (_coreState, false);
        }

        // Decode the returned ForcedInclusion struct
        IForcedInclusionStore.ForcedInclusion memory forcedInclusion =
            abi.decode(returnData, (IForcedInclusionStore.ForcedInclusion));

        coreState_ = _propose(_config, _coreState, forcedInclusion.blobSlice, true);
    }

    /// @dev Verifies that parentProposals[0] is the chain head (last proposal)
    /// @param _config The configuration parameters.
    /// @param _parentProposals The parent proposals array to verify (1-2 elements).
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

        if (storedNextProposalHash == bytes32(0)) {
            // Next slot in the ring buffer is empty, only one proposal expected
            require(_parentProposals.length == 1, IncorrectProposalCount());
        } else {
            // Next slot in the ring buffer is occupied, need to prove it contains a
            // proposal with a smaller id
            require(_parentProposals.length == 2, IncorrectProposalCount());
            require(
                _parentProposals[1].id < _parentProposals[0].id,
                NextProposalIdSmallerThanLastProposalId()
            );
            require(
                storedNextProposalHash == _hashProposal(_parentProposals[1]),
                NextProposalHashMismatch()
            );
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
            bytes memory payload = encodeProposedEventData(
                ProposedEventPayload({
                    proposal: proposal,
                    derivation: derivation,
                    coreState: _coreState
                })
            );
            emit Proposed(payload);

            return _coreState;
        }
    }

    /// @dev Finalizes proposals by verifying claim records and updating state.
    /// @param _config The configuration parameters.
    /// @param _coreState The current core state.
    /// @param _claimRecords The claim records to finalize.
    /// @return _ The updated core state
    function _finalize(
        Config memory _config,
        CoreState memory _coreState,
        ClaimRecord[] memory _claimRecords,
        BlockMiniHeader memory _endBlockMiniHeader
    )
        private
        returns (CoreState memory)
    {
        ClaimRecord memory lastFinalizedRecord;
        uint48 proposalId = _coreState.lastFinalizedProposalId + 1;
        uint256 finalizedCount;

        for (uint256 i; i < _config.maxFinalizationCount; ++i) {
            // Check if there are more proposals to finalize
            if (proposalId >= _coreState.nextProposalId) break;

            // Try to finalize the current proposal
            bool finalized;
            (finalized, proposalId) = _finalizeProposal(
                _config,
                _coreState,
                proposalId,
                i < _claimRecords.length ? _claimRecords[i] : lastFinalizedRecord,
                i < _claimRecords.length
            );

            if (!finalized) break;

            // Update state for successful finalization
            lastFinalizedRecord = _claimRecords[i];
            finalizedCount++;
        }

        // Update synced block if any proposals were finalized
        if (finalizedCount > 0) {
            bytes32 endBlockMiniHeaderHash = _hashBlockMiniHeader(_endBlockMiniHeader);
            require(
                endBlockMiniHeaderHash == lastFinalizedRecord.endBlockMiniHeaderHash,
                EndBlockMiniHeaderMismatch()
            );
            ISyncedBlockManager(_config.syncedBlockManager).saveSyncedBlock(
                _endBlockMiniHeader.number, _endBlockMiniHeader.hash, _endBlockMiniHeader.stateRoot
            );
        }

        return _coreState;
    }

    /// @dev Attempts to finalize a single proposal
    /// @param _config The configuration parameters.
    /// @param _coreState The core state, passed by reference, to update.
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

        // Reconstruct the BlockMiniHeader from the claim record hash
        // Note: We need to decode the endBlockMiniHeaderHash to get the actual header
        // For finalization, we create a claim with empty block header since we only have the hash
        _coreState.lastFinalizedClaimHash = _claimRecord.claimHash;

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

error ClaimRecordHashMismatchWithStorage();
error ClaimRecordNotProvided();
error DeadlineExceeded();
error EmptyProposals();
error EndBlockMiniHeaderMismatch();
error ExceedsUnfinalizedProposalCapacity();
error ForkNotActive();
error InconsistentParams();
error IncorrectProposalCount();
error InsufficientBond();
error InvalidSpan();
error InvalidState();
error LastProposalHashMismatch();
error LastProposalProofNotEmpty();
error NextProposalHashMismatch();
error NextProposalIdSmallerThanLastProposalId();
error NoBondToWithdraw();
error ProposalHashMismatch();
error ProposalHashMismatchWithClaim();
error ProposalHashMismatchWithStorage();
error ProposalIdMismatch();
error ProposerBondInsufficient();
error RingBufferSizeZero();
error SpanOutOfBounds();
error Unauthorized();
