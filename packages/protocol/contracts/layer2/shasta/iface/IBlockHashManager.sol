// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBlockHashProvider } from "contracts/layer2/based/IBlockHashProvider.sol";

/// @title IBlockHashManager
/// @notice Interface for the BlockHashManager contract that manages L2 block hashes
/// @custom:security-contact security@taiko.xyz
interface IBlockHashManager is IBlockHashProvider {
    /// @notice Saves the block hash for a given block ID.
    /// @param blockId The ID of the block whose hash is being saved.
    /// @param blockHash The hash of the block.
    function saveBlockHash(uint256 blockId, bytes32 blockHash) external;
}
