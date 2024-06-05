// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ITierRouter
/// @notice Defines interface to return an ITierProvider
/// @custom:security-contact security@taiko.xyz
interface ITierRouter {
    /// @dev Returns the address of the TierProvider for a given block.
    /// @param blockGroup ID of the block group.
    /// @return The address of the corresponding TierProvider.
    function getProvider(uint256 blockGroup) external view returns (address);
}
