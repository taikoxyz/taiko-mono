// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBlockHashProvider } from "contracts/layer2/based/IBlockHashProvider.sol";

/// @title IAnchor
/// @notice Interface for the Anchor contract that manages L2 state synchronization with L1
/// @dev This contract stores critical state information for L2 block production and gas management
/// @custom:security-contact security@taiko.xyz
interface IBlockHashManager is IBlockHashProvider {
    /// @notice Saves the block hash for a given block ID.
    /// @param blockId The ID of the block whose hash is being saved.
    /// @param blockHash The hash of the block.
    function saveBlockHash(uint256 blockId, bytes32 blockHash) external;
}
