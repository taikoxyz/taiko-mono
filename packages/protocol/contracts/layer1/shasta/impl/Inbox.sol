// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";

/// @title Inbox
/// @notice Core contract for managing L2 proposals, proofs,verification and forced inclusion in
/// Taiko's based
/// rollup architecture.
/// @dev This abstract contract implements the fundamental inbox logic including:
///      - Proposal submission with forced inclusion support
///      - Proof verification with transition record management
///      - Ring buffer storage for efficient state management
///      - Bond instruction processing for economic security
///      - Finalization of proven proposals
/// @custom:security-contact security@taiko.xyz
abstract contract Inbox is IInbox, IForcedInclusionStore, EssentialContract {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when bond is withdrawn from the contract
    /// @param user The user whose bond was withdrawn
    /// @param amount The amount of bond withdrawn
    event BondWithdrawn(address indexed user, uint256 amount);

    // ---------------------------------------------------------------
    // State Variables for compatibility with Pacaya inbox.
    // ---------------------------------------------------------------

    /// @dev Deprecated slots used by Pacaya inbox that contains:
    /// - `batches`
    /// - `transitionIds`
    /// - `transitions`
    /// - `__reserve1`
    /// - `stats1`
    /// - `stats2`
    uint256[6] private __slotsUsedByPacaya;

    /// @notice Bond balance for each account used in Pacaya inbox.
    /// @dev This is not used in Shasta. It is kept so users can withdraw their bond.
    /// @dev Bonds are now handled entirely on L2, by the `BondManager` contract.
    mapping(address account => uint256 bond) public bondBalance;

    // ---------------------------------------------------------------
    // State Variables for Shasta inbox.
    // ---------------------------------------------------------------

    /// @dev Ring buffer for storing proposal hashes indexed by buffer slot
    /// - bufferSlot: The ring buffer slot calculated as proposalId % ringBufferSize
    /// - proposalHash: The keccak256 hash of the Proposal struct
    /// @dev This variable does not reuse pacaya slots for storage safety, since we do buffer wrap
    /// around checks in the contract.
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev Simple mapping for storing transition record hashes
    /// @dev We do not use a ring buffer for this mapping, since a nested mapping does not benefit
    /// from it
    /// @dev Stores transition records for proposals with different parent transitions
    /// - compositeKey: Keccak256 hash of (proposalId, parentTransitionHash)
    /// - transitionRecordHash: The hash of the TransitionRecord struct
    mapping(bytes32 compositeKey => bytes32 transitionRecordHash) internal _transitionRecordHashes;

    /// @dev Storage for forced inclusion requests
    ///  Two slots used
    LibForcedInclusion.Storage internal _forcedInclusionStorage;

    uint256[39] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    constructor() EssentialContract() { }

    /// @notice Initializes the Inbox contract with genesis block
    /// @dev This contract uses a reinitializer so that it works both on fresh deployments as well
    /// as existing inbox proxies(i.e. mainnet)
    /// @dev IMPORTANT: Make sure this function is called in the same tx as the deployment or
    /// upgrade happens. On upgrades this is usually done calling `upgradeToAndCall`
    /// @param _owner The owner of this contract
    /// @param _genesisBlockHash The hash of the genesis block
    function initV3(address _owner, bytes32 _genesisBlockHash) external reinitializer(3) {
        address owner = owner();
        require(owner == address(0) || owner == msg.sender, ACCESS_DENIED());

        if (owner == address(0)) {
            __Essential_init(_owner);
        }
        _initializeInbox(_genesisBlockHash);
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInbox
    /// @notice Proposes new L2 blocks and forced inclusions to the rollup using blobs for DA.
    /// @dev Key behaviors:
    ///      1. Validates proposer authorization via ProposerChecker
    ///      2. Finalizes eligible proposals up to `config.maxFinalizationCount` to free ring buffer
    ///         space.
    ///      3. Process `input.numForcedInclusions` forced inclusions. The proposer is forced to
    ///         process at least `config.minForcedInclusionCount` if they are due.
    ///      4. Updates core state and emits `Proposed` event
    /// @dev IMPORTANT: The regular proposal might not be included if there is not enough capacity
    ///      available(i.e forced inclusions are prioritized).
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
        uint48 lookaheadSlotTimestamp =
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
        require(
            availableCapacity >= input.numForcedInclusions, ExceedsUnfinalizedProposalCapacity()
        );

        if (input.numForcedInclusions > 0) {
            // Process forced inclusion if required
            uint256 numForcedInclusionsProcessed;
            (coreState, numForcedInclusionsProcessed) = _processForcedInclusions(
                config, coreState, input.numForcedInclusions, lookaheadSlotTimestamp
            );

            availableCapacity -= numForcedInclusionsProcessed;
        }

        // Verify that at least `config.minForcedInclusionCount` forced inclusions were processed or
        // none remains in the queue that is due.
        require(
            input.numForcedInclusions >= config.minForcedInclusionCount
                || !LibForcedInclusion.isOldestForcedInclusionDue(_forcedInclusionStorage, config),
            UnprocessedForcedInclusionIsDue()
        );

        // Propose the normal proposal after the potential forced inclusions if there is capacity
        // available
        if (availableCapacity > 0) {
            LibBlobs.BlobSlice memory blobSlice =
                LibBlobs.validateBlobReference(input.blobReference);
            _propose(config, coreState, blobSlice, false, lookaheadSlotTimestamp);
        }
    }

    /// @inheritdoc IInbox
    /// @notice Proves the validity of proposed L2 blocks
    /// @dev Validates transitions, calculates bond instructions, and verifies proofs
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        Config memory config = getConfig();

        // Decode and validate input
        ProveInput memory input = decodeProveInput(_data);
        require(input.proposals.length != 0, EmptyProposals());
        require(input.proposals.length == input.transitions.length, InconsistentParams());

        // Build transition records with validation and bond calculations
        _buildAndSaveTransitionRecords(config, input);

        // Verify the proof
        IProofVerifier(config.proofVerifier).verifyProof(
            _hashTransitionsArray(input.transitions), _proof
        );
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

    /// @inheritdoc IForcedInclusionStore
    function storeForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable {
        LibForcedInclusion.storeForcedInclusion(
            _forcedInclusionStorage, getConfig(), _blobReference
        );
    }

    /// @inheritdoc IForcedInclusionStore
    function isOldestForcedInclusionDue() external view returns (bool) {
        return LibForcedInclusion.isOldestForcedInclusionDue(_forcedInclusionStorage, getConfig());
    }

    /// @notice Retrieves the proposal hash for a given proposal ID
    /// @param _proposalId The ID of the proposal to query
    /// @return proposalHash_ The keccak256 hash of the Proposal struct at the ring buffer slot
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_) {
        Config memory config = getConfig();
        uint256 bufferSlot = _proposalId % config.ringBufferSize;
        proposalHash_ = _proposalHashes[bufferSlot];
    }

    /// @notice Retrieves the transition record hash for a specific proposal and parent transition
    /// @param _proposalId The ID of the proposal containing the transition
    /// @param _parentTransitionHash The hash of the parent transition in the proof chain
    /// @return transitionRecordHash_ The keccak256 hash of the TransitionRecord, or bytes32(0) if
    /// not found
    function getTransitionRecordHash(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        external
        view
        returns (bytes32 transitionRecordHash_)
    {
        return _getTransitionRecordHash(_proposalId, _parentTransitionHash);
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
    /// @return _ The decoded ProveInput struct containing proposals and transitions
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

    /// @dev Encodes the propose input data
    /// @param _input The ProposeInput struct
    /// @return The encoded data
    function encodeProposeInput(ProposeInput memory _input)
        external
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(_input);
    }

    /// @dev Encodes the prove input data
    /// @param _input The ProveInput struct
    /// @return The encoded data
    function encodeProveInput(ProveInput memory _input)
        external
        pure
        virtual
        returns (bytes memory)
    {
        return abi.encode(_input);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Initializes the inbox with genesis state
    /// @notice Sets up the initial proposal and core state with genesis block
    /// @param _genesisBlockHash The hash of the genesis block
    function _initializeInbox(bytes32 _genesisBlockHash) internal {
        Transition memory transition;
        transition.checkpoint.blockHash = _genesisBlockHash;

        CoreState memory coreState;
        coreState.nextProposalId = 1;
        coreState.lastFinalizedTransitionHash = _hashTransition(transition);

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

    /// @dev Builds and persists transition records for batch proof submissions
    /// @notice Validates transitions, calculates bond instructions, and stores records
    /// @dev Virtual function that can be overridden for optimization (e.g., transition aggregation)
    /// @param _config The configuration parameters for validation and storage
    /// @param _input The ProveInput containing arrays of proposals and corresponding transitions
    function _buildAndSaveTransitionRecords(
        Config memory _config,
        ProveInput memory _input
    )
        internal
        virtual
    {
        // Declare struct instance outside the loop to avoid repeated memory allocations
        TransitionRecord memory transitionRecord;
        transitionRecord.span = 1;

        for (uint256 i; i < _input.proposals.length; ++i) {
            _validateTransition(_config, _input.proposals[i], _input.transitions[i]);

            // Reuse the same memory location for the transitionRecord struct
            transitionRecord.bondInstructions =
                _calculateBondInstructions(_config, _input.proposals[i], _input.transitions[i]);
            transitionRecord.effectiveAt = uint48(block.timestamp + _config.cooldownWindow);
            transitionRecord.transitionHash = _hashTransition(_input.transitions[i]);
            transitionRecord.checkpointHash = _hashCheckpoint(_input.transitions[i].checkpoint);

            // Pass transition and transitionRecord to _setTransitionRecordHash which will emit the
            // event
            _setTransitionRecordHash(
                _input.proposals[i].id, _input.transitions[i], transitionRecord
            );
        }
    }

    /// @dev Validates transition consistency with its corresponding proposal
    /// @notice Ensures the transition references the correct proposal hash
    /// @param _config The configuration parameters for validation
    /// @param _proposal The proposal being proven
    /// @param _transition The transition to validate against the proposal
    function _validateTransition(
        Config memory _config,
        Proposal memory _proposal,
        Transition memory _transition
    )
        internal
        view
    {
        bytes32 proposalHash = _checkProposalHash(_config, _proposal);
        require(proposalHash == _transition.proposalHash, ProposalHashMismatchWithTransition());
    }

    /// @dev Calculates bond instructions based on proof timing and prover identity
    /// @notice Bond instruction rules:
    ///         - On-time (within provingWindow): No bond changes
    ///         - Late (within extendedProvingWindow): Liveness bond transfer if prover differs from
    /// designated
    ///         - Very late (after extendedProvingWindow): Provability bond transfer if prover
    /// differs from proposer
    /// @dev Bond instructions affect transition aggregation eligibility - transitions with
    /// instructions
    /// cannot be aggregated
    /// @param _config Configuration containing timing windows
    /// @param _proposal Proposal with timestamp and proposer address
    /// @param _transition Transition with designated and actual prover addresses
    /// @return bondInstructions_ Array of bond transfer instructions (empty if on-time or same
    /// prover)
    function _calculateBondInstructions(
        Config memory _config,
        Proposal memory _proposal,
        Transition memory _transition
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
                ? (_transition.designatedProver != _transition.actualProver)
                : (_proposal.proposer != _transition.actualProver);

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
                payer: isWithinExtendedWindow ? _transition.designatedProver : _proposal.proposer,
                receiver: _transition.actualProver
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

    /// @dev Stores transition record hash and emits Proved event
    /// @notice Virtual function to allow optimization in derived contracts
    /// @dev Uses composite key for unique transition identification
    /// @param _proposalId The ID of the proposal being proven
    /// @param _transition The transition data to include in the event
    /// @param _transitionRecord The transition record to hash and store
    function _setTransitionRecordHash(
        uint48 _proposalId,
        Transition memory _transition,
        TransitionRecord memory _transitionRecord
    )
        internal
        virtual
    {
        bytes32 compositeKey = _composeTransitionKey(_proposalId, _transition.parentTransitionHash);
        bytes32 transitionRecordHash = _hashTransitionRecord(_transitionRecord);

        bytes32 storedTransitionRecordHash = _transitionRecordHashes[compositeKey];
        if (storedTransitionRecordHash == transitionRecordHash) return;

        require(storedTransitionRecordHash == 0, TransitionWithSameParentHashAlreadyProved());
        _transitionRecordHashes[compositeKey] = transitionRecordHash;

        bytes memory payload = encodeProvedEventData(
            ProvedEventPayload({
                proposalId: _proposalId,
                transition: _transition,
                transitionRecord: _transitionRecord
            })
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

    /// @dev Retrieves transition record hash from storage
    /// @notice Virtual to allow optimization strategies in derived contracts
    /// @param _proposalId The ID of the proposal
    /// @param _parentTransitionHash The hash of the parent transition
    /// @return transitionRecordHash_ The stored transition record hash
    function _getTransitionRecordHash(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        virtual
        returns (bytes32 transitionRecordHash_)
    {
        bytes32 compositeKey = _composeTransitionKey(_proposalId, _parentTransitionHash);
        transitionRecordHash_ = _transitionRecordHashes[compositeKey];
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

    /// @dev Hashes a Transition struct.
    /// @param _transition The transition to hash.
    /// @return _ The hash of the transition.
    function _hashTransition(Transition memory _transition) internal pure returns (bytes32) {
        return keccak256(abi.encode(_transition));
    }

    /// @dev Hashes a TransitionRecord struct.
    /// @param _transitionRecord The transition record to hash.
    /// @return _ The hash of the transition record.
    function _hashTransitionRecord(TransitionRecord memory _transitionRecord)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_transitionRecord));
    }

    /// @dev Hashes a Checkpoint struct.
    /// @param _checkpoint The checkpoint to hash.
    /// @return _ The hash of the checkpoint.
    function _hashCheckpoint(ICheckpointManager.Checkpoint memory _checkpoint)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_checkpoint));
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

    /// @dev Processes multiple forced inclusions from the ForcedInclusionStore
    /// @notice Consumes up to _numForcedInclusions from the queue and proposes them sequentially
    /// @param _config Configuration containing forced inclusion store address
    /// @param _coreState Current core state to update with each inclusion processed
    /// @param _numForcedInclusions Maximum number of forced inclusions to process
    /// @param _lookaheadSlotTimestamp The timestamp of the last slot where the current preconfer
    /// can propose.
    /// @return _ Updated core state after processing all consumed forced inclusions
    /// @return _ Number of forced inclusions processed
    function _processForcedInclusions(
        Config memory _config,
        CoreState memory _coreState,
        uint8 _numForcedInclusions,
        uint48 _lookaheadSlotTimestamp
    )
        private
        returns (CoreState memory, uint256)
    {
        IForcedInclusionStore.ForcedInclusion[] memory forcedInclusions = LibForcedInclusion
            .consumeForcedInclusions(_forcedInclusionStorage, msg.sender, _numForcedInclusions);

        for (uint256 i; i < forcedInclusions.length; ++i) {
            _coreState = _propose(
                _config, _coreState, forcedInclusions[i].blobSlice, true, _lookaheadSlotTimestamp
            );
        }

        return (_coreState, forcedInclusions.length);
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
            require(_parentProposals[1].id < _parentProposals[0].id, InvalidLastProposalProof());
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
    /// @param _lookaheadSlotTimestamp The timestamp of the last slot where the current preconfer
    /// can propose.
    /// @return Updated core state with incremented nextProposalId
    function _propose(
        Config memory _config,
        CoreState memory _coreState,
        LibBlobs.BlobSlice memory _blobSlice,
        bool _isForcedInclusion,
        uint48 _lookaheadSlotTimestamp
    )
        private
        returns (CoreState memory)
    {
        unchecked {
            // use previous block as the origin for the proposal to be able to call `blockhash`
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
                timestamp: uint48(block.timestamp),
                lookaheadSlotTimestamp: _lookaheadSlotTimestamp,
                proposer: msg.sender,
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

    /// @dev Finalizes proven proposals and updates checkpoint
    /// @dev Performs up to `maxFinalizationCount` finalization iterations.
    /// The caller is forced to finalize transition records that have passed their cooldown period,
    /// but can
    /// decide to finalize ones that haven't.
    /// @param _config Configuration with finalization parameters
    /// @param _input Input containing transition records and end block header
    /// @return _ Core state with updated finalization counters
    function _finalize(
        Config memory _config,
        ProposeInput memory _input
    )
        private
        returns (CoreState memory)
    {
        CoreState memory coreState = _input.coreState;
        TransitionRecord memory lastFinalizedRecord;
        uint48 proposalId = coreState.lastFinalizedProposalId + 1;
        uint256 finalizedCount;

        for (uint256 i; i < _config.maxFinalizationCount; ++i) {
            // Check if there are more proposals to finalize
            if (proposalId >= coreState.nextProposalId) break;

            // Try to finalize the current proposal
            bool finalized;
            (finalized, proposalId) = _finalizeProposal(
                coreState,
                proposalId,
                i < _input.transitionRecords.length
                    ? _input.transitionRecords[i]
                    : lastFinalizedRecord,
                i < _input.transitionRecords.length
            );

            if (!finalized) break;

            // Update state for successful finalization
            lastFinalizedRecord = _input.transitionRecords[i];
            finalizedCount++;
        }

        // Update checkpoint if any proposals were finalized
        if (finalizedCount > 0) {
            bytes32 checkpointHash = _hashCheckpoint(_input.checkpoint);
            require(checkpointHash == lastFinalizedRecord.checkpointHash, CheckpointMismatch());
            ICheckpointManager(_config.checkpointManager).saveCheckpoint(_input.checkpoint);
        }

        return coreState;
    }

    /// @dev Attempts to finalize a single proposal
    /// @notice Updates core state and processes bond instructions if successful
    /// @param _coreState Core state to update (passed by reference)
    /// @param _proposalId The ID of the proposal to finalize
    /// @param _transitionRecord The expected transition record for verification
    /// @param _hasTransitionRecord Whether a transition record was provided in input
    /// @return finalized_ True if proposal was successfully finalized
    /// @return nextProposalId_ Next proposal ID to process (current + span)
    function _finalizeProposal(
        CoreState memory _coreState,
        uint48 _proposalId,
        TransitionRecord memory _transitionRecord,
        bool _hasTransitionRecord
    )
        private
        returns (bool finalized_, uint48 nextProposalId_)
    {
        // Check if transition record exists in storage
        bytes32 storedHash =
            _getTransitionRecordHash(_proposalId, _coreState.lastFinalizedTransitionHash);

        if (storedHash == 0) return (false, _proposalId);

        // If transition record is provided, allow finalization regardless of cooldown
        // If not provided, and cooldown has passed, revert
        if (!_hasTransitionRecord) {
            // Check if cooldown period has passed for forcing
            if (block.timestamp < _transitionRecord.effectiveAt) {
                // Cooldown not passed, don't force finalization
                return (false, _proposalId);
            }
            // Cooldown passed, force finalization
            revert TransitionRecordNotProvided();
        }

        // Verify transition record hash matches
        bytes32 transitionRecordHash = _hashTransitionRecord(_transitionRecord);
        require(transitionRecordHash == storedHash, TransitionRecordHashMismatchWithStorage());

        // Update core state
        _coreState.lastFinalizedProposalId = _proposalId;

        // Reconstruct the Checkpoint from the transition record hash
        // Note: We need to decode the checkpointHash to get the actual header
        // For finalization, we create a transition with empty block header since we only have the
        // hash
        _coreState.lastFinalizedTransitionHash = _transitionRecord.transitionHash;

        // Process bond instructions
        _processBondInstructions(_coreState, _transitionRecord.bondInstructions);

        // Validate and calculate next proposal ID
        require(_transitionRecord.span > 0, InvalidSpan());
        nextProposalId_ = _proposalId + _transitionRecord.span;
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

    /// @dev Computes composite key for transition record storage
    /// @notice Creates unique identifier for proposal-parent transition pairs
    /// @param _proposalId The ID of the proposal
    /// @param _parentTransitionHash Hash of the parent transition
    /// @return _ Keccak256 hash of encoded parameters
    function _composeTransitionKey(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_proposalId, _parentTransitionHash));
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

    /// @dev Hashes an array of Transitions.
    /// @param _transitions The transitions array to hash.
    /// @return _ The hash of the transitions array.
    function _hashTransitionsArray(Transition[] memory _transitions)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_transitions));
    }
}

// ---------------------------------------------------------------
// Errors
// ---------------------------------------------------------------

error TransitionRecordHashMismatchWithStorage();
error TransitionRecordNotProvided();
error DeadlineExceeded();
error EmptyProposals();
error CheckpointMismatch();
error ExceedsUnfinalizedProposalCapacity();
error ForkNotActive();
error InconsistentParams();
error IncorrectProposalCount();
error InsufficientBond();
error InvalidLastProposalProof();
error InvalidSpan();
error InvalidState();
error LastProposalHashMismatch();
error LastProposalProofNotEmpty();
error NextProposalHashMismatch();
error NoBondToWithdraw();
error ProposalHashMismatch();
error ProposalHashMismatchWithTransition();
error ProposalHashMismatchWithStorage();
error ProposalIdMismatch();
error ProposerBondInsufficient();
error RingBufferSizeZero();
error SpanOutOfBounds();
error TransitionWithSameParentHashAlreadyProved();
error Unauthorized();
error UnprocessedForcedInclusionIsDue();
