// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/libs/LibBlobs.sol";

/// @title MockLibBlobs
/// @notice Mock version of LibBlobs for testing that bypasses blobhash validation
library MockLibBlobs {
    /// @dev Mock validation that creates fake blob hashes without using blobhash opcode
    function validateBlobReference(LibBlobs.BlobReference memory _blobReference)
        internal
        pure
        returns (LibBlobs.BlobSlice memory)
    {
        if (_blobReference.numBlobs == 0) revert LibBlobs.InvalidBlobReference();

        bytes32[] memory blobHashes = new bytes32[](_blobReference.numBlobs);
        for (uint256 i; i < _blobReference.numBlobs; ++i) {
            // Create deterministic mock blob hashes
            blobHashes[i] = keccak256(abi.encode("mock_blob", _blobReference.blobStartIndex + i));
        }

        return LibBlobs.BlobSlice({
            blobHashes: blobHashes,
            offset: _blobReference.offset,
            timestamp: uint48(1) // Use fixed timestamp for testing
         });
    }
}
