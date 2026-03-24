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
    /// @dev Uses assembly to avoid Solidity's zero-initialization of the bytes32[] array
    ///      and the BlobSlice struct, since every slot is written before being read.
    ///      Original Solidity: new bytes32[](numBlobs) + loop + BlobSlice{...}
    /// @param _blobReference The blob locator to validate.
    /// @return slice_ The blob slice.
    function validateBlobReference(BlobReference memory _blobReference)
        internal
        view
        returns (BlobSlice memory slice_)
    {
        uint256 numBlobs = _blobReference.numBlobs;
        require(numBlobs > 0, NoBlobs());

        assembly {
            let ptr := mload(0x40)

            // Allocate bytes32[] array: [length, hash0, hash1, ...]
            let blobHashesPtr := ptr
            mstore(ptr, numBlobs)
            ptr := add(ptr, 0x20)

            let startIdx := and(mload(add(_blobReference, 0x00)), 0xffff) // blobStartIndex

            for { let i := 0 } lt(i, numBlobs) { i := add(i, 1) } {
                let h := blobhash(add(startIdx, i))
                if iszero(h) {
                    // revert BlobNotFound()
                    mstore(0x00, 0xf765f45e) // BlobNotFound() selector
                    revert(0x1c, 0x04)
                }
                mstore(ptr, h)
                ptr := add(ptr, 0x20)
            }

            // Allocate BlobSlice struct: [blobHashes_ptr, offset, timestamp]
            // Original Solidity: BlobSlice({blobHashes, offset, timestamp})
            slice_ := ptr
            mstore(ptr, blobHashesPtr)
            mstore(add(ptr, 0x20), and(mload(add(_blobReference, 0x40)), 0xffffff)) // offset
            // (uint24)
            mstore(add(ptr, 0x40), and(timestamp(), 0xffffffffffff)) // uint48(block.timestamp)
            ptr := add(ptr, 0x60)

            // Update free memory pointer
            mstore(0x40, ptr)
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BlobNotFound();
    error NoBlobs();
}
