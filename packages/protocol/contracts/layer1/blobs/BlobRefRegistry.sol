// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IBlobRefRegistry.sol";

/// @title BlobRefRegistry
/// @custom:security-contact security@taiko.xyz
contract BlobRefRegistry is IBlobRefRegistry {
    error NoBlobsProvided();
    error BlobNotFound();

    /// @dev A mapping of the hash of a blob ref to the timestamp when it was saved
    mapping(bytes32 refHash => uint256 timestamp) private _registeredHashes;

    /// @inheritdoc IBlobRefRegistry
    function registerRef(uint256[] calldata blobIndices)
        external
        returns (bytes32 refHash, BlobRef memory ref)
    {
        ref = _getRef(blobIndices);
        refHash = _registerRefHash(ref);
        emit Registered(refHash, ref);
    }

    /// @inheritdoc IBlobRefRegistry
    function getRef(uint256[] calldata blobIndices) external view returns (BlobRef memory) {
        return _getRef(blobIndices);
    }

    /// @inheritdoc IBlobRefRegistry
    function isRefRegistered(bytes32 refHash) external view returns (bool) {
        return _registeredHashes[refHash] != 0;
    }

    /// @dev Registers the hash of a blob ref to the registry
    /// @param ref The blob ref whose hash to save
    /// @return The hash of the blob source
    function _registerRefHash(BlobRef memory ref) private returns (bytes32) {
        bytes32 hash = keccak256(abi.encode(ref));
        _registeredHashes[hash] = block.timestamp;
        emit Registered(hash, ref);
        return hash;
    }

    /// @dev Retrieves the blob ref for given blob indices
    /// @param blobIndices The indices of the blobhashes to retrieve
    /// @return The blob ref constructed from the block's number and the list of blob hashes
    function _getRef(uint256[] calldata blobIndices) private view returns (BlobRef memory) {
        uint256 nBlobs = blobIndices.length;
        require(nBlobs != 0, NoBlobsProvided());

        bytes32[] memory blobhashes = new bytes32[](nBlobs);
        for (uint256 i; i < nBlobs; ++i) {
            blobhashes[i] = _blobHash(blobIndices[i]);
            require(blobhashes[i] != 0, BlobNotFound());
        }

        return BlobRef(block.number, blobhashes);
    }

    function _blobHash(uint256 blobIndex) internal view virtual returns (bytes32) {
        return blobhash(blobIndex);
    }
}
