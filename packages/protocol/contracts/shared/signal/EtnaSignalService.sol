// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SignalService } from "./SignalService.sol";

/// @title EtnaSignalService
/// @notice Verifies signals against counterpart chain state roots on either side of the bridge.
/// @custom:security-contact security@taiko.xyz
contract EtnaSignalService is SignalService {
    address private constant _BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    /// @notice True on L2, where Etna headers supply L1 state roots through EIP-4788.
    bool public immutable usesBeaconRoots;

    /// @notice Configures the shared implementation for one side of the bridge.
    /// @param _syncer The L1 Inbox or L2 Anchor proxy.
    /// @param _remote The counterpart SignalService proxy.
    /// @param _pauser Optional address authorized to pause the service.
    /// @param _usesBeaconRoots Whether to use the local EIP-4788 contract.
    constructor(
        address _syncer,
        address _remote,
        address _pauser,
        bool _usesBeaconRoots
    )
        SignalService(_syncer, _remote, _pauser)
    {
        usesBeaconRoots = _usesBeaconRoots;
    }

    /// @notice Returns the counterpart state root used to verify a signal proof.
    /// @param _id Remote checkpoint height, or on L2 the local timestamp of an Etna block.
    /// @return stateRoot_ The authenticated root. Reverts if the id has no usable root.
    function getStateRoot(uint64 _id) external view returns (bytes32 stateRoot_) {
        return _getStateRoot(_id);
    }

    /// @inheritdoc SignalService
    function _storeCheckpoint(Checkpoint calldata _checkpoint) internal override {
        if (usesBeaconRoots) {
            (bool ok, bytes32 root) = _beaconRoot(block.timestamp);
            if (!ok || root != bytes32(0)) revert SS_CHECKPOINTS_CLOSED();
        }
        // Keep VERSION and the old blockHash word in place across upgrades.
        _checkpoints[VERSION][_checkpoint.blockNumber].stateRoot = _checkpoint.stateRoot;
    }

    /// @inheritdoc SignalService
    function _getCheckpoint(uint48 _blockNumber)
        internal
        view
        override
        returns (Checkpoint memory checkpoint_)
    {
        bytes32 root = _checkpoints[VERSION][_blockNumber].stateRoot;
        if (root == bytes32(0)) revert SS_CHECKPOINT_NOT_FOUND();
        return Checkpoint({ blockNumber: _blockNumber, blockHash: bytes32(0), stateRoot: root });
    }

    /// @inheritdoc SignalService
    function _getStateRoot(uint64 _blockId) internal view override returns (bytes32 stateRoot_) {
        if (_blockId <= type(uint48).max) {
            stateRoot_ = _checkpoints[VERSION][uint48(_blockId)].stateRoot;
        }
        if (stateRoot_ == bytes32(0) && usesBeaconRoots) {
            (, stateRoot_) = _beaconRoot(_blockId);
        }
        if (stateRoot_ == bytes32(0)) revert SS_CHECKPOINT_NOT_FOUND();
    }

    /// @dev EIP-4788 accepts a single ABI word without a function selector.
    /// @param _timestamp L2 block timestamp to query.
    /// @return ok_ Whether the call returned exactly one word.
    /// @return root_ The returned root, or zero on failure.
    function _beaconRoot(uint256 _timestamp) private view returns (bool ok_, bytes32 root_) {
        (bool success, bytes memory data) = _BEACON_ROOTS.staticcall(abi.encode(_timestamp));
        ok_ = success && data.length == 32;
        if (ok_) root_ = abi.decode(data, (bytes32));
    }

    error SS_CHECKPOINTS_CLOSED();
}
