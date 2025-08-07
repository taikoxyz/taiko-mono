// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibBlobs
/// @notice Library for the ShastaInbox contract
/// @custom:security-contact security@taiko.xyz
library LibBlobs {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Represents a segment of data that is stored in multiple consecutive blobs created
    /// in this transaction.
    struct BlobReference {
        /// @notice The starting index of the blob.
        uint48 blobStartIndex;
        /// @notice The number of blobs.
        uint32 numBlobs;
        /// @notice The offset within the blob data.
        uint32 offset;
    }

    /// @notice Represents a frame of data that is stored in multiple blobs. Note the size is
    /// encoded as a bytes32 at the offset location.
    struct BlobSlice {
        /// @notice The blobs containing the proposal's content.
        bytes32[] blobHashes;
        /// @notice The offset of the proposal's content in the containing blobs.
        uint32 offset;
    }

    // -------------------------------------------------------------------------
    // Functions
    // -------------------------------------------------------------------------

    /// @dev Validates a blob locator and converts it to a blob slice.
    /// @param _blobReference The blob locator to validate.
    /// @return _ The blob slice.
    function validateBlobReference(BlobReference memory _blobReference)
        internal
        view
        returns (BlobSlice memory)
    {
        if (_blobReference.numBlobs == 0) revert InvalidBlobReference();

        bytes32[] memory blobHashes = new bytes32[](_blobReference.numBlobs);
        for (uint256 i; i < _blobReference.numBlobs; ++i) {
            blobHashes[i] = blobhash(_blobReference.blobStartIndex + i);
            if (blobHashes[i] == 0) revert BlobNotFound();
        }

        return BlobSlice({ blobHashes: blobHashes, offset: _blobReference.offset });
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error BlobNotFound();
    error InvalidBlobReference();
}
