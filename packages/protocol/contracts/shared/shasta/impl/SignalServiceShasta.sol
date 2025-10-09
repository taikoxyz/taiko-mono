// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../common/EssentialContract.sol";
import "../../libs/LibTrieProof.sol";
import "../../libs/LibNames.sol";
import "../iface/ICheckpointStore.sol";
import "../iface/ISignalServiceShasta.sol";

/// @title ShastaSignalService
/// @notice See the documentation in {ISignalServiceShasta} for more details.
/// @dev Labeled in address resolver as "signal_service".
/// @custom:security-contact security@taiko.xyz
contract SignalServiceShasta is EssentialContract, ISignalServiceShasta {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Storage-optimized checkpoint record with only persisted fields
    struct CheckpointRecord {
        /// @notice The block hash for the end (last) block in this proposal.
        bytes32 blockHash;
        /// @notice The state root for the end (last) block in this proposal.
        bytes32 stateRoot;
    }

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @dev Address that can save checkpoints to this contract.
    /// @dev This is the `inbox` on L1 and the `anchor` on L2.
    address internal immutable _authorizedSyncer;

    /// @dev Address of the remote signal service.
    address internal immutable _remoteSignalService;
    // ---------------------------------------------------------------
    // Pre shasta storage variables
    // ---------------------------------------------------------------

    /// @dev Deprecated slots used by the old SignalService
    // - `topBlockId`
    // - `authorized`
    // - `_receivedSignals`
    uint256[3] private _slotsUsedByPacaya;

    // ---------------------------------------------------------------
    // Post shasta storage variables
    // ---------------------------------------------------------------

    /// @notice Storage for checkpoints persisted via the SignalService.
    /// @dev Maps block number to checkpoint data
    mapping(uint48 blockNumber => CheckpointRecord checkpoint) private _checkpoints;

    uint256[44] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(address authorizedSyncer, address remoteSignalService) {
        require(authorizedSyncer != address(0), ZERO_ADDRESS());
        require(remoteSignalService != address(0), ZERO_ADDRESS());

        _authorizedSyncer = authorizedSyncer;
        _remoteSignalService = remoteSignalService;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ISignalServiceShasta
    function sendSignal(bytes32 _signal) external returns (bytes32) {
        return _sendSignal(msg.sender, _signal, _signal);
    }

    /// @inheritdoc ISignalServiceShasta
    /// @dev This function may revert.
    function verifySignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        external
        view
        nonZeroAddr(_app)
        nonZeroBytes32(_signal)
    {
        bytes32 slot = getSignalSlot(_chainId, _app, _signal);

        Proof[] memory proofs = abi.decode(_proof, (Proof[]));
        if (proofs.length != 1) revert SS_INVALID_PROOF_LENGTH();

        Proof memory proof = proofs[0];

        if (proof.accountProof.length == 0 || proof.storageProof.length == 0) {
            revert SS_EMPTY_PROOF();
        }

        CheckpointRecord storage checkpoint = _getCheckpoint(uint48(proof.blockId));
        bytes32 stateRoot = checkpoint.stateRoot;
        if (stateRoot != proof.rootHash) {
            revert SS_INVALID_CHECKPOINT();
        }

        LibTrieProof.verifyMerkleProof(
            stateRoot, _remoteSignalService, slot, _signal, proof.accountProof, proof.storageProof
        );
    }

    /// @inheritdoc ISignalServiceShasta
    function isSignalSent(address _app, bytes32 _signal) public view returns (bool) {
        return _loadSignalValue(_app, _signal) != 0;
    }

    /// @inheritdoc ISignalServiceShasta
    function isSignalSent(bytes32 _signalSlot) public view returns (bool) {
        return _loadSignalValue(_signalSlot) != 0;
    }

    /// @notice Returns the slot for a signal.
    /// @param _chainId The chainId of the signal.
    /// @param _app The address that initiated the signal.
    /// @param _signal The signal (message) that was sent.
    /// @return The slot for the signal.
    function getSignalSlot(
        uint64 _chainId,
        address _app,
        bytes32 _signal
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("SIGNAL", _chainId, _app, _signal));
    }

    /// @inheritdoc ICheckpointStore
    function saveCheckpoint(Checkpoint calldata _checkpoint) external override {
        if (msg.sender != _authorizedSyncer) revert SS_UNAUTHORIZED();
        if (_checkpoint.stateRoot == bytes32(0)) revert SS_INVALID_CHECKPOINT();
        if (_checkpoint.blockHash == bytes32(0)) revert SS_INVALID_CHECKPOINT();

        _checkpoints[_checkpoint.blockNumber] =
            CheckpointRecord({ blockHash: _checkpoint.blockHash, stateRoot: _checkpoint.stateRoot });

        emit CheckpointSaved(_checkpoint.blockNumber, _checkpoint.blockHash, _checkpoint.stateRoot);
    }

    /// @inheritdoc ICheckpointStore
    function getCheckpoint(uint48 _blockNumber)
        external
        view
        override
        returns (Checkpoint memory checkpoint)
    {
        CheckpointRecord storage record = _getCheckpoint(_blockNumber);
        checkpoint = Checkpoint({
            blockNumber: _blockNumber,
            blockHash: record.blockHash,
            stateRoot: record.stateRoot
        });
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Gets a checkpoint by block number
    /// @param _blockNumber The block number of the checkpoint
    /// @return record_ The checkpoint record
    function _getCheckpoint(uint48 _blockNumber)
        private
        view
        returns (CheckpointRecord storage record_)
    {
        record_ = _checkpoints[_blockNumber];
        if (record_.blockHash == bytes32(0)) revert SS_CHECKPOINT_NOT_FOUND();
    }

    function _sendSignal(
        address _app,
        bytes32 _signal,
        bytes32 _value
    )
        private
        nonZeroAddr(_app)
        nonZeroBytes32(_signal)
        nonZeroBytes32(_value)
        returns (bytes32 slot_)
    {
        slot_ = getSignalSlot(uint64(block.chainid), _app, _signal);
        assembly {
            sstore(slot_, _value)
        }
        emit SignalSent(_app, _signal, slot_, _value);
    }

    function _loadSignalValue(
        address _app,
        bytes32 _signal
    )
        private
        view
        nonZeroAddr(_app)
        nonZeroBytes32(_signal)
        returns (bytes32)
    {
        bytes32 slot = getSignalSlot(uint64(block.chainid), _app, _signal);
        return _loadSignalValue(slot);
    }

    function _loadSignalValue(bytes32 _signalSlot) private view returns (bytes32 value_) {
        assembly {
            value_ := sload(_signalSlot)
        }
    }
}

// ---------------------------------------------------------------
// Errors
// ---------------------------------------------------------------
error SS_EMPTY_PROOF();
error SS_INVALID_PROOF_LENGTH();
error SS_INVALID_CHECKPOINT();
error SS_CHECKPOINT_NOT_FOUND();
error SS_UNAUTHORIZED();
