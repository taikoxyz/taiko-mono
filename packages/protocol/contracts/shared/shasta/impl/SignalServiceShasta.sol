// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../common/EssentialContract.sol";
import "../../libs/LibTrieProof.sol";
import "../../libs/LibNames.sol";
import "../iface/ICheckpointStore.sol";
import "../libs/LibCheckpointStore.sol";
import "../iface/ISignalServiceShasta.sol";

/// @title SignalService
/// @notice See the documentation in {ISignalService} for more details.
/// @dev Labeled in address resolver as "signal_service".
/// @custom:security-contact security@taiko.xyz
contract SignalService is EssentialContract, ISignalService, ICheckpointStore {

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
    uint256[2] private _slotsUsedByPacaya;

    /// @dev Cache for received signals. 
    /// @dev Once written, subsequent verifications can skip the merkle proof validation.
    mapping(bytes32 signalSlot => bool received) internal _receivedSignals;

    
    // ---------------------------------------------------------------
    // New Storage variables
    // ---------------------------------------------------------------

    /// @notice Storage for checkpoints persisted via the SignalService.
    /// @dev 2 slots used
    LibCheckpointStore.Storage private _checkpointStorage;

    uint256[44] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------
    
    constructor(address authorizedSyncer, address remoteSignalService)  {
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
        _verifySignalReceived(_chainId, _app, _signal, _proof);
        _receivedSignals[getSignalSlot(_chainId, _app, _signal)] = true;
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
    {
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

        LibCheckpointStore.saveCheckpoint(_checkpointStorage, _checkpoint);
    }


    /// @inheritdoc ICheckpointStore
    function getCheckpoint(uint48 _blockNumber)
        external
        view
        override
        returns (Checkpoint memory)
    {
        return LibCheckpointStore.getCheckpoint(_checkpointStorage, _blockNumber);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------
    

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

        HopProof[] memory hopProofs = abi.decode(_proof, (HopProof[]));
        if (hopProofs.length != 1) revert SS_INVALID_PROOF_LENGTH();

        HopProof memory hop = hopProofs[0];
        // TODO: do we need to support the case where accountProof=0 like the original SS?
        // If so, who pushes the trusted account root of the SS?
        if (hop.accountProof.length == 0 || hop.storageProof.length == 0) revert SS_EMPTY_PROOF();

        ICheckpointStore.Checkpoint memory checkpoint =
            LibCheckpointStore.getCheckpoint(_checkpointStorage, uint48(hop.blockId));
        if (checkpoint.blockNumber != uint48(hop.blockId) || checkpoint.stateRoot != hop.rootHash) {
            revert SS_INVALID_CHECKPOINT();
        }

        LibTrieProof.verifyMerkleProof(
            checkpoint.stateRoot,
            _remoteSignalService,
            slot,
            _signal,
            hop.accountProof,
            hop.storageProof
        );
    }
}

// ---------------------------------------------------------------
// Errors
// ---------------------------------------------------------------
error SS_EMPTY_PROOF();
error SS_INVALID_PROOF_LENGTH();
error SS_INVALID_CHECKPOINT();
error SS_UNAUTHORIZED();
error SS_SIGNAL_NOT_RECEIVED();
