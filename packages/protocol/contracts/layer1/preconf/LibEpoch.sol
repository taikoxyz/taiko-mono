// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibEpoch
/// @custom:security-contact security@taiko.xyz
library LibEpoch {
    uint256 internal constant SECONDS_IN_SLOT = 12;
    uint256 internal constant SECONDS_IN_EPOCH = SECONDS_IN_SLOT * 32;
    uint256 internal constant TWO_EPOCHS = 2 * SECONDS_IN_EPOCH;

    error TimestampBeforeBeaconGenesis();

    /// @dev Calculates the current and next epoch timestamps based on the given timestamp and the
    /// beacon genesis timestamp.
    /// @param _timestamp The current timestamp.
    /// @param _beaconGenesisTimestamp The genesis timestamp of the beacon.
    /// @return currentEpochTimestamp_ The timestamp marking the start of the current epoch.
    /// @return nextEopocTimestamp_ The timestamp marking the start of the next epoch.
    function getEpochTimestamp(
        uint256 _timestamp,
        uint256 _beaconGenesisTimestamp
    )
        internal
        pure
        returns (uint256 currentEpochTimestamp_, uint256 nextEopocTimestamp_)
    {
        require(_timestamp >= _beaconGenesisTimestamp, TimestampBeforeBeaconGenesis());
        unchecked {
            uint256 timePassedSinceGenesis = _timestamp - _beaconGenesisTimestamp;
            uint256 timeToCurrentEpochFromGenesis =
                (timePassedSinceGenesis / SECONDS_IN_EPOCH) * SECONDS_IN_EPOCH;
            currentEpochTimestamp_ = _beaconGenesisTimestamp + timeToCurrentEpochFromGenesis;
            nextEopocTimestamp_ = currentEpochTimestamp_ + SECONDS_IN_EPOCH;
        }
    }
}
