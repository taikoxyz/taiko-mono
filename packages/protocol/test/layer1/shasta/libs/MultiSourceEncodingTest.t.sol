// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProposedEventEncoder } from "src/layer1/shasta/libs/LibProposedEventEncoder.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { console2 } from "forge-std/src/console2.sol";

contract MultiSourceEncodingTest is Test {
    
    function test_debugEncoding() public {
        // Create a simple payload with single source
        IInbox.ProposedEventPayload memory payload;
        
        payload.proposal.id = 1;
        payload.derivation.originBlockNumber = 100;
        payload.derivation.basefeeSharingPctg = 0;
        
        // Create single source
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = bytes32(uint256(1));
        blobHashes[1] = bytes32(uint256(2));
        
        payload.derivation.sources = new IInbox.DerivationSource[](1);
        payload.derivation.sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: 100,
                timestamp: 1000
            })
        });
        
        // Encode and log
        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        console2.log("Encoded length:", encoded.length);
        console2.logBytes(encoded);
        
        // Decode and verify
        IInbox.ProposedEventPayload memory decoded = LibProposedEventEncoder.decode(encoded);
        
        assertEq(decoded.proposal.id, 1);
        assertEq(decoded.derivation.sources.length, 1);
        assertEq(decoded.derivation.sources[0].blobSlice.offset, 100);
        assertEq(decoded.derivation.sources[0].blobSlice.blobHashes.length, 2);
    }
    
    function test_calculateSizeIsCorrect() public {
        // Test that calculateProposedEventSize returns correct size
        uint256 numSources = 1;
        uint256 totalBlobHashes = 2;
        
        uint256 expectedSize = LibProposedEventEncoder.calculateProposedEventSize(
            numSources, 
            totalBlobHashes
        );
        
        // Create actual payload
        IInbox.ProposedEventPayload memory payload;
        bytes32[] memory blobHashes = new bytes32[](2);
        
        payload.derivation.sources = new IInbox.DerivationSource[](1);
        payload.derivation.sources[0].blobSlice.blobHashes = blobHashes;
        
        bytes memory encoded = LibProposedEventEncoder.encode(payload);
        
        console2.log("Expected size:", expectedSize);
        console2.log("Actual size:", encoded.length);
        
        assertEq(encoded.length, expectedSize);
    }
}