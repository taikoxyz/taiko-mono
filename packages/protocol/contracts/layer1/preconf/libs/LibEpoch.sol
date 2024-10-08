// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibEpoch
/// @custom:security-contact security@taiko.xyz
library LibEpoch {
    uint256 internal constant SLOTS_IN_EPOCH = 32;
    uint256 internal constant SECONDS_IN_SLOT = 12;

    /// @dev Calculates the current and next epoch timestamps based on the given timestamp and the
    /// beacon genesis timestamp.
    /// @param _slot The current timestamp.
    /// @return The timestamp marking the start of the current epoch.
    function toEpochFirstSlot(uint256 _slot) internal pure returns (uint256) {
        return (_slot / SLOTS_IN_EPOCH) * SLOTS_IN_EPOCH;
    }

    /// @dev Converts the slot number to its corresponding block timestamp.
    /// @param _slot The slot number to be converted.
    /// @param _beaconGenesisTimestamp The genesis timestamp of the beacon.
    /// @param _beaconGenesisSlot The slot number at the genesis of the beacon.
    /// @return The timestamp corresponding to the start of the specified slot.
    function slotToTimestamp(
        uint256 _slot,
        uint256 _beaconGenesisTimestamp,
        uint256 _beaconGenesisSlot
    )
        internal
        pure
        returns (uint256)
    {
        return (_slot - _beaconGenesisSlot) * SECONDS_IN_SLOT + _beaconGenesisTimestamp;
    }
}
