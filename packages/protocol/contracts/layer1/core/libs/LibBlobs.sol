// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibBlobs
/// @notice Library for handling blobs.
/// @custom:security-contact security@taiko.xyz
library LibBlobs {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    uint256 internal constant FIELD_ELEMENT_BYTES = 32;
    uint256 internal constant BLOB_FIELD_ELEMENTS = 4096;
    uint256 internal constant BLOB_BYTES = BLOB_FIELD_ELEMENTS * FIELD_ELEMENT_BYTES;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Represents a segment of data that is stored in multiple consecutive blobs created
    /// in this transaction.
    struct BlobReference {
        /// @notice The starting index of the blob.
        uint16 blobStartIndex;
        /// @notice The number of blobs.
        uint16 numBlobs;
        /// @notice The field-element offset within the blob data.
        uint24 offset;
    }

    /// @notice Represents a frame of data that is stored in multiple blobs. Note the size is
    /// encoded as a bytes32 at the offset location.
    struct BlobSlice {
        /// @notice The blobs containing the proposal's content.
        bytes32[] blobHashes;
        /// @notice The byte offset of the proposal's content in the containing blobs.
        uint24 offset;
        /// @notice The timestamp when the frame was created.
        uint48 timestamp;
    }

    // ---------------------------------------------------------------
    // Functions
    // ---------------------------------------------------------------

    /// @dev Validates a blob locator and converts it to a blob slice.
    /// @param _blobReference The blob locator to validate.
    /// @return The blob slice.
    function validateBlobReference(BlobReference memory _blobReference)
        internal
        view
        returns (BlobSlice memory)
    {
        require(_blobReference.numBlobs > 0, NoBlobs());

        bytes32[] memory blobHashes = new bytes32[](_blobReference.numBlobs);
        for (uint256 i; i < _blobReference.numBlobs; ++i) {
            blobHashes[i] = blobhash(_blobReference.blobStartIndex + i);
            require(blobHashes[i] != 0, BlobNotFound());
        }

        return BlobSlice({
            blobHashes: blobHashes,
            offset: _blobReference.offset,
            timestamp: uint48(block.timestamp)
        });
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BlobNotFound();
    error NoBlobs();
}
