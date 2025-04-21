// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBlockInfoProvider
/// @notice Interface for retrieving extra block information.
interface IBlockInfoProvider {
    /// @notice Retrieves the block hash for a given block
    /// @param blockId The ID of the block
    /// @return _ The block hash of the specified block ID, or 0 if not found
    function getBlockHash(uint256 blockId) external view returns (bytes32);

    /// @notice Retrieves the block hash for a given block
    /// @param blockId The ID of the block
    /// @return _ The coinbase address of the specified block ID, or address(0) if not found
    function getBlockCoinbase(uint256 blockId) external view returns (address);
}
