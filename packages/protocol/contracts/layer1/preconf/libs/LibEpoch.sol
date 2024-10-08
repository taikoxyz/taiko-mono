// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibEpoch
/// @custom:security-contact security@taiko.xyz
library LibEpoch {
    uint256 internal constant SLOTS_IN_EPOCH = 32;
    uint256 internal constant SECONDS_IN_SLOT = 12;
    uint256 internal constant SECONDS_IN_EPOCH = SECONDS_IN_SLOT * SLOTS_IN_EPOCH;
    uint256 internal constant TWO_EPOCHS = 2 * SECONDS_IN_EPOCH;

    /// @dev Calculates the current and next epoch timestamps based on the given timestamp and the
    /// beacon genesis timestamp.
    /// @param _slot The current timestamp.
    /// @return The timestamp marking the start of the current epoch.
    function toEpochFirstSlot(uint256 _slot) internal pure returns (uint256) {
        return (_slot / SLOTS_IN_EPOCH) * SLOTS_IN_EPOCH;
    }

    /// @dev Convert the slot id to its block timestamp on Ethereum.
    /// @param _slot The slot number to convert.
    /// @return The timestamp corresponding to the start of the given slot.
    function slotToTimestamp(uint256 _slot) internal pure returns (uint256) {
        // TODO(daniel): fix this.
        return _slot * SECONDS_IN_SLOT;
    }
}
