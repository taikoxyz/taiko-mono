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
/// @notice Core contract for managing L2 proposals, proofs, and verification in Taiko's based
/// rollup architecture.
/// @dev This abstract contract implements the fundamental inbox logic including:
///      - Proposal submission with forced inclusion support
///      - Proof verification with claim record management
///      - Ring buffer storage for efficient state management
///      - Bond instruction processing for economic security
///      - Finalization of proven proposals
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
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Ring buffer for storing proposal hashes indexed by buffer slot
    /// @notice Reuses the `batches` slot from Pacaya fork for storage efficiency
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - proposalHash: The keccak256 hash of the Proposal struct
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev This variable is no longer used.
    mapping(uint256 bufferSlot => mapping(bytes32 parentHash => uint24 transitionId)) private
        __transitionIdsPacaya;

    /// @dev Ring buffer for storing claim record hashes with composite key indexing
    /// @notice Stores claim records for proposals with different parent claims
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - compositeKey: Keccak256 hash of (proposalId, parentClaimHash)
    /// - claimRecordHash: The hash of the ClaimRecord struct
    mapping(uint256 bufferSlot => mapping(bytes32 compositeKey => bytes32 claimRecordHash)) internal
        _claimRecordHashes;

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
    /// @notice Proposes new L2 blocks to the rollup
    /// @dev Key behaviors:
    ///      1. Validates proposer authorization via ProposerChecker
    ///      2. Finalizes eligible proposals to free ring buffer space
    ///      3. Processes forced inclusions if due (oldest first)
    ///      4. Submits regular proposal if capacity available
    ///      5. Updates core state and emits Proposed event
    /// @dev Forced inclusion processing:
    ///      - Processes exactly one (oldest) forced inclusion per call
    ///      - Only processed when due, cannot be processed early
    ///      - Takes priority over regular proposals
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

        _validateProposeInput(input);

        // Verify parentProposals[0] is actually the last proposal stored on-chain.
        _verifyChainHead(config, input.parentProposals);

        // IMPORTANT: Finalize first to free ring buffer space and prevent deadlock
        CoreState memory coreState = _finalize(config, input);

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
    /// @notice Proves the validity of proposed L2 blocks
    /// @dev Validates claims, calculates bond instructions, and verifies proofs
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        Config memory config = getConfig();

        // Decode and validate input
        ProveInput memory input = decodeProveInput(_data);
        require(input.proposals.length != 0, EmptyProposals());
        require(input.proposals.length == input.claims.length, InconsistentParams());

        // Build claim records with validation and bond calculations
        _buildAndSaveClaimRecords(config, input);

        // Verify the proof
        IProofVerifier(config.proofVerifier).verifyProof(_hashClaimsArray(input.claims), _proof);
    }

    /// @notice Withdraws bond balance to specified address
    /// @dev Legacy function for withdrawing bonds from Pacaya fork
    /// @dev Bonds are now managed on L2 by the BondManager contract
    /// @param _address The recipient address for the bond withdrawal
    function withdrawBond(address _address) external nonReentrant {
        uint256 amount = bondBalance[_address];
        require(amount > 0, NoBondToWithdraw());
        // Clear balance before transfer (checks-effects-interactions)
        bondBalance[_address] = 0;
        // Transfer the bond
        IERC20(getConfig().bondToken).safeTransfer(_address, amount);
        emit BondWithdrawn(_address, amount);
    }

    /// @notice Retrieves the proposal hash for a given proposal ID
    /// @param _proposalId The ID of the proposal to query
    /// @return proposalHash_ The keccak256 hash of the Proposal struct at the ring buffer slot
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_) {
        Config memory config = getConfig();
        uint256 bufferSlot = _proposalId % config.ringBufferSize;
        proposalHash_ = _proposalHashes[bufferSlot];
    }

    /// @notice Retrieves the claim record hash for a specific proposal and parent claim
    /// @param _proposalId The ID of the proposal containing the claim
    /// @param _parentClaimHash The hash of the parent claim in the proof chain
    /// @return claimRecordHash_ The keccak256 hash of the ClaimRecord, or bytes32(0) if not found
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

    /// @notice Returns the maximum capacity for unfinalized proposals
    /// @dev Capacity is ringBufferSize - 1 to prevent overwriting unfinalized proposals
    /// @return _ The maximum number of unfinalized proposals allowed
    function getCapacity() external view returns (uint256) {
        Config memory config = getConfig();
        return _getCapacity(config);
    }

    /// @notice Returns the configuration parameters for this Inbox instance
    /// @dev Must be overridden by concrete implementations to provide specific configuration
    /// @return _ The Config struct containing all configuration parameters
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

    /// @dev Builds and persists claim records for batch proof submissions
    /// @notice Validates claims, calculates bond instructions, and stores records
    /// @dev Virtual function that can be overridden for optimization (e.g., claim aggregation)
    /// @param _config The configuration parameters for validation and storage
    /// @param _input The ProveInput containing arrays of proposals and corresponding claims
    function _buildAndSaveClaimRecords(
        Config memory _config,
        ProveInput memory _input
    )
        internal
        virtual
    {
        // Declare struct instance outside the loop to avoid repeated memory allocations
        ClaimRecord memory claimRecord;
        claimRecord.span = 1;

        for (uint256 i; i < _input.proposals.length; ++i) {
            _validateClaim(_config, _input.proposals[i], _input.claims[i]);

            // Reuse the same memory location for the claimRecord struct
            claimRecord.bondInstructions =
                _calculateBondInstructions(_config, _input.proposals[i], _input.claims[i]);
            claimRecord.claimHash = _hashClaim(_input.claims[i]);
            claimRecord.endBlockMiniHeaderHash =
                _hashBlockMiniHeader(_input.claims[i].endBlockMiniHeader);

            // Pass claim and claimRecord to _setClaimRecordHash which will emit the event
            _setClaimRecordHash(_config, _input.proposals[i].id, _input.claims[i], claimRecord);
        }
    }

    /// @dev Retrieves the hash of a blob at the specified index
    /// @notice Uses EIP-4844 blobhash opcode to access blob data
    /// @dev Virtual to allow test contracts to mock blob hash retrieval
    /// @param _blobIndex The index of the blob in the transaction
    /// @return _ The versioned hash of the blob
    function _getBlobHash(uint256 _blobIndex) internal view virtual returns (bytes32) {
        return blobhash(_blobIndex);
    }

    /// @dev Validates claim consistency with its corresponding proposal
    /// @notice Ensures the claim references the correct proposal hash
    /// @param _config The configuration parameters for validation
    /// @param _proposal The proposal being proven
    /// @param _claim The claim to validate against the proposal
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

    /// @dev Calculates bond instructions based on proof timing and prover identity
    /// @notice Bond instruction rules:
    ///         - On-time (within provingWindow): No bond changes
    ///         - Late (within extendedProvingWindow): Liveness bond transfer if prover differs from
    /// designated
    ///         - Very late (after extendedProvingWindow): Provability bond transfer if prover
    /// differs from proposer
    /// @dev Bond instructions affect claim aggregation eligibility - claims with instructions
    /// cannot be aggregated
    /// @param _config Configuration containing timing windows
    /// @param _proposal Proposal with timestamp and proposer address
    /// @param _claim Claim with designated and actual prover addresses
    /// @return bondInstructions_ Array of bond transfer instructions (empty if on-time or same
    /// prover)
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

    /// @dev Stores a proposal hash in the ring buffer
    /// @notice Overwrites any existing hash at the calculated buffer slot
    function _setProposalHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _proposalHash
    )
        internal
    {
        _proposalHashes[_proposalId % _config.ringBufferSize] = _proposalHash;
    }

    /// @dev Stores claim record hash and emits Proved event
    /// @notice Virtual function to allow optimization in derived contracts
    /// @dev Calculates composite key for unique claim identification
    /// @param _config Configuration containing ring buffer size
    /// @param _proposalId The ID of the proposal being proven
    /// @param _claim The claim data to include in the event
    /// @param _claimRecord The claim record to hash and store
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
        _claimRecordHashes[bufferSlot][compositeKey] = claimRecordHash;

        bytes memory payload = encodeProvedEventData(
            ProvedEventPayload({ proposalId: _proposalId, claim: _claim, claimRecord: _claimRecord })
        );
        emit Proved(payload);
    }

    /// @dev Calculates the maximum number of unfinalized proposals
    /// @notice Returns ringBufferSize - 1 to ensure one slot always remains free
    function _getCapacity(Config memory _config) internal pure returns (uint256) {
        // The ring buffer can hold ringBufferSize proposals total, but we need to ensure
        // unfinalized proposals are not overwritten. Therefore, the maximum number of
        // unfinalized proposals is ringBufferSize - 1.
        unchecked {
            return _config.ringBufferSize - 1;
        }
    }

    /// @dev Retrieves claim record hash from storage
    /// @notice Virtual to allow optimization strategies in derived contracts
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
        claimRecordHash_ = _claimRecordHashes[bufferSlot][compositeKey];
    }

    /// @dev Validates proposal hash against stored value
    /// @notice Reverts with ProposalHashMismatch if hashes don't match
    /// @param _config Configuration containing ring buffer size
    /// @param _proposal The proposal to validate
    /// @return proposalHash_ The computed hash of the proposal
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

    /// @dev Calculates remaining capacity for new proposals
    /// @notice Subtracts unfinalized proposals from total capacity
    /// @param _config Configuration containing ring buffer size
    /// @param _coreState Current state with proposal counters
    /// @return _ Number of additional proposals that can be submitted
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

    /// @dev Validates propose function inputs
    /// @notice Checks deadline, proposal array, and state consistency
    /// @param _input The ProposeInput to validate
    function _validateProposeInput(ProposeInput memory _input) private view {
        require(_input.deadline == 0 || block.timestamp <= _input.deadline, DeadlineExceeded());
        require(_input.parentProposals.length > 0, EmptyProposals());
        require(
            _hashCoreState(_input.coreState) == _input.parentProposals[0].coreStateHash,
            InvalidState()
        );
    }

    /// @dev Attempts to process a forced inclusion from the ForcedInclusionStore
    /// @notice Uses low-level call to handle potential failures gracefully
    /// @param _config Configuration containing forced inclusion store address
    /// @param _coreState Current core state to update if inclusion processed
    /// @return coreState_ Updated state if forced inclusion processed, unchanged otherwise
    /// @return forcedInclusionProcessed_ True if a forced inclusion was successfully processed
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

    /// @dev Verifies that parentProposals[0] is the current chain head
    /// @notice Requires 1 element if next slot empty, 2 if occupied with older proposal
    /// @param _config Configuration containing ring buffer size
    /// @param _parentProposals Array of 1-2 proposals to verify chain head
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

    /// @dev Creates and stores a new proposal
    /// @notice Increments nextProposalId and emits Proposed event
    /// @param _config Configuration with basefee sharing percentage
    /// @param _coreState Current state whose hash is stored in the proposal
    /// @param _blobSlice Blob data slice containing L2 transactions
    /// @param _isForcedInclusion True if this is a forced inclusion proposal
    /// @return Updated core state with incremented nextProposalId
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

    /// @dev Finalizes proven proposals and updates synced block
    /// @notice Processes up to maxFinalizationCount proposals in sequence
    /// @dev Stops at first missing claim record or span boundary
    /// @param _config Configuration with finalization parameters
    /// @param _input Input containing claim records and end block header
    /// @return _ Core state with updated finalization counters
    function _finalize(
        Config memory _config,
        ProposeInput memory _input
    )
        private
        returns (CoreState memory)
    {
        CoreState memory coreState = _input.coreState;
        ClaimRecord memory lastFinalizedRecord;
        uint48 proposalId = coreState.lastFinalizedProposalId + 1;
        uint256 finalizedCount;

        for (uint256 i; i < _config.maxFinalizationCount; ++i) {
            // Check if there are more proposals to finalize
            if (proposalId >= coreState.nextProposalId) break;

            // Try to finalize the current proposal
            bool finalized;
            (finalized, proposalId) = _finalizeProposal(
                _config,
                coreState,
                proposalId,
                i < _input.claimRecords.length ? _input.claimRecords[i] : lastFinalizedRecord,
                i < _input.claimRecords.length
            );

            if (!finalized) break;

            // Update state for successful finalization
            lastFinalizedRecord = _input.claimRecords[i];
            finalizedCount++;
        }

        // Update synced block if any proposals were finalized
        if (finalizedCount > 0) {
            bytes32 endBlockMiniHeaderHash = _hashBlockMiniHeader(_input.endBlockMiniHeader);
            require(
                endBlockMiniHeaderHash == lastFinalizedRecord.endBlockMiniHeaderHash,
                EndBlockMiniHeaderMismatch()
            );
            ISyncedBlockManager(_config.syncedBlockManager).saveSyncedBlock(
                _input.endBlockMiniHeader.number,
                _input.endBlockMiniHeader.hash,
                _input.endBlockMiniHeader.stateRoot
            );
        }

        return coreState;
    }

    /// @dev Attempts to finalize a single proposal
    /// @notice Updates core state and processes bond instructions if successful
    /// @param _config Configuration for claim record retrieval
    /// @param _coreState Core state to update (passed by reference)
    /// @param _proposalId The ID of the proposal to finalize
    /// @param _claimRecord The expected claim record for verification
    /// @param _hasClaimRecord Whether a claim record was provided in input
    /// @return finalized_ True if proposal was successfully finalized
    /// @return nextProposalId_ Next proposal ID to process (current + span)
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

    /// @dev Processes bond instructions and updates aggregated hash
    /// @notice Emits BondInstructed event for L2 bond manager processing
    /// @param _coreState Core state with bond instructions hash to update
    /// @param _instructions Array of bond transfer instructions to aggregate
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

    /// @dev Computes composite key for claim record storage
    /// @notice Creates unique identifier for proposal-parent claim pairs
    /// @param _proposalId The ID of the proposal
    /// @param _parentClaimHash Hash of the parent claim
    /// @return _ Keccak256 hash of encoded parameters
    function _composeClaimKey(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        internal
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
