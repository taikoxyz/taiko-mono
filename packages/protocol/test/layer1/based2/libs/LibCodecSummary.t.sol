// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibCodec } from "contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "contracts/layer1/based2/IInbox.sol";

contract LibCodecSummaryTest is Test {
    // -------------------------------------------------------------------------
    // Pack/Unpack Summary Tests
    // -------------------------------------------------------------------------

    function test_packUnpackSummary_roundTrip() public pure {
        IInbox.Summary memory summary = IInbox.Summary({
            nextBatchId: 12_345,
            lastSyncedBlockId: 67_890,
            lastSyncedAt: 111_111,
            lastVerifiedBatchId: 222_222,
            gasIssuanceUpdatedAt: 333_333,
            gasIssuancePerSecond: 444_444,
            lastVerifiedBlockHash: bytes32(uint256(0x1234567890abcdef)),
            lastBatchMetaHash: bytes32(uint256(0xfedcba0987654321))
        });

        bytes memory packed = LibCodec.packSummary(summary);
        assertEq(packed.length, 98);

        IInbox.Summary memory unpacked = LibCodec.unpackSummary(packed);

        assertEq(unpacked.nextBatchId, summary.nextBatchId);
        assertEq(unpacked.lastSyncedBlockId, summary.lastSyncedBlockId);
        assertEq(unpacked.lastSyncedAt, summary.lastSyncedAt);
        assertEq(unpacked.lastVerifiedBatchId, summary.lastVerifiedBatchId);
        assertEq(unpacked.gasIssuanceUpdatedAt, summary.gasIssuanceUpdatedAt);
        assertEq(unpacked.gasIssuancePerSecond, summary.gasIssuancePerSecond);
        assertEq(unpacked.lastVerifiedBlockHash, summary.lastVerifiedBlockHash);
        assertEq(unpacked.lastBatchMetaHash, summary.lastBatchMetaHash);
    }

    function test_packUnpackSummary_maxValues() public pure {
        IInbox.Summary memory summary = IInbox.Summary({
            nextBatchId: type(uint48).max,
            lastSyncedBlockId: type(uint48).max,
            lastSyncedAt: type(uint48).max,
            lastVerifiedBatchId: type(uint48).max,
            gasIssuanceUpdatedAt: type(uint48).max,
            gasIssuancePerSecond: type(uint32).max,
            lastVerifiedBlockHash: bytes32(type(uint256).max),
            lastBatchMetaHash: bytes32(type(uint256).max)
        });

        bytes memory packed = LibCodec.packSummary(summary);
        IInbox.Summary memory unpacked = LibCodec.unpackSummary(packed);

        assertEq(unpacked.nextBatchId, summary.nextBatchId);
        assertEq(unpacked.lastSyncedBlockId, summary.lastSyncedBlockId);
        assertEq(unpacked.lastSyncedAt, summary.lastSyncedAt);
        assertEq(unpacked.lastVerifiedBatchId, summary.lastVerifiedBatchId);
        assertEq(unpacked.gasIssuanceUpdatedAt, summary.gasIssuanceUpdatedAt);
        assertEq(unpacked.gasIssuancePerSecond, summary.gasIssuancePerSecond);
        assertEq(unpacked.lastVerifiedBlockHash, summary.lastVerifiedBlockHash);
        assertEq(unpacked.lastBatchMetaHash, summary.lastBatchMetaHash);
    }

    function test_packUnpackSummary_minValues() public pure {
        IInbox.Summary memory summary = IInbox.Summary({
            nextBatchId: 0,
            lastSyncedBlockId: 0,
            lastSyncedAt: 0,
            lastVerifiedBatchId: 0,
            gasIssuanceUpdatedAt: 0,
            gasIssuancePerSecond: 0,
            lastVerifiedBlockHash: bytes32(0),
            lastBatchMetaHash: bytes32(0)
        });

        bytes memory packed = LibCodec.packSummary(summary);
        IInbox.Summary memory unpacked = LibCodec.unpackSummary(packed);

        assertEq(unpacked.nextBatchId, summary.nextBatchId);
        assertEq(unpacked.lastSyncedBlockId, summary.lastSyncedBlockId);
        assertEq(unpacked.lastSyncedAt, summary.lastSyncedAt);
        assertEq(unpacked.lastVerifiedBatchId, summary.lastVerifiedBatchId);
        assertEq(unpacked.gasIssuanceUpdatedAt, summary.gasIssuanceUpdatedAt);
        assertEq(unpacked.gasIssuancePerSecond, summary.gasIssuancePerSecond);
        assertEq(unpacked.lastVerifiedBlockHash, summary.lastVerifiedBlockHash);
        assertEq(unpacked.lastBatchMetaHash, summary.lastBatchMetaHash);
    }

    function test_packSummary_expectedSize() public pure {
        IInbox.Summary memory summary = IInbox.Summary({
            nextBatchId: 1,
            lastSyncedBlockId: 2,
            lastSyncedAt: 3,
            lastVerifiedBatchId: 4,
            gasIssuanceUpdatedAt: 5,
            gasIssuancePerSecond: 6,
            lastVerifiedBlockHash: bytes32(uint256(7)),
            lastBatchMetaHash: bytes32(uint256(8))
        });

        bytes memory packed = LibCodec.packSummary(summary);

        // Expected size: 6+6+6+6+6+4+32+32 = 98 bytes
        assertEq(packed.length, 98);
    }

    function test_unpackSummary_revertInvalidLength() public {
        bytes memory invalidData = new bytes(97); // Wrong length
        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackSummary(invalidData);
    }

    function test_unpackSummary_revertTooShort() public {
        bytes memory tooShort = new bytes(50);
        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackSummary(tooShort);
    }

    function test_unpackSummary_revertTooLong() public {
        bytes memory tooLong = new bytes(100);
        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackSummary(tooLong);
    }

    function testFuzz_packUnpackSummary(
        uint48 nextBatchId,
        uint48 lastSyncedBlockId,
        uint48 lastSyncedAt,
        uint48 lastVerifiedBatchId,
        uint48 gasIssuanceUpdatedAt,
        uint32 gasIssuancePerSecond,
        bytes32 lastVerifiedBlockHash,
        bytes32 lastBatchMetaHash
    )
        public
        pure
    {
        IInbox.Summary memory summary = IInbox.Summary({
            nextBatchId: nextBatchId,
            lastSyncedBlockId: lastSyncedBlockId,
            lastSyncedAt: lastSyncedAt,
            lastVerifiedBatchId: lastVerifiedBatchId,
            gasIssuanceUpdatedAt: gasIssuanceUpdatedAt,
            gasIssuancePerSecond: gasIssuancePerSecond,
            lastVerifiedBlockHash: lastVerifiedBlockHash,
            lastBatchMetaHash: lastBatchMetaHash
        });

        bytes memory packed = LibCodec.packSummary(summary);
        IInbox.Summary memory unpacked = LibCodec.unpackSummary(packed);

        assertEq(unpacked.nextBatchId, summary.nextBatchId);
        assertEq(unpacked.lastSyncedBlockId, summary.lastSyncedBlockId);
        assertEq(unpacked.lastSyncedAt, summary.lastSyncedAt);
        assertEq(unpacked.lastVerifiedBatchId, summary.lastVerifiedBatchId);
        assertEq(unpacked.gasIssuanceUpdatedAt, summary.gasIssuanceUpdatedAt);
        assertEq(unpacked.gasIssuancePerSecond, summary.gasIssuancePerSecond);
        assertEq(unpacked.lastVerifiedBlockHash, summary.lastVerifiedBlockHash);
        assertEq(unpacked.lastBatchMetaHash, summary.lastBatchMetaHash);
    }

    // -------------------------------------------------------------------------
    // Gas optimization tests
    // -------------------------------------------------------------------------

    function test_gasOptimization_summary() public {
        IInbox.Summary memory summary = IInbox.Summary({
            nextBatchId: 12_345,
            lastSyncedBlockId: 67_890,
            lastSyncedAt: 111_111,
            lastVerifiedBatchId: 222_222,
            gasIssuanceUpdatedAt: 333_333,
            gasIssuancePerSecond: 444_444,
            lastVerifiedBlockHash: bytes32(uint256(0x1234567890abcdef)),
            lastBatchMetaHash: bytes32(uint256(0xfedcba0987654321))
        });

        uint256 gasBefore = gasleft();
        bytes memory packed = LibCodec.packSummary(summary);
        uint256 packGas = gasBefore - gasleft();

        gasBefore = gasleft();
        LibCodec.unpackSummary(packed);
        uint256 unpackGas = gasBefore - gasleft();

        emit log_named_uint("Gas used for packing summary", packGas);
        emit log_named_uint("Gas used for unpacking summary", unpackGas);
        emit log_named_uint("Packed summary size", packed.length);
    }

    function test_gasComparison_abiEncode() public {
        IInbox.Summary memory summary = IInbox.Summary({
            nextBatchId: 12_345,
            lastSyncedBlockId: 67_890,
            lastSyncedAt: 111_111,
            lastVerifiedBatchId: 222_222,
            gasIssuanceUpdatedAt: 333_333,
            gasIssuancePerSecond: 444_444,
            lastVerifiedBlockHash: bytes32(uint256(0x1234567890abcdef)),
            lastBatchMetaHash: bytes32(uint256(0xfedcba0987654321))
        });

        // Custom packing
        uint256 gasBefore = gasleft();
        bytes memory packed = LibCodec.packSummary(summary);
        uint256 customPackGas = gasBefore - gasleft();

        gasBefore = gasleft();
        LibCodec.unpackSummary(packed);
        uint256 customUnpackGas = gasBefore - gasleft();

        // ABI encoding
        gasBefore = gasleft();
        bytes memory abiPacked = abi.encode(summary);
        uint256 abiEncodeGas = gasBefore - gasleft();

        gasBefore = gasleft();
        abi.decode(abiPacked, (IInbox.Summary));
        uint256 abiDecodeGas = gasBefore - gasleft();

        emit log_named_uint("Custom pack gas", customPackGas);
        emit log_named_uint("Custom unpack gas", customUnpackGas);
        emit log_named_uint("ABI encode gas", abiEncodeGas);
        emit log_named_uint("ABI decode gas", abiDecodeGas);
        emit log_named_uint("Custom packed size", packed.length);
        emit log_named_uint("ABI packed size", abiPacked.length);

        // Custom packing should be more efficient in both size and gas
        assertTrue(packed.length < abiPacked.length, "Custom packing should be smaller");
    }

    // -------------------------------------------------------------------------
    // Edge case tests
    // -------------------------------------------------------------------------

    function test_dataIntegrity_alternatingBits() public pure {
        // Test with alternating bit patterns to ensure no bit corruption
        IInbox.Summary memory summary = IInbox.Summary({
            nextBatchId: 0xAAAAAA, // 24-bit alternating pattern
            lastSyncedBlockId: 0x555555, // 24-bit alternating pattern
            lastSyncedAt: 0xAAAAAA,
            lastVerifiedBatchId: 0x555555,
            gasIssuanceUpdatedAt: 0xAAAAAA,
            gasIssuancePerSecond: 0xAAAAAAAA, // 32-bit alternating pattern
            lastVerifiedBlockHash: bytes32(
                0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
            ),
            lastBatchMetaHash: bytes32(
                0x5555555555555555555555555555555555555555555555555555555555555555
            )
        });

        bytes memory packed = LibCodec.packSummary(summary);
        IInbox.Summary memory unpacked = LibCodec.unpackSummary(packed);

        assertEq(unpacked.nextBatchId, summary.nextBatchId);
        assertEq(unpacked.lastSyncedBlockId, summary.lastSyncedBlockId);
        assertEq(unpacked.lastSyncedAt, summary.lastSyncedAt);
        assertEq(unpacked.lastVerifiedBatchId, summary.lastVerifiedBatchId);
        assertEq(unpacked.gasIssuanceUpdatedAt, summary.gasIssuanceUpdatedAt);
        assertEq(unpacked.gasIssuancePerSecond, summary.gasIssuancePerSecond);
        assertEq(unpacked.lastVerifiedBlockHash, summary.lastVerifiedBlockHash);
        assertEq(unpacked.lastBatchMetaHash, summary.lastBatchMetaHash);
    }

    function test_dataIntegrity_boundaryValues() public pure {
        // Test with boundary values for each field type
        IInbox.Summary memory summary = IInbox.Summary({
            nextBatchId: type(uint48).max,
            lastSyncedBlockId: 1,
            lastSyncedAt: type(uint48).max - 1,
            lastVerifiedBatchId: 2,
            gasIssuanceUpdatedAt: type(uint48).max - 2,
            gasIssuancePerSecond: type(uint32).max,
            lastVerifiedBlockHash: bytes32(uint256(1)),
            lastBatchMetaHash: bytes32(type(uint256).max - 1)
        });

        bytes memory packed = LibCodec.packSummary(summary);
        IInbox.Summary memory unpacked = LibCodec.unpackSummary(packed);

        assertEq(unpacked.nextBatchId, summary.nextBatchId);
        assertEq(unpacked.lastSyncedBlockId, summary.lastSyncedBlockId);
        assertEq(unpacked.lastSyncedAt, summary.lastSyncedAt);
        assertEq(unpacked.lastVerifiedBatchId, summary.lastVerifiedBatchId);
        assertEq(unpacked.gasIssuanceUpdatedAt, summary.gasIssuanceUpdatedAt);
        assertEq(unpacked.gasIssuancePerSecond, summary.gasIssuancePerSecond);
        assertEq(unpacked.lastVerifiedBlockHash, summary.lastVerifiedBlockHash);
        assertEq(unpacked.lastBatchMetaHash, summary.lastBatchMetaHash);
    }

    function test_multipleRoundTrips() public pure {
        IInbox.Summary memory original = IInbox.Summary({
            nextBatchId: 999,
            lastSyncedBlockId: 888,
            lastSyncedAt: 777,
            lastVerifiedBatchId: 666,
            gasIssuanceUpdatedAt: 555,
            gasIssuancePerSecond: 444,
            lastVerifiedBlockHash: keccak256("test"),
            lastBatchMetaHash: keccak256("hash")
        });

        // Pack and unpack multiple times
        bytes memory packed1 = LibCodec.packSummary(original);
        IInbox.Summary memory unpacked1 = LibCodec.unpackSummary(packed1);

        bytes memory packed2 = LibCodec.packSummary(unpacked1);
        IInbox.Summary memory unpacked2 = LibCodec.unpackSummary(packed2);

        bytes memory packed3 = LibCodec.packSummary(unpacked2);
        IInbox.Summary memory unpacked3 = LibCodec.unpackSummary(packed3);

        // All should be identical
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked1)));
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked2)));
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked3)));
        assertEq(keccak256(packed1), keccak256(packed2));
        assertEq(keccak256(packed2), keccak256(packed3));
    }
}
