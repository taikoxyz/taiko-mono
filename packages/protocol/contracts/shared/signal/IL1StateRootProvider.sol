// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IL1StateRootProvider
/// @notice Provides authenticated L1 execution state roots for L2 signal verification.
/// @custom:security-contact security@taiko.xyz
interface IL1StateRootProvider {
    /// @notice Returns the authenticated L1 state root for a proof's blockId.
    /// @dev The current L2 timestamp selects checkpoint lookup before Etna and oracle lookup
    /// from Etna. Reverts for invalid IDs, missing/expired entries, or zero roots.
    /// @param _blockId L1 block number before Etna, L2 timestamp from Etna on.
    /// @return stateRoot_ The authenticated L1 execution state root.
    function getL1StateRoot(uint64 _blockId) external view returns (bytes32 stateRoot_);
}
