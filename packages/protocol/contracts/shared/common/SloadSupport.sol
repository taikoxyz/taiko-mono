// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SloadSupport
/// @notice An abstract contract providing utilities for reading storage slots using the sload instruction
/// @dev This contract provides a safe and efficient way to read multiple storage slots in a single call
abstract contract SloadSupport {
    /// @notice Load multiple storage slots as bytes32
    /// @dev Reads the values of multiple storage slots using the sload instruction
    /// @param _slots The storage slots to load
    /// @return values_ An array of values at the specified storage slots
    function loadStorageSlots(bytes32[] calldata _slots)
        external
        view
        returns (bytes32[] memory values_)
    {
        uint256 size = _slots.length;
        values_ = new bytes32[](size);
        for (uint256 i; i < size; ++i) {
            bytes32 slot = _slots[i];
            assembly {
                mstore(add(add(values_, 0x20), mul(i, 0x20)), sload(slot))
            }
        }
    }
}
