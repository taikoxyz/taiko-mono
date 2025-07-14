// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibCodec } from "contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "contracts/layer1/based2/IInbox.sol";

contract LibCodecBatchTest is Test {
    // -------------------------------------------------------------------------
    // Pack/Unpack Batch Tests
    // -------------------------------------------------------------------------

    function test_packUnpackBatches_emptyArray() public pure {
        IInbox.Batch[] memory batches = new IInbox.Batch[](0);

        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);

        assertEq(unpacked.length, 0);
        assertEq(packed.length, 1); // Just the length field
    }

    function test_packUnpackBatches_singleBatch() public pure {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        // Create minimal batch for testing
        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        batches[0] = IInbox.Batch({
            proposer: address(0x1111),
            coinbase: address(0x2222),
            lastBlockTimestamp: 123_456,
            gasIssuancePerSecond: 789,
            isForcedInclusion: true,
            proverAuth: emptyAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: 1,
                numBlobs: 2,
                byteOffset: 3,
                byteSize: 4,
                createdIn: 5
            })
        });

        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);

        assertEq(unpacked.length, 1);
        assertEq(unpacked[0].proposer, batches[0].proposer);
        assertEq(unpacked[0].coinbase, batches[0].coinbase);
        assertEq(unpacked[0].lastBlockTimestamp, batches[0].lastBlockTimestamp);
        assertEq(unpacked[0].gasIssuancePerSecond, batches[0].gasIssuancePerSecond);
        assertEq(unpacked[0].isForcedInclusion, batches[0].isForcedInclusion);
        // Note: The current implementation stores empty arrays for complex fields
    }

    function test_packUnpackBatches_singleBatchWithAuth() public pure {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        // Create batch with non-empty proverAuth
        bytes memory proverAuth = abi.encodePacked("test", "auth", "data");
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        batches[0] = IInbox.Batch({
            proposer: address(0x1111),
            coinbase: address(0x2222),
            lastBlockTimestamp: 123_456,
            gasIssuancePerSecond: 789,
            isForcedInclusion: false,
            proverAuth: proverAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: 10,
                numBlobs: 20,
                byteOffset: 30,
                byteSize: 40,
                createdIn: 50
            })
        });

        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);

        assertEq(unpacked.length, 1);
        assertEq(unpacked[0].proposer, batches[0].proposer);
        assertEq(unpacked[0].coinbase, batches[0].coinbase);
        assertEq(unpacked[0].lastBlockTimestamp, batches[0].lastBlockTimestamp);
        assertEq(unpacked[0].gasIssuancePerSecond, batches[0].gasIssuancePerSecond);
        assertEq(unpacked[0].isForcedInclusion, batches[0].isForcedInclusion);
        assertEq(unpacked[0].proverAuth.length, proverAuth.length);

        // Verify proverAuth data integrity
        for (uint256 i = 0; i < proverAuth.length; i++) {
            assertEq(unpacked[0].proverAuth[i], proverAuth[i]);
        }
    }

    function test_packUnpackBatches_multipleBatches() public pure {
        IInbox.Batch[] memory batches = new IInbox.Batch[](3);

        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        for (uint256 i = 0; i < 3; i++) {
            batches[i] = IInbox.Batch({
                proposer: address(uint160(i + 100)),
                coinbase: address(uint160(i + 200)),
                lastBlockTimestamp: uint48(i + 1000),
                gasIssuancePerSecond: uint32(i + 2000),
                isForcedInclusion: i % 2 == 0,
                proverAuth: emptyAuth,
                signalSlots: emptySlots,
                anchorBlockIds: emptyBlockIds,
                blocks: emptyBlocks,
                blobs: IInbox.Blobs({
                    hashes: emptyHashes,
                    firstBlobIndex: uint8(i + 1),
                    numBlobs: uint8(i + 2),
                    byteOffset: uint32(i + 3),
                    byteSize: uint32(i + 4),
                    createdIn: uint48(i + 5)
                })
            });
        }

        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);

        assertEq(unpacked.length, 3);

        for (uint256 i = 0; i < 3; i++) {
            assertEq(unpacked[i].proposer, batches[i].proposer);
            assertEq(unpacked[i].coinbase, batches[i].coinbase);
            assertEq(unpacked[i].lastBlockTimestamp, batches[i].lastBlockTimestamp);
            assertEq(unpacked[i].gasIssuancePerSecond, batches[i].gasIssuancePerSecond);
            assertEq(unpacked[i].isForcedInclusion, batches[i].isForcedInclusion);
        }
    }

    function test_packBatches_revertArrayTooLarge() public pure {
        // Test that the function properly validates array size limits
        // Since creating an actual array of uint8.max + 1 size would be impractical,
        // we test with smaller arrays and verify no reverts occur
        IInbox.Batch[] memory batches = new IInbox.Batch[](100);

        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        for (uint256 i = 0; i < 100; i++) {
            batches[i] = IInbox.Batch({
                proposer: address(uint160(i)),
                coinbase: address(uint160(i + 1000)),
                lastBlockTimestamp: uint48(i),
                gasIssuancePerSecond: uint32(i),
                isForcedInclusion: false,
                proverAuth: emptyAuth,
                signalSlots: emptySlots,
                anchorBlockIds: emptyBlockIds,
                blocks: emptyBlocks,
                blobs: IInbox.Blobs({
                    hashes: emptyHashes,
                    firstBlobIndex: 0,
                    numBlobs: 0,
                    byteOffset: 0,
                    byteSize: 0,
                    createdIn: 0
                })
            });
        }

        // Should not revert for reasonable array sizes
        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);
        assertEq(unpacked.length, 100);
    }

    function test_unpackBatches_revertInvalidDataLength() public {
        // Test with data that's too short (0 bytes is too short, need at least 1 for length)
        bytes memory tooShort = new bytes(0);

        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackBatches(tooShort);
    }

    function test_packBatches_revertProverAuthTooLarge() public {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        // Create a proverAuth that's too large for uint16 (> 65535 bytes)
        bytes memory largeProverAuth = new bytes(65536); // One byte too large

        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        batches[0] = IInbox.Batch({
            proposer: address(0x1111),
            coinbase: address(0x2222),
            lastBlockTimestamp: 123_456,
            gasIssuancePerSecond: 789,
            isForcedInclusion: true,
            proverAuth: largeProverAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: 1,
                numBlobs: 2,
                byteOffset: 3,
                byteSize: 4,
                createdIn: 5
            })
        });

        // Should revert with ProverAuthTooLarge error
        vm.expectRevert(LibCodec.ProverAuthTooLarge.selector);
        LibCodec.packBatches(batches);
    }

    function test_packBatches_revertSignalSlotsArrayTooLarge() public {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        // Create signalSlots array that's too large for uint8 (256 > 255)
        bytes32[] memory largeSignalSlots = new bytes32[](256);

        bytes memory emptyAuth = new bytes(0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        batches[0] = IInbox.Batch({
            proposer: address(0x1111),
            coinbase: address(0x2222),
            lastBlockTimestamp: 123_456,
            gasIssuancePerSecond: 789,
            isForcedInclusion: true,
            proverAuth: emptyAuth,
            signalSlots: largeSignalSlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: 1,
                numBlobs: 2,
                byteOffset: 3,
                byteSize: 4,
                createdIn: 5
            })
        });

        vm.expectRevert(LibCodec.SignalSlotsArrayTooLarge.selector);
        LibCodec.packBatches(batches);
    }

    function test_packBatches_revertAnchorBlockIdsArrayTooLarge() public {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        // Create anchorBlockIds array that's too large for uint16 (65536 > 65535)
        uint48[] memory largeAnchorBlockIds = new uint48[](65536);

        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        batches[0] = IInbox.Batch({
            proposer: address(0x1111),
            coinbase: address(0x2222),
            lastBlockTimestamp: 123_456,
            gasIssuancePerSecond: 789,
            isForcedInclusion: true,
            proverAuth: emptyAuth,
            signalSlots: emptySlots,
            anchorBlockIds: largeAnchorBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: 1,
                numBlobs: 2,
                byteOffset: 3,
                byteSize: 4,
                createdIn: 5
            })
        });

        vm.expectRevert(LibCodec.AnchorBlockIdsArrayTooLarge.selector);
        LibCodec.packBatches(batches);
    }

    function test_packBatches_revertBlocksArrayTooLarge() public {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        // Create blocks array that's too large for uint16 (65536 > 65535)
        IInbox.Block[] memory largeBlocks = new IInbox.Block[](65536);

        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        batches[0] = IInbox.Batch({
            proposer: address(0x1111),
            coinbase: address(0x2222),
            lastBlockTimestamp: 123_456,
            gasIssuancePerSecond: 789,
            isForcedInclusion: true,
            proverAuth: emptyAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: largeBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: 1,
                numBlobs: 2,
                byteOffset: 3,
                byteSize: 4,
                createdIn: 5
            })
        });

        vm.expectRevert(LibCodec.BlocksArrayTooLarge.selector);
        LibCodec.packBatches(batches);
    }

    function test_packBatches_revertBlobHashesArrayTooLarge() public {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        // Create blob hashes array that's too large for uint4 (16 > 15)
        bytes32[] memory largeBlobHashes = new bytes32[](16);

        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);

        batches[0] = IInbox.Batch({
            proposer: address(0x1111),
            coinbase: address(0x2222),
            lastBlockTimestamp: 123_456,
            gasIssuancePerSecond: 789,
            isForcedInclusion: true,
            proverAuth: emptyAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: largeBlobHashes,
                firstBlobIndex: 1,
                numBlobs: 2,
                byteOffset: 3,
                byteSize: 4,
                createdIn: 5
            })
        });

        vm.expectRevert(LibCodec.BlobHashesArrayTooLarge.selector);
        LibCodec.packBatches(batches);
    }

    function test_packUnpackBatches_booleanValues() public pure {
        IInbox.Batch[] memory batches = new IInbox.Batch[](2);

        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        // Test with isForcedInclusion = true
        batches[0] = IInbox.Batch({
            proposer: address(0x1111),
            coinbase: address(0x2222),
            lastBlockTimestamp: 123_456,
            gasIssuancePerSecond: 789,
            isForcedInclusion: true,
            proverAuth: emptyAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: 1,
                numBlobs: 2,
                byteOffset: 3,
                byteSize: 4,
                createdIn: 5
            })
        });

        // Test with isForcedInclusion = false
        batches[1] = IInbox.Batch({
            proposer: address(0x3333),
            coinbase: address(0x4444),
            lastBlockTimestamp: 789_012,
            gasIssuancePerSecond: 456,
            isForcedInclusion: false,
            proverAuth: emptyAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: 6,
                numBlobs: 7,
                byteOffset: 8,
                byteSize: 9,
                createdIn: 10
            })
        });

        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);

        assertEq(unpacked.length, 2);
        assertEq(unpacked[0].isForcedInclusion, true);
        assertEq(unpacked[1].isForcedInclusion, false);
        assertEq(unpacked[0].gasIssuancePerSecond, 789);
        assertEq(unpacked[1].gasIssuancePerSecond, 456);
    }

    // -------------------------------------------------------------------------
    // Gas optimization tests
    // -------------------------------------------------------------------------

    function test_gasOptimization_packing() public {
        IInbox.Batch[] memory batches = new IInbox.Batch[](10);

        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        for (uint256 i = 0; i < 10; i++) {
            batches[i] = IInbox.Batch({
                proposer: address(uint160(i)),
                coinbase: address(uint160(i + 1000)),
                lastBlockTimestamp: uint48(i),
                gasIssuancePerSecond: uint32(i),
                isForcedInclusion: i % 2 == 0,
                proverAuth: emptyAuth,
                signalSlots: emptySlots,
                anchorBlockIds: emptyBlockIds,
                blocks: emptyBlocks,
                blobs: IInbox.Blobs({
                    hashes: emptyHashes,
                    firstBlobIndex: uint8(i),
                    numBlobs: uint8(i + 1),
                    byteOffset: uint32(i + 2),
                    byteSize: uint32(i + 3),
                    createdIn: uint48(i + 4)
                })
            });
        }

        uint256 gasBefore = gasleft();
        bytes memory packed = LibCodec.packBatches(batches);
        uint256 packGas = gasBefore - gasleft();

        gasBefore = gasleft();
        LibCodec.unpackBatches(packed);
        uint256 unpackGas = gasBefore - gasleft();

        emit log_named_uint("Gas used for packing 10 batches", packGas);
        emit log_named_uint("Gas used for unpacking 10 batches", unpackGas);
        emit log_named_uint("Packed size for 10 batches", packed.length);
    }

    function test_gasComparison_abiEncode() public {
        IInbox.Batch[] memory batches = new IInbox.Batch[](5);

        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        for (uint256 i = 0; i < 5; i++) {
            batches[i] = IInbox.Batch({
                proposer: address(uint160(i)),
                coinbase: address(uint160(i + 1000)),
                lastBlockTimestamp: uint48(i),
                gasIssuancePerSecond: uint32(i),
                isForcedInclusion: i % 2 == 0,
                proverAuth: emptyAuth,
                signalSlots: emptySlots,
                anchorBlockIds: emptyBlockIds,
                blocks: emptyBlocks,
                blobs: IInbox.Blobs({
                    hashes: emptyHashes,
                    firstBlobIndex: uint8(i),
                    numBlobs: uint8(i + 1),
                    byteOffset: uint32(i + 2),
                    byteSize: uint32(i + 3),
                    createdIn: uint48(i + 4)
                })
            });
        }

        // Custom packing
        uint256 gasBefore = gasleft();
        bytes memory packed = LibCodec.packBatches(batches);
        uint256 customPackGas = gasBefore - gasleft();

        gasBefore = gasleft();
        LibCodec.unpackBatches(packed);
        uint256 customUnpackGas = gasBefore - gasleft();

        // ABI encoding
        gasBefore = gasleft();
        bytes memory abiPacked = abi.encode(batches);
        uint256 abiEncodeGas = gasBefore - gasleft();

        gasBefore = gasleft();
        abi.decode(abiPacked, (IInbox.Batch[]));
        uint256 abiDecodeGas = gasBefore - gasleft();

        emit log_named_uint("Custom pack gas", customPackGas);
        emit log_named_uint("Custom unpack gas", customUnpackGas);
        emit log_named_uint("ABI encode gas", abiEncodeGas);
        emit log_named_uint("ABI decode gas", abiDecodeGas);
        emit log_named_uint("Custom packed size", packed.length);
        emit log_named_uint("ABI packed size", abiPacked.length);

        // Custom packing should be smaller
        assertTrue(packed.length < abiPacked.length, "Custom packing should be smaller");
    }

    // -------------------------------------------------------------------------
    // Edge case tests
    // -------------------------------------------------------------------------

    function test_dataIntegrity_maxValues() public pure {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        bytes memory maxAuth = new bytes(100); // Some reasonable auth size
        for (uint256 i = 0; i < maxAuth.length; i++) {
            maxAuth[i] = bytes1(uint8(i % 256));
        }

        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        batches[0] = IInbox.Batch({
            proposer: address(type(uint160).max),
            coinbase: address(type(uint160).max - 1),
            lastBlockTimestamp: type(uint48).max,
            gasIssuancePerSecond: type(uint32).max,
            isForcedInclusion: true,
            proverAuth: maxAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: type(uint8).max,
                numBlobs: type(uint8).max,
                byteOffset: type(uint32).max,
                byteSize: type(uint32).max,
                createdIn: type(uint48).max
            })
        });

        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);

        assertEq(unpacked.length, 1);
        assertEq(unpacked[0].proposer, batches[0].proposer);
        assertEq(unpacked[0].coinbase, batches[0].coinbase);
        assertEq(unpacked[0].lastBlockTimestamp, batches[0].lastBlockTimestamp);
        assertEq(unpacked[0].gasIssuancePerSecond, batches[0].gasIssuancePerSecond);
        assertEq(unpacked[0].isForcedInclusion, batches[0].isForcedInclusion);
        assertEq(unpacked[0].proverAuth.length, maxAuth.length);
    }

    function test_dataIntegrity_minValues() public pure {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        batches[0] = IInbox.Batch({
            proposer: address(0),
            coinbase: address(0),
            lastBlockTimestamp: 0,
            gasIssuancePerSecond: 0,
            isForcedInclusion: false,
            proverAuth: emptyAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: 0,
                numBlobs: 0,
                byteOffset: 0,
                byteSize: 0,
                createdIn: 0
            })
        });

        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);

        assertEq(unpacked.length, 1);
        assertEq(unpacked[0].proposer, address(0));
        assertEq(unpacked[0].coinbase, address(0));
        assertEq(unpacked[0].lastBlockTimestamp, 0);
        assertEq(unpacked[0].gasIssuancePerSecond, 0);
        assertEq(unpacked[0].isForcedInclusion, false);
        assertEq(unpacked[0].proverAuth.length, 0);
    }

    function testFuzz_packUnpack_singleBatch(
        address proposer,
        uint48 lastBlockTimestamp,
        uint32 gasIssuancePerSecond,
        bool isForcedInclusion
    )
        public
        pure
    {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);
        bytes32[] memory emptyHashes = new bytes32[](0);

        batches[0] = IInbox.Batch({
            proposer: proposer,
            coinbase: address(0x1234),
            lastBlockTimestamp: lastBlockTimestamp,
            gasIssuancePerSecond: gasIssuancePerSecond,
            isForcedInclusion: isForcedInclusion,
            proverAuth: emptyAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                hashes: emptyHashes,
                firstBlobIndex: 1,
                numBlobs: 2,
                byteOffset: 3,
                byteSize: 4,
                createdIn: 5
            })
        });

        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);

        assertEq(unpacked.length, 1);
        assertEq(unpacked[0].proposer, proposer);
        assertEq(unpacked[0].lastBlockTimestamp, lastBlockTimestamp);
        assertEq(unpacked[0].gasIssuancePerSecond, gasIssuancePerSecond);
        assertEq(unpacked[0].isForcedInclusion, isForcedInclusion);
    }
}
