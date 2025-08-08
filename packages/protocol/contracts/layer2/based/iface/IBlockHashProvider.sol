// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBlockHashProvider
/// @notice Interface for retrieving block hashes.
interface IBlockHashProvider {
    /// @notice Retrieves the block hash for a given block ID.
    /// @param blockId The ID of the block whose hash is being requested.
    /// @return _ The block hash of the specified block ID, or 0 if no hash is found.
    function getBlockHash(uint256 blockId) external view returns (bytes32);
}
