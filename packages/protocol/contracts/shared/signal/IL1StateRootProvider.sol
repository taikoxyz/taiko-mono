// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IL1StateRootProvider
/// @notice Provides L1 execution state roots authenticated by Etna L2 block derivation.
/// @custom:security-contact security@taiko.xyz
interface IL1StateRootProvider {
    /// @notice Returns the first L2 timestamp at which Etna is active.
    /// @dev Determines whether an L2 proof's blockId denotes a block number or timestamp.
    /// @return timestamp_ Etna activation timestamp in L2 Unix seconds.
    function etnaTimestamp() external view returns (uint64 timestamp_);

    /// @notice Returns the L1 state root recorded for an Etna L2 timestamp.
    /// @dev Reverts for pre-Etna timestamps, unavailable oracle entries, or zero roots. The L2
    /// header and prover authenticate the root; this interface does not authenticate an L1
    /// block number or block hash supplied by the caller.
    /// @param _l2Timestamp Timestamp of the L2 block that recorded the L1 anchor state root.
    /// @return stateRoot_ The authenticated L1 execution state root.
    function getL1StateRoot(uint64 _l2Timestamp) external view returns (bytes32 stateRoot_);
}
