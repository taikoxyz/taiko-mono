// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { InboxStateManager } from "../../../contracts/layer1/shasta/impl/InboxStateManager.sol";

// Mock contract to expose private functions for testing
contract InboxStateManagerHarness is InboxStateManager {
    constructor(
        address _inbox,
        bytes32 _genesisBlockHash,
        uint256 _ringBufferSize
    )
        InboxStateManager(_inbox, _genesisBlockHash, _ringBufferSize)
    { }

    function encodeSlotReuseMarker(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        external
        pure
        returns (uint256)
    {
        return _encodeSlotReuseMarker(_proposalId, _parentClaimHash);
    }

    function decodeSlotReuseMarker(uint256 _slotReuseMarker)
        external
        pure
        returns (uint48 proposalId_, bytes32 partialParentClaimHash_)
    {
        return _decodeSlotReuseMarker(_slotReuseMarker);
    }
}

/// @title InboxStateManagerEncodingTest
/// @notice Tests for the encoding/decoding functions in InboxStateManager
/// @custom:security-contact security@taiko.xyz
contract InboxStateManagerEncodingTest is Test {
    InboxStateManagerHarness harness;

    function setUp() public {
        address inbox = address(0x1);
        bytes32 genesisHash = keccak256("GENESIS");
        harness = new InboxStateManagerHarness(inbox, genesisHash, 1000);
    }

    // -------------------------------------------------------------------------
    // Basic Encoding/Decoding Tests
    // -------------------------------------------------------------------------

    function test_encodeDecodeBasic() public view {
        uint48 proposalId = 12_345;
        bytes32 parentClaimHash = keccak256("PARENT_CLAIM");

        uint256 encoded = harness.encodeSlotReuseMarker(proposalId, parentClaimHash);
        (uint48 decodedId, bytes32 decodedPartialHash) = harness.decodeSlotReuseMarker(encoded);

        assertEq(decodedId, proposalId);
        // The partial hash should be the parent claim hash with the lowest 48 bits zeroed out
        assertEq(decodedPartialHash, bytes32(uint256(parentClaimHash) >> 48 << 48));
    }

    function test_encodeDecode_maxValues() public view {
        uint48 maxProposalId = type(uint48).max;
        bytes32 maxParentHash = bytes32(type(uint256).max);

        uint256 encoded = harness.encodeSlotReuseMarker(maxProposalId, maxParentHash);
        (uint48 decodedId, bytes32 decodedPartialHash) = harness.decodeSlotReuseMarker(encoded);

        assertEq(decodedId, maxProposalId);
        assertEq(decodedPartialHash, bytes32(uint256(maxParentHash) >> 48 << 48));
    }

    function test_encodeDecode_zeroValues() public view {
        uint48 proposalId = 0;
        bytes32 parentClaimHash = bytes32(0);

        uint256 encoded = harness.encodeSlotReuseMarker(proposalId, parentClaimHash);
        (uint48 decodedId, bytes32 decodedPartialHash) = harness.decodeSlotReuseMarker(encoded);

        assertEq(decodedId, proposalId);
        assertEq(decodedPartialHash, bytes32(0));
    }

    // -------------------------------------------------------------------------
    // Fuzz Tests
    // -------------------------------------------------------------------------

    function testFuzz_encodeDecodeRoundTrip(
        uint48 proposalId,
        bytes32 parentClaimHash
    )
        public
        view
    {
        uint256 encoded = harness.encodeSlotReuseMarker(proposalId, parentClaimHash);
        (uint48 decodedId, bytes32 decodedPartialHash) = harness.decodeSlotReuseMarker(encoded);

        assertEq(decodedId, proposalId);
        // Check that the high 208 bits are preserved
        assertEq(uint256(decodedPartialHash) >> 48, uint256(parentClaimHash) >> 48);
        // Check that the low 48 bits are zeroed
        assertEq(uint256(decodedPartialHash) & ((1 << 48) - 1), 0);
    }

    function testFuzz_encodingBitLayout(uint48 proposalId, bytes32 parentClaimHash) public view {
        uint256 encoded = harness.encodeSlotReuseMarker(proposalId, parentClaimHash);

        // Check that proposal ID is in the high 48 bits
        uint256 extractedProposalId = encoded >> 208;
        assertEq(extractedProposalId, uint256(proposalId));

        // Check that the parent claim hash (minus lowest 48 bits) is in the low 208 bits
        uint256 extractedPartialHash = encoded & ((1 << 208) - 1);
        uint256 expectedPartialHash = uint256(parentClaimHash) >> 48;
        assertEq(extractedPartialHash, expectedPartialHash);
    }

    // -------------------------------------------------------------------------
    // Edge Case Tests
    // -------------------------------------------------------------------------

    function test_encodeDecode_differentParentHashesSamePartial() public view {
        uint48 proposalId = 42;

        // Two different hashes that share the same high 208 bits
        bytes32 hash1 =
            bytes32(uint256(0xABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890));
        bytes32 hash2 =
            bytes32(uint256(0xABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF0000000000));

        uint256 encoded1 = harness.encodeSlotReuseMarker(proposalId, hash1);
        uint256 encoded2 = harness.encodeSlotReuseMarker(proposalId, hash2);

        (uint48 decodedId1, bytes32 decodedPartial1) = harness.decodeSlotReuseMarker(encoded1);
        (uint48 decodedId2, bytes32 decodedPartial2) = harness.decodeSlotReuseMarker(encoded2);

        // Both should decode to same proposal ID
        assertEq(decodedId1, proposalId);
        assertEq(decodedId2, proposalId);

        // The partial hashes should be equal since we only store the high 208 bits
        assertEq(decodedPartial1, decodedPartial2);
    }

    function test_encode_bitsDoNotOverlap() public view {
        // Test that proposal ID bits don't overlap with parent hash bits
        uint48 maxProposalId = type(uint48).max;
        bytes32 maxParentHash = bytes32(type(uint256).max);

        uint256 encoded = harness.encodeSlotReuseMarker(maxProposalId, maxParentHash);

        // Extract both parts
        uint256 proposalIdPart = encoded >> 208;
        uint256 parentHashPart = encoded & ((1 << 208) - 1);

        // Verify no overlap by checking that OR equals encoded value
        assertEq((proposalIdPart << 208) | parentHashPart, encoded);
    }
}
