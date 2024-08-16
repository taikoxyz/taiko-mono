// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ITierRouter
/// @notice Defines interface to return an ITierProvider
/// @custom:security-contact security@taiko.xyz
interface ITierRouter {
    /// @dev Returns the address of the TierProvider for a given block.
    /// @param blockId ID of the block.
    /// @return The address of the corresponding TierProvider.
    function getProvider(uint256 blockId) external view returns (address);
}
