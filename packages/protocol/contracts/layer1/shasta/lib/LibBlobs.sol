// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibBlobs
/// @notice Library for the ShastaInbox contract
/// @custom:security-contact security@taiko.xyz
library LibBlobs {
    // -------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------

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
        /// @notice The timestamp when the frame was created.
        uint48 createdAt;
    }

    // -------------------------------------------------------------------
    // Functions
    // -------------------------------------------------------------------

    /// @dev Validates a blob locator and converts it to a frame.
    /// @param _blobLocator The blob locator to validate.
    /// @return _ The frame.
    function validateBlobLocator(BlobLocator memory _blobLocator)
        internal
        view
        returns (BlobFrame memory)
    {
        require(_blobLocator.numBlobs != 0, InvalidBlobLocator());

        bytes32[] memory blobHashes = new bytes32[](_blobLocator.numBlobs);
        for (uint256 i; i < _blobLocator.numBlobs; ++i) {
            blobHashes[i] = blobhash(_blobLocator.blobStartIndex + i);
            require(blobHashes[i] != 0, BlobNotFound());
        }

        return BlobFrame({
            blobHashes: blobHashes,
            offset: _blobLocator.offset,
            createdAt: uint48(block.timestamp)
        });
    }

    // -------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------

    error BlobNotFound();
    error InvalidBlobLocator();
}
