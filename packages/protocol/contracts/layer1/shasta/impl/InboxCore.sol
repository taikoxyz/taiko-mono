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
import { LibForcedInclusion } from "../libs/LibForcedInclusion.sol";
import { LibInboxValidation } from "../libs/LibInboxValidation.sol";
import { LibTransitionRecords } from "../libs/LibTransitionRecords.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";

/// @title InboxCore
/// @notice Core shared functionality for Inbox contract implementations
/// @dev Contains common structs, storage, and utility functions that can be inherited
///      by different Inbox implementations (regular Inbox, InboxOptimized1, etc.)
/// @custom:security-contact security@taiko.xyz
abstract contract InboxCore is IInbox, IForcedInclusionStore, EssentialContract {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Type Aliases from Libraries
    // ---------------------------------------------------------------

    using LibTransitionRecords for *;
    using LibInboxValidation for *;

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The token used for bonds.
    IERC20 internal immutable _bondToken;

    /// @notice The checkpoint manager contract.
    ICheckpointManager internal immutable _checkpointManager;

    /// @notice The proof verifier contract.
    IProofVerifier internal immutable _proofVerifier;

    /// @notice The proposer checker contract.
    IProposerChecker internal immutable _proposerChecker;

    /// @notice The proving window in seconds.
    uint48 internal immutable _provingWindow;

    /// @notice The extended proving window in seconds.
    uint48 internal immutable _extendedProvingWindow;

    /// @notice The maximum number of finalized proposals in one block.
    uint256 internal immutable _maxFinalizationCount;

    /// @notice The finalization grace period in seconds.
    uint48 internal immutable _finalizationGracePeriod;

    /// @notice The ring buffer size for storing proposal hashes.
    uint256 internal immutable _ringBufferSize;

    /// @notice The percentage of basefee paid to coinbase.
    uint8 internal immutable _basefeeSharingPctg;

    /// @notice The minimum number of forced inclusions that the proposer is forced to process if
    /// they are due.
    uint256 internal immutable _minForcedInclusionCount;

    /// @notice The delay for forced inclusions measured in seconds.
    uint64 internal immutable _forcedInclusionDelay;

    /// @notice The fee for forced inclusions in Gwei.
    uint64 internal immutable _forcedInclusionFeeInGwei;

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
    /// - `transitionState`
    /// @dev Slot layout: mapping(bytes32 => uint256) with 3 consecutive mappings
    uint256[3] private __deprecated_mappings;

    /// @dev Ring buffer storage for proposal hashes.
    mapping(uint256 bufferSlot => bytes32 proposalHash) internal _proposalHashes;

    /// @dev Mapping to store the bond balance of each user.
    mapping(address user => uint256 bondBalance) public bondBalance;

    /// @notice Core state representing the current canonical chain head and the pending
    /// finalization queue.
    CoreState public coreState;

    /// @dev Mapping to store transition record hashes and deadlines.
    mapping(bytes32 key => LibTransitionRecords.TransitionRecordHashAndDeadline hashAndDeadline) internal
        _transitionRecordHashAndDeadlines;

    /// @notice Mapping to store forced inclusions.
    mapping(bytes32 hash => uint256 timestamp) public _forcedInclusionStorage;

    uint256[43] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(IInbox.Config memory _config) {
        _bondToken = IERC20(_config.bondToken);
        _checkpointManager = ICheckpointManager(_config.checkpointManager);
        _proofVerifier = IProofVerifier(_config.proofVerifier);
        _proposerChecker = IProposerChecker(_config.proposerChecker);
        _provingWindow = _config.provingWindow;
        _extendedProvingWindow = _config.extendedProvingWindow;
        _maxFinalizationCount = _config.maxFinalizationCount;
        _finalizationGracePeriod = _config.finalizationGracePeriod;
        _ringBufferSize = _config.ringBufferSize;
        _basefeeSharingPctg = _config.basefeeSharingPctg;
        _minForcedInclusionCount = _config.minForcedInclusionCount;
        _forcedInclusionDelay = _config.forcedInclusionDelay;
        _forcedInclusionFeeInGwei = _config.forcedInclusionFeeInGwei;
    }

    // ---------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------

    /// @notice Retrieves the proposal hash for a given proposal ID
    /// @param _proposalId The ID of the proposal to query
    /// @return proposalHash_ The keccak256 hash of the Proposal struct at the ring buffer slot
    function getProposalHash(uint48 _proposalId) external view returns (bytes32 proposalHash_) {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        proposalHash_ = _proposalHashes[bufferSlot];
    }

    /// @notice Retrieves the transition record hash for a specific proposal and parent transition
    /// @param _proposalId The ID of the proposal containing the transition
    /// @param _parentTransitionHash The hash of the parent transition in the proof chain
    /// @return finalizationDeadline_ The timestamp when finalization is enforced
    /// @return recordHash_ The hash of the transition record
    function getTransitionRecordHash(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        external
        view
        returns (uint48 finalizationDeadline_, bytes26 recordHash_)
    {
        LibTransitionRecords.TransitionRecordHashAndDeadline memory hashAndDeadline =
            _getTransitionRecordHashAndDeadline(_proposalId, _parentTransitionHash);
        return (hashAndDeadline.finalizationDeadline, hashAndDeadline.recordHash);
    }

    /// @inheritdoc IInbox
    function getConfig() external view returns (IInbox.Config memory config_) {
        config_ = IInbox.Config({
            bondToken: address(_bondToken),
            checkpointManager: address(_checkpointManager),
            proofVerifier: address(_proofVerifier),
            proposerChecker: address(_proposerChecker),
            provingWindow: _provingWindow,
            extendedProvingWindow: _extendedProvingWindow,
            maxFinalizationCount: _maxFinalizationCount,
            finalizationGracePeriod: _finalizationGracePeriod,
            ringBufferSize: _ringBufferSize,
            basefeeSharingPctg: _basefeeSharingPctg,
            minForcedInclusionCount: _minForcedInclusionCount,
            forcedInclusionDelay: _forcedInclusionDelay,
            forcedInclusionFeeInGwei: _forcedInclusionFeeInGwei
        });
    }

    // ---------------------------------------------------------------
    // Internal Utility Functions
    // ---------------------------------------------------------------

    /// @dev Initializes the inbox with genesis block hash.
    /// @param _genesisBlockHash The hash of the genesis block.
    function _initializeInbox(bytes32 _genesisBlockHash) internal {
        // Initialize the core state with the genesis block hash
        coreState.nextProposalBlockId = 1;
        coreState.lastFinalizedTransitionHash = _genesisBlockHash;

        // Initialize the first proposal
        Proposal memory genesisProposal = Proposal({
            id: 0,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: uint48(block.timestamp),
            proposer: address(0),
            coreStateHash: bytes32(0),
            derivationHash: bytes32(0)
        });

        // Set the genesis proposal hash in the ring buffer
        uint256 bufferSlot = 0;
        _proposalHashes[bufferSlot] = LibInboxValidation.hashProposal(genesisProposal);
    }

    /// @dev Validates a transition for a given proposal.
    /// @param _proposal The proposal containing the transition.
    /// @param _transition The transition to validate.
    function _validateTransition(
        Proposal memory _proposal,
        Transition memory _transition
    )
        internal
        view
    {
        LibInboxValidation.validateTransition(_proposal, _transition, _proposalHashes, _ringBufferSize);
    }

    /// @dev Sets the proposal hash for a given proposal ID in the ring buffer.
    /// @param _proposalId The ID of the proposal.
    /// @param _proposalHash The hash of the proposal to set.
    function _setProposalHash(uint48 _proposalId, bytes32 _proposalHash) internal {
        uint256 bufferSlot = _proposalId % _ringBufferSize;
        _proposalHashes[bufferSlot] = _proposalHash;
    }

    /// @dev Sets the transition record hash and deadline for a specific transition.
    /// @param _proposalId The ID of the proposal containing the transition.
    /// @param _transition The transition data.
    /// @param _metadata The metadata for the transition.
    /// @param _transitionRecord The transition record.
    function _setTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        Transition memory _transition,
        TransitionMetadata memory _metadata,
        TransitionRecord memory _transitionRecord
    )
        internal
        virtual
    {
        LibTransitionRecords.setTransitionRecordHashAndDeadline(
            _proposalId,
            _transition,
            _metadata,
            _transitionRecord,
            _transitionRecordHashAndDeadlines,
            _finalizationGracePeriod
        );
    }

    /// @dev Gets the transition record hash and deadline for a specific transition.
    /// @param _proposalId The ID of the proposal containing the transition.
    /// @param _parentTransitionHash The hash of the parent transition.
    /// @return hashAndDeadline The transition record hash and finalization deadline.
    function _getTransitionRecordHashAndDeadline(
        uint48 _proposalId,
        bytes32 _parentTransitionHash
    )
        internal
        view
        returns (LibTransitionRecords.TransitionRecordHashAndDeadline memory hashAndDeadline)
    {
        hashAndDeadline = LibTransitionRecords.getTransitionRecordHashAndDeadline(
            _proposalId,
            _parentTransitionHash,
            _transitionRecordHashAndDeadlines
        );
    }

    /// @dev Checks if a proposal hash matches the stored hash in the ring buffer.
    /// @param _proposal The proposal to check.
    /// @return proposalHash_ The computed proposal hash.
    function _checkProposalHash(Proposal memory _proposal)
        internal
        view
        returns (bytes32 proposalHash_)
    {
        return LibInboxValidation.checkProposalHash(_proposal, _proposalHashes, _ringBufferSize);
    }

    // ---------------------------------------------------------------
    // Delegated Functions to Libraries
    // ---------------------------------------------------------------

    /// @dev Builds a transition record for a proposal, transition, and metadata tuple.
    /// @param _proposal The proposal the transition is proving.
    /// @param _transition The transition associated with the proposal.
    /// @param _metadata The metadata describing the prover and additional context.
    /// @return record The constructed transition record with span set to one.
    function _buildTransitionRecord(
        Proposal memory _proposal,
        Transition memory _transition,
        TransitionMetadata memory _metadata
    )
        internal
        view
        returns (TransitionRecord memory record)
    {
        return LibTransitionRecords.buildTransitionRecord(
            _proposal, _transition, _metadata, _provingWindow, _extendedProvingWindow
        );
    }

    /// @dev Hashes an array of Transitions.
    /// @param _transitions The transitions array to hash.
    /// @return _ The hash of the transitions array.
    function _hashTransitionsArray(Transition[] memory _transitions)
        internal
        pure
        returns (bytes32)
    {
        return LibInboxValidation.hashTransitionsArray(_transitions);
    }

    /// @dev Hashes the core state.
    /// @param _coreState The core state to hash.
    /// @return _ The hash of the core state.
    function _hashCoreState(CoreState memory _coreState) internal pure virtual returns (bytes32) {
        return LibInboxValidation.hashCoreState(_coreState);
    }

    /// @dev Hashes a proposal.
    /// @param _proposal The proposal to hash.
    /// @return _ The hash of the proposal.
    function _hashProposal(Proposal memory _proposal) internal pure virtual returns (bytes32) {
        return LibInboxValidation.hashProposal(_proposal);
    }

    /// @dev Hashes a derivation.
    /// @param _derivation The derivation to hash.
    /// @return _ The hash of the derivation.
    function _hashDerivation(Derivation memory _derivation)
        internal
        pure
        returns (bytes32)
    {
        return LibInboxValidation.hashDerivation(_derivation);
    }

    // ---------------------------------------------------------------
    // Data Encoding/Decoding Functions
    // ---------------------------------------------------------------

    /// @dev Decodes ProposalInput from calldata.
    /// @param _data The calldata to decode.
    /// @return input The decoded ProposalInput.
    function _decodeProposeInput(bytes calldata _data)
        internal
        pure
        returns (ProposeInput memory input)
    {
        return LibTransitionRecords.decodeProposeInput(_data);
    }

    /// @dev Decodes ProveInput from calldata.
    /// @param _data The calldata to decode.
    /// @return input The decoded ProveInput.
    function _decodeProveInput(bytes calldata _data)
        internal
        pure
        returns (ProveInput memory input)
    {
        return LibTransitionRecords.decodeProveInput(_data);
    }

    /// @dev Encodes event data for the Proposed event.
    /// @param _payload The event payload to encode.
    /// @return _ The encoded event data.
    function _encodeProposedEventData(ProposedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory)
    {
        return LibTransitionRecords.encodeProposedEventData(_payload);
    }

    /// @dev Encodes event data for the Proved event.
    /// @param _payload The event payload to encode.
    /// @return _ The encoded event data.
    function _encodeProvedEventData(ProvedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory)
    {
        return LibTransitionRecords.encodeProvedEventData(_payload);
    }

    // ---------------------------------------------------------------
    // Abstract Functions to be implemented by child contracts
    // ---------------------------------------------------------------

    /// @dev Abstract function for building and saving transition records.
    /// @param _input The prove input containing proposals and transitions.
    function _buildAndSaveTransitionRecords(ProveInput memory _input) internal virtual;
}