// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EssentialContract } from "contracts/shared/common/EssentialContract.sol";
import { IBlockHashManager } from "../iface/IBlockHashManager.sol";

/// @title BlockHashManager
/// @notice Contract that stores and provides block hashes for verification
/// @dev This contract allows authorized entities to save block headers for later retrieval
/// @custom:security-contact security@taiko.xyz
contract BlockHashManager is EssentialContract, IBlockHashManager {
    /// @dev Address authorized to save block headers
    address public immutable authorized;

    /// @dev Mapping from block ID to block hash
    mapping(uint256 blockId => bytes32 blockHash) private _blockHashes;

    uint256[49] private __gap;

    /// @notice Emitted when a new block hash is saved
    /// @param blockId The ID of the block
    /// @param blockHash The hash of the block
    event BlockHashSaved(uint256 indexed blockId, bytes32 blockHash);

    constructor(address _authorized) nonZeroAddr(_authorized) EssentialContract() {
        authorized = _authorized;
    }

    /// @notice Initialize the contract
    /// @param _owner The owner of the contract
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Saves a block header for a given block ID
    /// @param _blockId The ID of the block
    /// @param _blockHash The hash of the block
    /// @dev Only the authorized address can call this function
    function saveBlockHash(uint256 _blockId, bytes32 _blockHash) external onlyFrom(authorized) {
        if (_blockHash == bytes32(0)) revert InvalidBlockHash();
        if (_blockHashes[_blockId] != bytes32(0)) revert BlockAlreadyExists();

        _blockHashes[_blockId] = _blockHash;
        emit BlockHashSaved(_blockId, _blockHash);
    }

    /// @notice Retrieves the block hash for a given block ID
    /// @param blockId The ID of the block whose hash is being requested
    /// @return _ The block hash of the specified block ID, or 0 if no hash is found
    function getBlockHash(uint256 blockId) external view returns (bytes32) {
        return _blockHashes[blockId];
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error InvalidBlockHash();
    error BlockAlreadyExists();
}
