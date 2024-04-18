// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./IAddressResolver.sol";
import "./LibStrings.sol";

/// @title ISnapshot
/// @custom:security-contact security@taiko.xyz
interface ISnapshot {
    function snapshot() external returns (uint256);
}

/// @title LibSnapshot
/// @custom:security-contact security@taiko.xyz
library LibSnapshot {
    uint256 public constant SNAPSHOT_INTERVAL = 7200; // uint = 1 L1 block

    /// @notice Emitted when the Taiko token snapshot is taken.
    /// @param tkoAddress The Taiko token address.
    /// @param snapshotIdx The snapshot index.
    /// @param snapshotId The snapshot id.
    event TaikoTokenSnapshot(address tkoAddress, uint256 snapshotIdx, uint256 snapshotId);

    /// @dev Takes a snapshot every 200,000 L1 blocks which is roughly 27 days.
    /// @param _taikoToken The Taiko token address.
    /// @param _blockId The L1's block ID.
    /// @param _lastSnapshotIdx The latest snapshot's index.
    /// @return The new snapshot's index, 0 if no new snapshot is taken.
    function autoSnapshot(
        address _taikoToken,
        uint256 _blockId,
        uint64 _lastSnapshotIdx
    )
        internal
        returns (uint32)
    {
        if (_blockId % SNAPSHOT_INTERVAL != 0) return 0;

        // if snapshotIdx = type(uint32).max, we can handle L1 block id up to 4e14.
        uint32 snapshotIdx = uint32(_blockId / SNAPSHOT_INTERVAL + 1);
        if (snapshotIdx == _lastSnapshotIdx) return 0;

        uint256 snapshotId = ISnapshot(_taikoToken).snapshot();
        emit TaikoTokenSnapshot(_taikoToken, snapshotIdx, snapshotId);
        return snapshotIdx;
    }
}
