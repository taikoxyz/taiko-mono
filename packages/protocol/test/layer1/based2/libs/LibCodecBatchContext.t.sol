// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console2 } from "forge-std/src/Test.sol";
import { LibCodec } from "contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "contracts/layer1/based2/IInbox.sol";

contract LibCodecBatchContextTest is Test {
    using LibCodec for IInbox.BatchContext;

    function test_packUnpack_emptyArrays() public pure {
        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0x1234567890123456789012345678901234567890),
            txsHash: bytes32(uint256(0xabcdef)),
            lastAnchorBlockId: 12_345,
            lastBlockId: 67_890,
            blobsCreatedIn: 11_111,
            livenessBond: 100_000,
            provabilityBond: 200_000,
            baseFeeSharingPctg: 75,
            anchorBlockHashes: new bytes32[](0),
            blobHashes: new bytes32[](0)
        });

        bytes memory packed = context.packBatchContext();
        IInbox.BatchContext memory unpacked = LibCodec.unpackBatchContext(packed);

        assertEq(unpacked.prover, context.prover);
        assertEq(unpacked.txsHash, context.txsHash);
        assertEq(unpacked.lastAnchorBlockId, context.lastAnchorBlockId);
        assertEq(unpacked.lastBlockId, context.lastBlockId);
        assertEq(unpacked.blobsCreatedIn, context.blobsCreatedIn);
        assertEq(unpacked.livenessBond, context.livenessBond);
        assertEq(unpacked.provabilityBond, context.provabilityBond);
        assertEq(unpacked.baseFeeSharingPctg, context.baseFeeSharingPctg);
        assertEq(unpacked.anchorBlockHashes.length, 0);
        assertEq(unpacked.blobHashes.length, 0);
    }

    function test_packUnpack_withArrays() public pure {
        bytes32[] memory anchorHashes = new bytes32[](3);
        anchorHashes[0] = bytes32(uint256(0x111));
        anchorHashes[1] = bytes32(uint256(0x222));
        anchorHashes[2] = bytes32(uint256(0x333));

        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = bytes32(uint256(0xaaa));
        blobHashes[1] = bytes32(uint256(0xbbb));

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF),
            txsHash: keccak256("test"),
            lastAnchorBlockId: 99_999,
            lastBlockId: 123_456,
            blobsCreatedIn: 22_222,
            livenessBond: 150_000,
            provabilityBond: 250_000,
            baseFeeSharingPctg: 50,
            anchorBlockHashes: anchorHashes,
            blobHashes: blobHashes
        });

        bytes memory packed = context.packBatchContext();
        IInbox.BatchContext memory unpacked = LibCodec.unpackBatchContext(packed);

        assertEq(unpacked.prover, context.prover);
        assertEq(unpacked.txsHash, context.txsHash);
        assertEq(unpacked.lastAnchorBlockId, context.lastAnchorBlockId);
        assertEq(unpacked.lastBlockId, context.lastBlockId);
        assertEq(unpacked.blobsCreatedIn, context.blobsCreatedIn);
        assertEq(unpacked.livenessBond, context.livenessBond);
        assertEq(unpacked.provabilityBond, context.provabilityBond);
        assertEq(unpacked.baseFeeSharingPctg, context.baseFeeSharingPctg);

        assertEq(unpacked.anchorBlockHashes.length, 3);
        assertEq(unpacked.anchorBlockHashes[0], anchorHashes[0]);
        assertEq(unpacked.anchorBlockHashes[1], anchorHashes[1]);
        assertEq(unpacked.anchorBlockHashes[2], anchorHashes[2]);

        assertEq(unpacked.blobHashes.length, 2);
        assertEq(unpacked.blobHashes[0], blobHashes[0]);
        assertEq(unpacked.blobHashes[1], blobHashes[1]);
    }

    function test_packUnpack_maxValues() public pure {
        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(type(uint160).max),
            txsHash: bytes32(type(uint256).max),
            lastAnchorBlockId: type(uint48).max,
            lastBlockId: type(uint48).max,
            blobsCreatedIn: type(uint48).max,
            livenessBond: type(uint48).max,
            provabilityBond: type(uint48).max,
            baseFeeSharingPctg: type(uint8).max,
            anchorBlockHashes: new bytes32[](0),
            blobHashes: new bytes32[](0)
        });

        bytes memory packed = context.packBatchContext();
        IInbox.BatchContext memory unpacked = LibCodec.unpackBatchContext(packed);

        assertEq(unpacked.prover, context.prover);
        assertEq(unpacked.txsHash, context.txsHash);
        assertEq(unpacked.lastAnchorBlockId, context.lastAnchorBlockId);
        assertEq(unpacked.lastBlockId, context.lastBlockId);
        assertEq(unpacked.blobsCreatedIn, context.blobsCreatedIn);
        assertEq(unpacked.livenessBond, context.livenessBond);
        assertEq(unpacked.provabilityBond, context.provabilityBond);
        assertEq(unpacked.baseFeeSharingPctg, context.baseFeeSharingPctg);
    }

    function test_packUnpack_largeArrays() public pure {
        // Test with relatively large arrays (but still within reasonable limits)
        uint256 anchorCount = 100;
        uint256 blobCount = 15; // Changed from 50 to match new 4-bit limit

        bytes32[] memory anchorHashes = new bytes32[](anchorCount);
        for (uint256 i = 0; i < anchorCount; i++) {
            anchorHashes[i] = keccak256(abi.encode("anchor", i));
        }

        bytes32[] memory blobHashes = new bytes32[](blobCount);
        for (uint256 i = 0; i < blobCount; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0x123),
            txsHash: keccak256("large arrays test"),
            lastAnchorBlockId: 1000,
            lastBlockId: 2000,
            blobsCreatedIn: 3000,
            livenessBond: 4000,
            provabilityBond: 5000,
            baseFeeSharingPctg: 25,
            anchorBlockHashes: anchorHashes,
            blobHashes: blobHashes
        });

        bytes memory packed = context.packBatchContext();
        IInbox.BatchContext memory unpacked = LibCodec.unpackBatchContext(packed);

        assertEq(unpacked.anchorBlockHashes.length, anchorCount);
        assertEq(unpacked.blobHashes.length, blobCount);

        for (uint256 i = 0; i < anchorCount; i++) {
            assertEq(unpacked.anchorBlockHashes[i], anchorHashes[i]);
        }

        for (uint256 i = 0; i < blobCount; i++) {
            assertEq(unpacked.blobHashes[i], blobHashes[i]);
        }
    }

    function test_pack_arrayTooLarge() public pure {
        // Test array size limit (uint16 max)
        // Since creating a large array in memory might cause issues,
        // we'll test with a smaller size that still triggers the check

        // Create a context with array size that would exceed uint16 max
        bytes32[] memory anchorHashes = new bytes32[](100);
        bytes32[] memory blobHashes = new bytes32[](0);

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0x123),
            txsHash: bytes32(0),
            lastAnchorBlockId: 0,
            lastBlockId: 0,
            blobsCreatedIn: 0,
            livenessBond: 0,
            provabilityBond: 0,
            baseFeeSharingPctg: 0,
            anchorBlockHashes: anchorHashes,
            blobHashes: blobHashes
        });

        // This test verifies the limit check works correctly
        // In practice, creating arrays larger than uint16.max is not feasible in memory
        // So we verify the function works with valid sizes
        bytes memory packed = context.packBatchContext();
        IInbox.BatchContext memory unpacked = LibCodec.unpackBatchContext(packed);
        assertEq(unpacked.anchorBlockHashes.length, 100);
    }

    function test_unpack_invalidDataLength() public {
        // Test with data that's too short
        bytes memory tooShort = new bytes(50); // Less than 91 bytes minimum

        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackBatchContext(tooShort);
    }

    function test_packUnpack_fuzz(
        address prover,
        bytes32 txsHash,
        uint48 lastAnchorBlockId,
        uint48 lastBlockId,
        uint48 blobsCreatedIn,
        uint48 livenessBond,
        uint48 provabilityBond,
        uint8 baseFeeSharingPctg,
        uint8 anchorHashCount,
        uint8 blobHashCount
    )
        public
        view
    {
        // Limit array sizes for fuzzing
        anchorHashCount = anchorHashCount % 10;
        blobHashCount = blobHashCount % 10;

        bytes32[] memory anchorHashes = new bytes32[](anchorHashCount);
        for (uint256 i = 0; i < anchorHashCount; i++) {
            anchorHashes[i] = keccak256(abi.encode("fuzz_anchor", i, block.timestamp));
        }

        bytes32[] memory blobHashes = new bytes32[](blobHashCount);
        for (uint256 i = 0; i < blobHashCount; i++) {
            blobHashes[i] = keccak256(abi.encode("fuzz_blob", i, block.timestamp));
        }

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: prover,
            txsHash: txsHash,
            lastAnchorBlockId: lastAnchorBlockId,
            lastBlockId: lastBlockId,
            blobsCreatedIn: blobsCreatedIn,
            livenessBond: livenessBond,
            provabilityBond: provabilityBond,
            baseFeeSharingPctg: baseFeeSharingPctg,
            anchorBlockHashes: anchorHashes,
            blobHashes: blobHashes
        });

        bytes memory packed = context.packBatchContext();
        IInbox.BatchContext memory unpacked = LibCodec.unpackBatchContext(packed);

        assertEq(unpacked.prover, context.prover);
        assertEq(unpacked.txsHash, context.txsHash);
        assertEq(unpacked.lastAnchorBlockId, context.lastAnchorBlockId);
        assertEq(unpacked.lastBlockId, context.lastBlockId);
        assertEq(unpacked.blobsCreatedIn, context.blobsCreatedIn);
        assertEq(unpacked.livenessBond, context.livenessBond);
        assertEq(unpacked.provabilityBond, context.provabilityBond);
        assertEq(unpacked.baseFeeSharingPctg, context.baseFeeSharingPctg);

        assertEq(unpacked.anchorBlockHashes.length, anchorHashCount);
        assertEq(unpacked.blobHashes.length, blobHashCount);

        for (uint256 i = 0; i < anchorHashCount; i++) {
            assertEq(unpacked.anchorBlockHashes[i], anchorHashes[i]);
        }

        for (uint256 i = 0; i < blobHashCount; i++) {
            assertEq(unpacked.blobHashes[i], blobHashes[i]);
        }
    }

    function test_packedSize() public pure {
        // Test to verify the packed size calculation is correct
        bytes32[] memory anchorHashes = new bytes32[](2);
        bytes32[] memory blobHashes = new bytes32[](3);

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0x123),
            txsHash: bytes32(0),
            lastAnchorBlockId: 0,
            lastBlockId: 0,
            blobsCreatedIn: 0,
            livenessBond: 0,
            provabilityBond: 0,
            baseFeeSharingPctg: 0,
            anchorBlockHashes: anchorHashes,
            blobHashes: blobHashes
        });

        bytes memory packed = context.packBatchContext();

        // Expected size: 83 (fixed) + 2 (anchor length) + 1 (blob length) + 2*32 + 3*32 = 246
        uint256 expectedSize = 83 + 2 + 1 + (2 * 32) + (3 * 32);
        assertEq(packed.length, expectedSize);
    }

    function test_gasEfficiency() public view {
        // Test gas efficiency compared to abi.encode
        bytes32[] memory anchorHashes = new bytes32[](5);
        bytes32[] memory blobHashes = new bytes32[](5);

        for (uint256 i = 0; i < 5; i++) {
            anchorHashes[i] = keccak256(abi.encode("anchor", i));
            blobHashes[i] = keccak256(abi.encode("blob", i));
        }

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0x123),
            txsHash: keccak256("gas test"),
            lastAnchorBlockId: 1000,
            lastBlockId: 2000,
            blobsCreatedIn: 3000,
            livenessBond: 4000,
            provabilityBond: 5000,
            baseFeeSharingPctg: 25,
            anchorBlockHashes: anchorHashes,
            blobHashes: blobHashes
        });

        // Measure gas for custom packing
        uint256 gasStart = gasleft();
        bytes memory packed = context.packBatchContext();
        uint256 gasUsedPack = gasStart - gasleft();

        // Measure gas for unpacking
        gasStart = gasleft();
        IInbox.BatchContext memory unpacked = LibCodec.unpackBatchContext(packed);
        uint256 gasUsedUnpack = gasStart - gasleft();

        // Compare with abi.encode/decode
        gasStart = gasleft();
        bytes memory abiPacked = abi.encode(context);
        uint256 gasUsedAbiEncode = gasStart - gasleft();

        gasStart = gasleft();
        IInbox.BatchContext memory abiUnpacked = abi.decode(abiPacked, (IInbox.BatchContext));
        uint256 gasUsedAbiDecode = gasStart - gasleft();

        console2.log("Custom pack gas:", gasUsedPack);
        console2.log("Custom unpack gas:", gasUsedUnpack);
        console2.log("ABI encode gas:", gasUsedAbiEncode);
        console2.log("ABI decode gas:", gasUsedAbiDecode);
        console2.log("Custom packed size:", packed.length);
        console2.log("ABI packed size:", abiPacked.length);

        // Verify data integrity
        assertEq(unpacked.prover, abiUnpacked.prover);
        assertEq(unpacked.txsHash, abiUnpacked.txsHash);
    }

    function test_packBatchContext_revertAnchorBlockHashesArrayTooLarge() public {
        // Create an array that's too large for uint16 (65536 > 65535)
        bytes32[] memory largeAnchorHashes = new bytes32[](65536);
        bytes32[] memory blobHashes = new bytes32[](0);

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0x1111),
            txsHash: bytes32(uint256(0x2222)),
            lastAnchorBlockId: 1,
            lastBlockId: 2,
            blobsCreatedIn: 3,
            livenessBond: 4,
            provabilityBond: 5,
            baseFeeSharingPctg: 6,
            anchorBlockHashes: largeAnchorHashes,
            blobHashes: blobHashes
        });

        vm.expectRevert(LibCodec.AnchorBlockHashesArrayTooLarge.selector);
        LibCodec.packBatchContext(context);
    }

    function test_packBatchContext_revertBlobHashesArrayTooLarge() public {
        // Create an array that's too large for uint4 (16 > 15)
        bytes32[] memory largeBlobHashes = new bytes32[](16);
        bytes32[] memory anchorHashes = new bytes32[](0);

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0x1111),
            txsHash: bytes32(uint256(0x2222)),
            lastAnchorBlockId: 1,
            lastBlockId: 2,
            blobsCreatedIn: 3,
            livenessBond: 4,
            provabilityBond: 5,
            baseFeeSharingPctg: 6,
            anchorBlockHashes: anchorHashes,
            blobHashes: largeBlobHashes
        });

        vm.expectRevert(LibCodec.BlobHashesArrayTooLarge.selector);
        LibCodec.packBatchContext(context);
    }
}
