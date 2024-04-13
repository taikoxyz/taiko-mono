// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./IAddressResolver.sol";
import "./LibStrings.sol";

/// @title LibAutoSnapshot
/// @custom:security-contact security@taiko.xyz
interface ISnapshot {
    function snapshot() external returns (uint256);
}

library LibAutoSnapshot {
    uint256 public constant SNAPSHOT_INTERVAL = 200_000; // uint = 1 L1 block
    /// @notice Emitted when the Taiko token snapshot is taken.
    /// @param tkoAddress The Taiko token address.
    /// @param snapshotIdx The snapshot index.
    /// @param snapshotId The snapshot id.

    event TaikoTokenSnapshotTaken(address tkoAddress, uint256 snapshotIdx, uint256 snapshotId);

    /// @dev Takes a snapshot every 200,000 L1 blocks which is roughly 27 days.
    /// @param _resolver The IAddressResolve address.
    /// @param _blockId The L1's block ID.
    /// @param _lastSnapshotIdx The latest snapshot's index.
    /// @return The new snapshot's index, 0 if no new snapshot is taken.
    function autoSnapshot(
        IAddressResolver _resolver,
        uint256 _blockId,
        uint64 _lastSnapshotIdx
    )
        internal
        returns (uint64)
    {
        if (_blockId % SNAPSHOT_INTERVAL != 0) return 0;

        uint256 snapshotIdx = _blockId / SNAPSHOT_INTERVAL;
        if (snapshotIdx == 0 || snapshotIdx == _lastSnapshotIdx) {
            return 0;
        }

        address taikoToken = _resolver.resolve(LibStrings.B_TAIKO_TOKEN, true);
        if (taikoToken == address(0)) return 0;

        uint256 snapshotId = ISnapshot(taikoToken).snapshot();
        emit TaikoTokenSnapshotTaken(taikoToken, snapshotIdx, snapshotId);
        return uint64(snapshotIdx);
    }
}
