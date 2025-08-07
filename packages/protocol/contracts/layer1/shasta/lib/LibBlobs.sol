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
    struct BlobLocator {
        /// @notice The starting index of the blob.
        uint48 blobStartIndex;
        /// @notice The number of blobs.
        uint32 numBlobs;
        /// @notice The offset within the blob data.
        uint32 offset;
    }

    /// @notice Represents a frame of data that is stored in multiple blobs. Note the size is
    /// encoded as a bytes32 at the offset location.
    struct BlobFrame {
        /// @notice The blobs containing the proposal's content.
        bytes32[] blobHashes;
        /// @notice The offset of the proposal's content in the containing blobs.
        uint32 offset;
    }

    /// @dev Validates a blob locator and converts it to a frame.
    /// @param _blobLocator The blob locator to validate.
    /// @return _ The frame.
    function validateBlobLocator(BlobLocator memory _blobLocator)
        internal
        view
        returns (BlobFrame memory)
    {
        if (_blobLocator.numBlobs == 0) revert InvalidBlobLocator();

        bytes32[] memory blobHashes = new bytes32[](_blobLocator.numBlobs);
        for (uint48 i; i < _blobLocator.numBlobs; ++i) {
            blobHashes[i] = blobhash(_blobLocator.blobStartIndex + i);
            if (blobHashes[i] == 0) revert BlobNotFound();
        }

        return BlobFrame({ blobHashes: blobHashes, offset: _blobLocator.offset });
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error BlobNotFound();
    error InvalidBlobLocator();
}
