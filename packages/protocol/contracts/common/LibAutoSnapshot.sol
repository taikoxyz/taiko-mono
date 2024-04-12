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
    /// @notice Emitted when the Taiko token snapshot is taken.
    /// @param tkoAddress The Taiko token address.
    /// @param id The snapshot id.
    event TaikoTokenSnapshotTaken(address tkoAddress, uint256 id);

    // Take a snapshot every 100,000 L1 blocks which is roughly 13 days and 21 hours.
    function autoSnapshot(IAddressResolver _resolver, uint256 _blockId) internal {
        if (_blockId % 100_000 != 0) return;

        address taikoToken = _resolver.resolve(LibStrings.B_TAIKO_TOKEN, true);
        if (taikoToken != address(0)) {
            uint256 id = ISnapshot(taikoToken).snapshot();
            emit TaikoTokenSnapshotTaken(taikoToken, id);
        }
    }
}
