// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IBlobRefRegistry
/// @notice Interface for accessing and registering blob hashes from transactions
/// @custom:security-contact security@taiko.xyz
interface IBlobRefRegistry {
    /// @dev Struct containing blob hashes from a specific block
    /// @param blockNumber The block number where the blobs were included
    /// @param blobs Array of blob hashes
    struct BlobRef {
        uint256 blockNumber;
        bytes32[] blobhashes;
    }

    /// @notice Emitted when a blob ref hash is registered
    /// @param refHash The keccak256 hash of the encoded blob ref
    /// @param ref The blob ref
    event Registered(bytes32 indexed refHash, BlobRef ref);

    /// @notice Validates blobs at given indices, return a ref object, then register the ref hash
    /// for later usage
    /// @param blobIndices Array of blob indices to retrieve
    /// @return refHash_ The keccak256 hash of the encoded blob ref
    /// @return ref_ The retrieved blob data including block number and blob hashes
    /// @dev Should revert if any blob index is invalid or if no blobs are provided
    function registerRef(uint256[] calldata blobIndices)
        external
        returns (bytes32 refHash_, BlobRef memory ref_);

    /// @notice Validates blobs at given indices and return a ref object
    /// @param _blobIndices Array of blob indices to retrieve
    /// @return The blob data including block number and blob hashes
    /// @dev Should revert if any blob index is invalid or if no blobs are provided
    function getRef(uint256[] calldata _blobIndices) external view returns (BlobRef memory);

    /// @notice Checks if a blob reference has been previously registered
    /// @param _refHash The keccak256 hash of the encoded blob ref
    /// @return True if the blob ref hash exists in the registry, false otherwise
    function isRefRegistered(bytes32 _refHash) external view returns (bool);
}
