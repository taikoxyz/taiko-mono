// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IBlobRefRegistry.sol";

/// @title BlobRefRegistry
/// @custom:security-contact security@taiko.xyz
contract BlobRefRegistry is IBlobRefRegistry {
    /// @dev A mapping of the hash of a blob ref to the timestamp when it was saved
    mapping(bytes32 refHash => uint256 timestamp) private _registeredHashes;

    // -------------------------------------------------------------------------
    // Public Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IBlobRefRegistry
    function registerRef(uint256[] calldata _blobIndices)
        external
        returns (bytes32 refHash_, BlobRef memory ref_)
    {
        ref_ = _getRef(_blobIndices);
        refHash_ = _registerRefHash(ref_);
    }

    /// @inheritdoc IBlobRefRegistry
    function getRef(uint256[] calldata _blobIndices) external view returns (BlobRef memory) {
        return _getRef(_blobIndices);
    }

    /// @inheritdoc IBlobRefRegistry
    function isRefRegistered(bytes32 _refHash) external view returns (bool) {
        return _registeredHashes[_refHash] != 0;
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @dev Registers the hash of a blob ref to the registry
    /// @param _ref The blob ref whose hash to save
    /// @return hash_ The hash of the blob source
    function _registerRefHash(BlobRef memory _ref) private returns (bytes32 hash_) {
        hash_ = keccak256(abi.encode(_ref));
        _registeredHashes[hash_] = block.timestamp;
        emit Registered(hash_, _ref);
    }

    /// @dev Retrieves the blob ref for given blob indices
    /// @param _blobIndices The indices of the blobhashes to retrieve
    /// @return The blob ref constructed from the block's number and the list of blob hashes
    function _getRef(uint256[] calldata _blobIndices) private view returns (BlobRef memory) {
        uint256 nBlobs = _blobIndices.length;
        if (nBlobs == 0) revert EmptyBlobIndices();

        bytes32[] memory blobhashes = new bytes32[](nBlobs);
        for (uint256 i; i < nBlobs; ++i) {
            blobhashes[i] = blobhash(_blobIndices[i]);
            if (blobhashes[i] == 0) revert BlobNotFound();
        }

        return BlobRef(block.number, blobhashes);
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error EmptyBlobIndices();
    error BlobNotFound();
}
