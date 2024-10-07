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
    /// @return The timestamp marking the start of the current epoch.
    function toEpochTimestamp(
        uint256 _timestamp,
        uint256 _beaconGenesisTimestamp
    )
        internal
        pure
        returns (uint256)
    {
        require(_timestamp >= _beaconGenesisTimestamp, TimestampBeforeBeaconGenesis());
        unchecked {
            uint256 timePassedSinceGenesis = _timestamp - _beaconGenesisTimestamp;
            uint256 timeToCurrentEpochFromGenesis =
                (timePassedSinceGenesis / SECONDS_IN_EPOCH) * SECONDS_IN_EPOCH;
            return _beaconGenesisTimestamp + timeToCurrentEpochFromGenesis;
        }
    }

    /// @dev Calculates the timestamp for the next epoch based on the given epoch timestamp.
    /// @param _epochTimestamp The timestamp of the current epoch.
    /// @return The timestamp of the next epoch.
    function nextEpoch(uint256 _epochTimestamp) internal pure returns (uint256) {
        unchecked {
            return _epochTimestamp + SECONDS_IN_EPOCH;
        }
    }

    /// @dev Calculates the timestamp for the previous epoch based on the given epoch timestamp.
    /// @param _epochTimestamp The timestamp of the current epoch.
    /// @return The timestamp of the previous epoch.
    function prevEpoch(uint256 _epochTimestamp) internal pure returns (uint256) {
        return _epochTimestamp - SECONDS_IN_EPOCH;
    }
}
