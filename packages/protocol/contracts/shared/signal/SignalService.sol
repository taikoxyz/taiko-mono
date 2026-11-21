// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../common/EssentialContract.sol";
import "../libs/LibTrieProof.sol";
import "./ICheckpointStore.sol";
import "./ISignalService.sol";

import "./SignalService_Layout.sol"; // DO NOT DELETE

/// @title SignalService
/// @notice See the documentation in {ISignalService} for more details.
/// @dev Labeled in address resolver as "signal_service".
/// This contract will be initially deployed behind the fork router, which uses 151 slots [0..150].
/// The storage layout of this contract is compatible and aligned with both the Pacaya version and the fork router.
/// (e.g. the owner slot is in the same position).
/// @custom:security-contact security@taiko.xyz
contract SignalService is EssentialContract, ISignalService {
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

    /// @notice Address authorized to pause/unpause alongside the owner. Optional (may be zero).
    address public immutable pauser;

    /// @notice False on L1. True on L2, where EIP-4788 holds L1 state roots from Etna on: the
    /// checkpoint store then accepts a checkpoint only in a block whose own EIP-4788 root is zero,
    /// which is every block before Etna and none from Etna on, and proof roots resolve from a
    /// checkpoint or, when none is held for the proof's block id, from EIP-4788.
    bool public immutable usesBeaconRoots;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Version of the received-signal cache and checkpoint mappings.
    /// @dev Bumping this value in a future implementation hides every old cached signal and
    /// checkpoint at once without touching the old storage slots, including the checkpoints an
    /// Etna verifier-failure rollback must keep usable; that rollback therefore cannot be only a
    /// bump (Etna spec RECOV-8-27).
    uint256 public constant VERSION = 1;

    /// @notice The canonical EIP-4788 beacon roots contract. On L2 it records each block's
    /// `parentBeaconBlockRoot`: zero before Etna, the execution state root of the block's L1 anchor
    /// from Etna on.
    address public constant BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    // ---------------------------------------------------------------
    // Storage variables
    // ---------------------------------------------------------------

    /// @dev Slots used by the Pacaya signal service.
    // slot1: topBlockId
    // slot2: isAuthorized
    uint256[2] private _slotsUsedByPacaya;

    /// @dev Cache for received signals, namespaced by VERSION so a version bump invalidates cache
    /// entries together with the checkpoints they were derived from.
    /// @dev Once written, subsequent verifications can skip the merkle proof validation.
    /// Does NOT reuse the pacaya slot.
    mapping(uint256 version => mapping(bytes32 signalSlot => bool received)) internal
        _receivedSignals;

    /// @notice Storage for checkpoints persisted via the SignalService.
    /// @dev Maps checkpoint version => block number => checkpoint data.
    mapping(uint256 version => mapping(uint48 blockNumber => CheckpointRecord checkpoint)) private
        _checkpoints;

    uint256[46] private __gap;

    // ---------------------------------------------------------------
    // Constructor and Initialization
    // ---------------------------------------------------------------

    /// @notice Initializes the signal service's immutable state.
    /// @param authorizedSyncer Address that can save checkpoints to this contract.
    /// @param remoteSignalService Address of the remote signal service.
    /// @param _pauser Address authorized to pause/unpause alongside the owner. Optional (may be
    /// zero).
    /// @param _usesBeaconRoots False on L1; true on L2 (Etna ANCHORLESS.md section 4).
    constructor(
        address authorizedSyncer,
        address remoteSignalService,
        address _pauser,
        bool _usesBeaconRoots
    ) {
        require(authorizedSyncer != address(0), ZERO_ADDRESS());
        require(remoteSignalService != address(0), ZERO_ADDRESS());

        _authorizedSyncer = authorizedSyncer;
        _remoteSignalService = remoteSignalService;
        pauser = _pauser;
        usesBeaconRoots = _usesBeaconRoots;
    }

    /// @notice Initializes the SignalService contract for upgradeable deployments.
    /// @param _owner Address that will own the contract.
    function init(address _owner) external initializer {
        require(_owner != address(0), ZERO_ADDRESS());
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
        whenNotPaused
        returns (uint256)
    {
        _verifySignalReceived(_chainId, _app, _signal, _proof);
        _receivedSignals[VERSION][getSignalSlot(_chainId, _app, _signal)] = true;
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
        whenNotPaused
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
        /// forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encodePacked("SIGNAL", _chainId, _app, _signal));
    }

    /// @inheritdoc ICheckpointStore
    /// @dev With `usesBeaconRoots`, rejects a checkpoint unless the EIP-4788 root of the current
    /// block's own timestamp reads as zero. An Etna block has a nonzero root, so no checkpoint can
    /// be saved from Etna on and the public golden touch key cannot forge one through `anchorV4`.
    /// A failed read rejects as well, so a missing EIP-4788 contract fails closed.
    function saveCheckpoint(Checkpoint calldata _checkpoint) external override {
        if (msg.sender != _authorizedSyncer) revert SS_UNAUTHORIZED();
        if (usesBeaconRoots) {
            (bool ok, bytes32 root) = _beaconRoot(block.timestamp);
            if (!ok || root != 0) revert SS_CHECKPOINTS_CLOSED();
        }
        if (_checkpoint.stateRoot == bytes32(0)) revert SS_INVALID_CHECKPOINT();
        if (_checkpoint.blockHash == bytes32(0)) revert SS_INVALID_CHECKPOINT();

        _checkpoints[VERSION][_checkpoint.blockNumber] = CheckpointRecord({
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

    /// @dev Authorizes the owner or the designated immutable pauser to pause/unpause.
    function _authorizePause(address, bool) internal view override onlyFromOwnerOr(pauser) { }

    /// @dev Resolves the state root against which a signal proof is checked. A checkpoint answers
    /// first; with `usesBeaconRoots`, an id with no checkpoint then reads EIP-4788. Both stores
    /// hold only L1 state roots, so either may answer, and the choice does not depend on the block
    /// that verifies the proof.
    /// @param _blockId The block number of a checkpoint, or on L2 the timestamp of an Etna block.
    /// The `uint48` bound applies only to the checkpoint lookup.
    /// @return stateRoot_ The authenticated, nonzero state root; reverts with
    /// `SS_CHECKPOINT_NOT_FOUND` if neither store holds one.
    function _getStateRoot(uint64 _blockId) private view returns (bytes32 stateRoot_) {
        if (_blockId <= type(uint48).max) {
            stateRoot_ = _checkpoints[VERSION][uint48(_blockId)].stateRoot;
        }
        if (stateRoot_ == 0 && usesBeaconRoots) (, stateRoot_) = _beaconRoot(_blockId);
        if (stateRoot_ == 0) revert SS_CHECKPOINT_NOT_FOUND();
    }

    /// @dev Reads EIP-4788. Its whole calldata is the 32-byte timestamp, with no selector. It
    /// reverts for a timestamp it does not hold, and a call to an address without code succeeds
    /// with no return data; both give `ok_` false. A block before Etna reads as a zero root.
    /// @param _timestamp The L2 block timestamp.
    /// @return ok_ Whether the read returned one word.
    /// @return root_ The recorded root; zero unless `ok_`.
    function _beaconRoot(uint256 _timestamp) private view returns (bool ok_, bytes32 root_) {
        (bool success, bytes memory ret) = BEACON_ROOTS.staticcall(abi.encode(_timestamp));
        ok_ = success && ret.length == 32;
        if (ok_) root_ = abi.decode(ret, (bytes32));
    }

    /// @dev Gets a checkpoint by block number
    /// @param _blockNumber The block number of the checkpoint
    /// @return checkpoint_ The checkpoint
    function _getCheckpoint(uint48 _blockNumber)
        private
        view
        returns (Checkpoint memory checkpoint_)
    {
        CheckpointRecord storage record = _checkpoints[VERSION][_blockNumber];
        bytes32 blockHash = record.blockHash;
        if (blockHash == bytes32(0)) revert SS_CHECKPOINT_NOT_FOUND();

        checkpoint_ = Checkpoint({
            blockNumber: _blockNumber, blockHash: blockHash, stateRoot: record.stateRoot
        });
    }

    function _sendSignal(
        address _app,
        bytes32 _signal,
        bytes32 _value
    )
        private
        returns (bytes32 slot_)
    {
        require(_app != address(0), ZERO_ADDRESS());
        require(_signal != bytes32(0), ZERO_VALUE());
        require(_value != bytes32(0), ZERO_VALUE());

        slot_ = getSignalSlot(uint64(block.chainid), _app, _signal);
        assembly {
            sstore(slot_, _value)
        }
        emit SignalSent(_app, _signal, slot_, _value);
    }

    function _loadSignalValue(address _app, bytes32 _signal) private view returns (bytes32) {
        require(_app != address(0), ZERO_ADDRESS());
        require(_signal != bytes32(0), ZERO_VALUE());

        bytes32 slot = getSignalSlot(uint64(block.chainid), _app, _signal);
        return _loadSignalValue(slot);
    }

    function _loadSignalValue(bytes32 _signalSlot) private view returns (bytes32 value_) {
        assembly {
            value_ := sload(_signalSlot)
        }
    }

    /// @dev Verifies a cached signal, or a proof against the root `_getStateRoot` resolves.
    /// @param _chainId Source chain ID.
    /// @param _app Source application that sent the signal.
    /// @param _signal Signal being proven.
    /// @param _proof ABI-encoded hop proofs, or empty bytes for a cached signal.
    function _verifySignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        private
        view
    {
        require(_app != address(0), ZERO_ADDRESS());
        require(_signal != bytes32(0), ZERO_VALUE());

        bytes32 slot = getSignalSlot(_chainId, _app, _signal);
        if (_proof.length == 0) {
            require(_receivedSignals[VERSION][slot], SS_SIGNAL_NOT_RECEIVED());
            return;
        }

        HopProof[] memory proofs = abi.decode(_proof, (HopProof[]));
        if (proofs.length != 1) revert SS_INVALID_PROOF_LENGTH();

        HopProof memory proof = proofs[0];

        if (proof.accountProof.length == 0 || proof.storageProof.length == 0) {
            revert SS_EMPTY_PROOF();
        }

        bytes32 stateRoot = _getStateRoot(proof.blockId);
        if (stateRoot != proof.rootHash) {
            revert SS_INVALID_CHECKPOINT();
        }

        LibTrieProof.verifyMerkleProof(
            stateRoot, _remoteSignalService, slot, _signal, proof.accountProof, proof.storageProof
        );
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error SS_CHECKPOINT_NOT_FOUND();
    error SS_CHECKPOINTS_CLOSED();
    error SS_EMPTY_PROOF();
    error SS_INVALID_CHECKPOINT();
    error SS_INVALID_PROOF_LENGTH();
    error SS_SIGNAL_NOT_RECEIVED();
    error SS_UNAUTHORIZED();
}
