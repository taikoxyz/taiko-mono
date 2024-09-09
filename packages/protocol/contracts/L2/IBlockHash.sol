// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title IBlockHash
/// @notice Interface for retrieving block hashes.
interface IBlockHash {
    /// @notice Retrieves the block hash for a given block ID.
    /// @param blockId The ID of the block whose hash is being requested.
    /// @return The block hash of the specified block ID.
    function getBlockHash(uint256 blockId) external view returns (bytes32);
}
