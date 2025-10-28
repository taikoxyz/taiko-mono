// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LegacySignalService.sol";
import "./ICheckpointStore.sol";
import "./ISignalService.sol";

/// @title SignalService
/// @notice See the documentation in {ISignalService} for more details.
/// @dev Labeled in address resolver as "signal_service".
/// @custom:security-contact security@taiko.xyz
contract SignalService is LegacySignalService, ISignalService {
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


    /// @dev The height of the shasta fork.
    uint256 internal immutable _shastaForkHeight;

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

    constructor(address authorizedSyncer, address remoteSignalService, uint256 shastaForkHeight) LegacySignalService(remoteSignalService) {
        require(authorizedSyncer != address(0), ZERO_ADDRESS());

        _authorizedSyncer = authorizedSyncer;
        _shastaForkHeight = shastaForkHeight;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ISignalService
    function sendSignal(bytes32 _signal) external returns (bytes32) {
        return _sendSignal(msg.sender, _signal, _signal);
    }

    /// @inheritdoc ISignalService
    /// @dev This function may revert.
    function proveSignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        external
        virtual
        returns (uint256)
    {
        bytes32 slot = getSignalSlot(_chainId, _app, _signal);
        if (block.timestamp < _shastaForkHeight) {
        // Pre shasta logic
            CacheAction[] memory actions = // actions for caching
            _verifySignalReceivedLegacy(_chainId, _app, _signal, _proof, true);

            uint256 numCacheOps;
            for (uint256 i; i < actions.length; ++i) {
                numCacheOps += _cacheLegacy(actions[i]);
            }
            return numCacheOps;
        }

        // Post shasta logic
        _verifySignalReceived(_chainId, _app, _signal, _proof);
        _receivedSignals[slot] = true;
        return 0;
    }

    /// @inheritdoc ISignalService
    /// @dev This function may revert.
    function verifySignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        external
        view
        virtual
    {
        if (block.timestamp < _shastaForkHeight) {
            // Pre shasta logic
            _verifySignalReceivedLegacy(_chainId, _app, _signal, _proof, false);
            return; 
        }

        // Post shasta logic
        _verifySignalReceived(_chainId, _app, _signal, _proof);
    }

    /// @inheritdoc ISignalService
    function isSignalSent(address _app, bytes32 _signal) public view returns (bool) {
        return _loadSignalValue(_app, _signal) != 0;
    }

    /// @inheritdoc ISignalService
    function isSignalSent(bytes32 _signalSlot) public view returns (bool) {
        return _loadSignalValue(_signalSlot) != 0;
    }

    /// @inheritdoc ICheckpointStore
    function saveCheckpoint(Checkpoint calldata _checkpoint) external override {
        if (msg.sender != _authorizedSyncer) revert SS_UNAUTHORIZED();
        if (_checkpoint.stateRoot == bytes32(0)) revert SS_INVALID_CHECKPOINT();
        if (_checkpoint.blockHash == bytes32(0)) revert SS_INVALID_CHECKPOINT();

        _checkpoints[_checkpoint.blockNumber] = CheckpointRecord({
            blockHash: _checkpoint.blockHash, stateRoot: _checkpoint.stateRoot
        });

        emit CheckpointSaved(_checkpoint.blockNumber, _checkpoint.blockHash, _checkpoint.stateRoot);
    }

    /// @inheritdoc ICheckpointStore
    function getCheckpoint(uint48 _blockNumber)
        external
        view
        override
        returns (Checkpoint memory checkpoint)
    {
        return _getCheckpoint(_blockNumber);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Gets a checkpoint by block number
    /// @param _blockNumber The block number of the checkpoint
    /// @return checkpoint The checkpoint
    function _getCheckpoint(uint48 _blockNumber)
        private
        view
        returns (Checkpoint memory checkpoint)
    {
        CheckpointRecord storage record = _checkpoints[_blockNumber];
        bytes32 blockHash = record.blockHash;
        if (blockHash == bytes32(0)) revert SS_CHECKPOINT_NOT_FOUND();

        checkpoint = Checkpoint({
            blockNumber: _blockNumber, blockHash: blockHash, stateRoot: record.stateRoot
        });
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

    function _verifySignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        private
        view
        nonZeroAddr(_app)
        nonZeroBytes32(_signal)
    {
        bytes32 slot = getSignalSlot(_chainId, _app, _signal);
        if (_proof.length == 0) {
            require(_receivedSignals[slot], SS_SIGNAL_NOT_RECEIVED());
            return;
        }

        Proof[] memory proofs = abi.decode(_proof, (Proof[]));
        if (proofs.length != 1) revert SS_INVALID_PROOF_LENGTH();

        Proof memory proof = proofs[0];

        if (proof.accountProof.length == 0 || proof.storageProof.length == 0) {
            revert SS_EMPTY_PROOF();
        }

        Checkpoint memory checkpoint = _getCheckpoint(uint48(proof.blockId));
        if (checkpoint.stateRoot != proof.rootHash) {
            revert SS_INVALID_CHECKPOINT();
        }

        LibTrieProof.verifyMerkleProof(
            checkpoint.stateRoot,
            _remoteSignalService,
            slot,
            _signal,
            proof.accountProof,
            proof.storageProof
        );
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
error SS_SIGNAL_NOT_RECEIVED();
