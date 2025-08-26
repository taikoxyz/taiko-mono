// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";

/// @title BlobTestUtils
/// @notice Simple utilities for blob-related testing
contract BlobTestUtils is Test {

    function _setupBlobHashes() internal {
        // Setup test blob hashes for EIP-4844
        bytes32[] memory hashes = new bytes32[](9);
        for (uint256 i = 0; i < 9; i++) {
            hashes[i] = keccak256(abi.encode("blob", i));
        }
        // Mock the blobhash function for testing
        vm.blobhashes(hashes);
    }
}