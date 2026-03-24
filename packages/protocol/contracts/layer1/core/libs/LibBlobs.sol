// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title LibBlobs
/// @notice Library for handling blobs.
/// @custom:security-contact security@taiko.xyz
library LibBlobs {
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
    /// @return slice_ The blob slice.
    function validateBlobReference(BlobReference memory _blobReference)
        internal
        view
        returns (BlobSlice memory slice_)
    {
        uint256 numBlobs = _blobReference.numBlobs;
        require(numBlobs > 0, NoBlobs());

        // Fast path: single blob (common case)
        if (numBlobs == 1) {
            bytes32 h = blobhash(_blobReference.blobStartIndex);
            require(h != 0, BlobNotFound());
            bytes32[] memory blobHashes;
            assembly {
                blobHashes := mload(0x40)
                mstore(blobHashes, 1) // length = 1
                mstore(add(blobHashes, 0x20), h) // blobHashes[0]
                mstore(0x40, add(blobHashes, 0x40)) // update free memory pointer
            }
            slice_.blobHashes = blobHashes;
            slice_.offset = _blobReference.offset;
            slice_.timestamp = uint48(block.timestamp);
            return slice_;
        }

        bytes32[] memory blobHashes = new bytes32[](numBlobs);
        uint256 startIndex = _blobReference.blobStartIndex;
        for (uint256 i; i < numBlobs; ++i) {
            bytes32 h = blobhash(startIndex + i);
            require(h != 0, BlobNotFound());
            blobHashes[i] = h;
        }

        slice_.blobHashes = blobHashes;
        slice_.offset = _blobReference.offset;
        slice_.timestamp = uint48(block.timestamp);
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BlobNotFound();
    error NoBlobs();
}
