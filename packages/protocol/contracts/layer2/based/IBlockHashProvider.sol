// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBlockHashProvider
/// @notice Interface for retrieving block hashes.
/// @custom:security-contact security@taiko.xyz
interface IBlockHashProvider {
    /// @notice Retrieves the block hash for a given block ID.
    /// @param _blockId The ID of the block whose hash is being requested.
    /// @return blockHash_ The block hash of the specified block ID, or 0 if no hash is found.
    function getBlockHash(uint256 _blockId) external view returns (bytes32 blockHash_);
}
