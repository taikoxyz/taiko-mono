// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EssentialContract } from "../common/EssentialContract.sol";
import { LibTrieProof } from "../libs/LibTrieProof.sol";
import { ICheckpointStore } from "./ICheckpointStore.sol";
import { ISignalService } from "./ISignalService.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";

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
    // Constants
    // ---------------------------------------------------------------

    /// @dev EIP-7201 namespace for signal storage to prevent slot collisions.
    /// keccak256(abi.encode(uint256(keccak256("taiko.signal.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _SIGNAL_NAMESPACE =
        0x5f95a88415cd5f00e8294a1869c7704fe444fc32297815093cecf5b3769dc600;

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

    /// @dev Timestamp after which legacy slot fallback will no longer be performed.
    uint256 public immutable legacySlotExpiry;

    // ---------------------------------------------------------------
    // Storage variables
    // ---------------------------------------------------------------

    /// @dev Slots used by the Pacaya signal service.
    // slot1: topBlockId
    // slot2: isAuthorized
    uint256[2] private _slotsUsedByPacaya;

    /// @dev Cache for received signals.
    /// @dev Once written, subsequent verifications can skip the merkle proof validation.
    /// Does NOT reuse the pacaya slot.
    mapping(bytes32 signalSlot => bool received) internal _receivedSignals;

    /// @notice Storage for checkpoints persisted via the SignalService.
    /// @dev Maps block number to checkpoint data
    mapping(uint48 blockNumber => CheckpointRecord checkpoint) private _checkpoints;

    uint256[46] private __gap;

    // ---------------------------------------------------------------
    // Constructor and Initialization
    // ---------------------------------------------------------------

    constructor(
        address authorizedSyncer,
        address remoteSignalService,
        uint256 _legacySlotExpiry
    ) {
        require(authorizedSyncer != address(0), ZERO_ADDRESS());
        require(remoteSignalService != address(0), ZERO_ADDRESS());

        _authorizedSyncer = authorizedSyncer;
        _remoteSignalService = remoteSignalService;
        legacySlotExpiry = _legacySlotExpiry;
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
        virtual
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

    /// @notice Returns the EIP-7201 namespaced slot for a signal.
    /// @dev This uses a high-entropy domain separator to prevent slot collisions with contract state.
    /// The hash is computed as: keccak256(abi.encode(_SIGNAL_NAMESPACE, _chainId, _app, _signal))
    /// @param _chainId The chainId of the signal.
    /// @param _app The address that initiated the signal.
    /// @param _signal The signal (message) that was sent.
    /// @return The EIP-7201 namespaced slot for the signal.
    function getSignalSlot(
        uint64 _chainId,
        address _app,
        bytes32 _signal
    )
        public
        pure
        returns (bytes32)
    {
        return EfficientHashLib.hash(
            _SIGNAL_NAMESPACE, bytes32(uint256(_chainId)), bytes32(uint256(uint160(_app))), _signal
        );
    }

    /// @notice Returns the legacy slot for a signal (pre-EIP-7201).
    /// @dev This is the old slot calculation method, kept for backwards compatibility during migration.
    /// @param _chainId The chainId of the signal.
    /// @param _app The address that initiated the signal.
    /// @param _signal The signal (message) that was sent.
    /// @return The legacy slot for the signal.
    function getLegacySignalSlot(
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

    /// @notice External wrapper for LibTrieProof.verifyMerkleProof to enable try-catch pattern.
    /// @dev This function is intentionally external so that the contract can call it via `this.`
    /// and catch reverts when the proof doesn't match the slot.
    /// @param _rootHash The merkle root of state tree.
    /// @param _addr The address of contract.
    /// @param _slot The slot in the contract.
    /// @param _value The value to be verified.
    /// @param _accountProof The account proof
    /// @param _storageProof The storage proof
    function verifyMerkleProof(
        bytes32 _rootHash,
        address _addr,
        bytes32 _slot,
        bytes32 _value,
        bytes[] calldata _accountProof,
        bytes[] calldata _storageProof
    )
        external
        pure
    {
        LibTrieProof.verifyMerkleProof(
            _rootHash, _addr, _slot, _value, _accountProof, _storageProof
        );
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Gets a checkpoint by block number
    /// @param _blockNumber The block number of the checkpoint
    /// @return checkpoint_ The checkpoint
    function _getCheckpoint(uint48 _blockNumber)
        private
        view
        returns (Checkpoint memory checkpoint_)
    {
        CheckpointRecord storage record = _checkpoints[_blockNumber];
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

    function _loadSignalValue(
        address _app,
        bytes32 _signal
    )
        private
        view
        returns (bytes32 value_)
    {
        require(_app != address(0), ZERO_ADDRESS());
        require(_signal != bytes32(0), ZERO_VALUE());

        uint64 chainId = uint64(block.chainid);

        // First try the new EIP-7201 slot
        value_ = _loadSignalValue(getSignalSlot(chainId, _app, _signal));

        // If value is 0 and legacy support hasn't expired, check the legacy slot
        if (value_ == bytes32(0) && block.timestamp < legacySlotExpiry) {
            value_ = _loadSignalValue(getLegacySignalSlot(chainId, _app, _signal));
        }
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
    {
        require(_app != address(0), ZERO_ADDRESS());
        require(_signal != bytes32(0), ZERO_VALUE());

        bytes32 slot = getSignalSlot(_chainId, _app, _signal);
        if (_proof.length == 0) {
            // Check new EIP-7201 slot first
            if (_receivedSignals[slot]) return;
            // Fall back to legacy slot if within the legacy support period
            if (
                block.timestamp < legacySlotExpiry
                    && _receivedSignals[getLegacySignalSlot(_chainId, _app, _signal)]
            ) return;

            revert SS_SIGNAL_NOT_RECEIVED();
        }

        HopProof[] memory proofs = abi.decode(_proof, (HopProof[]));
        if (proofs.length != 1) revert SS_INVALID_PROOF_LENGTH();

        HopProof memory proof = proofs[0];

        if (proof.accountProof.length == 0 || proof.storageProof.length == 0) {
            revert SS_EMPTY_PROOF();
        }

        Checkpoint memory checkpoint = _getCheckpoint(uint48(proof.blockId));
        if (checkpoint.stateRoot != proof.rootHash) {
            revert SS_INVALID_CHECKPOINT();
        }

        // Try new EIP-7201 slot first, fall back to legacy slot during migration period.
        // Uses try-catch because SecureMerkleTrie.verifyInclusionProof reverts on path mismatch.
        try this.verifyMerkleProof(
            checkpoint.stateRoot,
            _remoteSignalService,
            slot,
            _signal,
            proof.accountProof,
            proof.storageProof
        ) { }
        catch {
            if (block.timestamp >= legacySlotExpiry) {
                revert SS_SIGNAL_NOT_RECEIVED();
            }
            LibTrieProof.verifyMerkleProof(
                checkpoint.stateRoot,
                _remoteSignalService,
                getLegacySignalSlot(_chainId, _app, _signal),
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
}
