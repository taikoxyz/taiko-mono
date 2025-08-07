// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBlockHashManager } from "../iface/IBlockHashManager.sol";

/// @title BlockHashManager
/// @notice Contract that stores and provides block hashes for verification
/// @dev This contract allows authorized entities to save block headers for later retrieval
/// @custom:security-contact security@taiko.xyz
contract BlockHashManager is IBlockHashManager {
    /// @dev Address authorized to save block headers
    address public immutable authorized;

    /// @dev Mapping from block ID to block hash
    mapping(uint256 blockId => bytes32 blockHash) private _blockHashes;

    /// @notice Emitted when a new block hash is saved
    /// @param blockId The ID of the block
    /// @param blockHash The hash of the block
    event BlockHashSaved(uint256 indexed blockId, bytes32 blockHash);

    /// @dev Restricts function access to only the authorized address
    modifier onlyAuthorized() {
        if (msg.sender != authorized) revert Unauthorized();
        _;
    }

    constructor(address _authorized) {
        if (_authorized == address(0)) revert InvalidAuthorizedAddress();
        authorized = _authorized;
    }

    /// @notice Saves a block header for a given block ID
    /// @param _blockId The ID of the block
    /// @param _blockHash The hash of the block
    /// @dev Only the authorized address can call this function
    function saveBlockHash(uint256 _blockId, bytes32 _blockHash) external onlyAuthorized {
        if (_blockHash == bytes32(0)) revert InvalidBlockHash();
        if (_blockHashes[_blockId] != bytes32(0)) revert BlockAlreadyExists();

        _blockHashes[_blockId] = _blockHash;
        emit BlockHeaderSaved(_blockId, _blockHash);
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

    error Unauthorized();
    error InvalidAuthorizedAddress();
    error InvalidBlockHash();
    error BlockAlreadyExists();
}
