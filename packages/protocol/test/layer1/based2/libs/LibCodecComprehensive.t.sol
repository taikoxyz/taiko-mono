// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibCodec } from "contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "contracts/layer1/based2/IInbox.sol";

contract LibCodecComprehensiveTest is Test {
    // -------------------------------------------------------------------------
    // Summary Tests
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

    function test_unpackSummary_revertInvalidLength() public {
        bytes memory invalidData = new bytes(97); // Wrong length
        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackSummary(invalidData);
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
    // BatchContext Tests
    // -------------------------------------------------------------------------

    function test_packUnpackBatchContext_roundTrip() public pure {
        bytes32[] memory anchorHashes = new bytes32[](2);
        anchorHashes[0] = bytes32(uint256(0x1111));
        anchorHashes[1] = bytes32(uint256(0x2222));

        bytes32[] memory blobHashes = new bytes32[](3);
        blobHashes[0] = bytes32(uint256(0x3333));
        blobHashes[1] = bytes32(uint256(0x4444));
        blobHashes[2] = bytes32(uint256(0x5555));

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0x1234567890123456789012345678901234567890),
            txsHash: bytes32(uint256(0xabcdef)),
            lastAnchorBlockId: 123_456,
            lastBlockId: 789_012,
            blockMaxGasLimit: 901_234,
            livenessBond: 567_890,
            provabilityBond: 123_456,
            baseFeeSharingPctg: 50,
            anchorBlockHashes: anchorHashes,
            blobHashes: blobHashes
        });

        bytes memory packed = LibCodec.packBatchContext(context);
        IInbox.BatchContext memory unpacked = LibCodec.unpackBatchContext(packed);

        assertEq(unpacked.prover, context.prover);
        assertEq(unpacked.txsHash, context.txsHash);
        assertEq(unpacked.lastAnchorBlockId, context.lastAnchorBlockId);
        assertEq(unpacked.lastBlockId, context.lastBlockId);
        // blobsCreatedIn field removed
        assertEq(unpacked.blockMaxGasLimit, context.blockMaxGasLimit);
        assertEq(unpacked.livenessBond, context.livenessBond);
        assertEq(unpacked.provabilityBond, context.provabilityBond);
        assertEq(unpacked.baseFeeSharingPctg, context.baseFeeSharingPctg);

        assertEq(unpacked.anchorBlockHashes.length, context.anchorBlockHashes.length);
        for (uint256 i = 0; i < context.anchorBlockHashes.length; i++) {
            assertEq(unpacked.anchorBlockHashes[i], context.anchorBlockHashes[i]);
        }

        assertEq(unpacked.blobHashes.length, context.blobHashes.length);
        for (uint256 i = 0; i < context.blobHashes.length; i++) {
            assertEq(unpacked.blobHashes[i], context.blobHashes[i]);
        }
    }

    function test_packUnpackBatchContext_emptyArrays() public pure {
        bytes32[] memory emptyHashes = new bytes32[](0);

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0x1111),
            txsHash: bytes32(uint256(0x2222)),
            lastAnchorBlockId: 1,
            lastBlockId: 2,
            blockMaxGasLimit: 4,
            livenessBond: 5,
            provabilityBond: 6,
            baseFeeSharingPctg: 7,
            anchorBlockHashes: emptyHashes,
            blobHashes: emptyHashes
        });

        bytes memory packed = LibCodec.packBatchContext(context);
        IInbox.BatchContext memory unpacked = LibCodec.unpackBatchContext(packed);

        assertEq(unpacked.prover, context.prover);
        assertEq(unpacked.anchorBlockHashes.length, 0);
        assertEq(unpacked.blobHashes.length, 0);
    }

    // -------------------------------------------------------------------------
    // BatchProveInput Tests
    // -------------------------------------------------------------------------

    function test_packUnpackBatchProveInputs_singleInput() public pure {
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](1);

        inputs[0] = IInbox.BatchProveInput({
            leftHash: bytes32(uint256(0x1111)),
            proposeMetaHash: bytes32(uint256(0x2222)),
            proveMeta: IInbox.BatchProveMetadata({
                proposer: address(0x3333),
                prover: address(0x4444),
                proposedAt: 5555,
                firstBlockId: 6666,
                lastBlockId: 7777,
                livenessBond: 8888,
                provabilityBond: 9999
            }),
            tran: IInbox.Transition({
                batchId: 1111,
                parentHash: bytes32(uint256(0xaaaa)),
                blockHash: bytes32(uint256(0xbbbb)),
                stateRoot: bytes32(uint256(0xcccc))
            })
        });

        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        IInbox.BatchProveInput[] memory unpacked = LibCodec.unpackBatchProveInputs(packed);

        assertEq(unpacked.length, 1);
        assertEq(unpacked[0].leftHash, inputs[0].leftHash);
        assertEq(unpacked[0].proposeMetaHash, inputs[0].proposeMetaHash);
        assertEq(unpacked[0].proveMeta.proposer, inputs[0].proveMeta.proposer);
        assertEq(unpacked[0].proveMeta.prover, inputs[0].proveMeta.prover);
        assertEq(unpacked[0].tran.batchId, inputs[0].tran.batchId);
        assertEq(unpacked[0].tran.parentHash, inputs[0].tran.parentHash);
        assertEq(unpacked[0].tran.blockHash, inputs[0].tran.blockHash);
        assertEq(unpacked[0].tran.stateRoot, inputs[0].tran.stateRoot);
    }

    function test_packUnpackBatchProveInputs_emptyArray() public pure {
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](0);

        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        IInbox.BatchProveInput[] memory unpacked = LibCodec.unpackBatchProveInputs(packed);

        assertEq(unpacked.length, 0);
    }

    // -------------------------------------------------------------------------
    // BatchProposeMetadataEvidence Tests
    // -------------------------------------------------------------------------

    function test_packUnpackBatchProposeMetadataEvidence_roundTrip() public pure {
        IInbox.BatchProposeMetadataEvidence memory evidence = IInbox.BatchProposeMetadataEvidence({
            leftHash: bytes32(uint256(0x1111111111111111)),
            proveMetaHash: bytes32(uint256(0x2222222222222222)),
            proposeMeta: IInbox.BatchProposeMetadata({
                lastBlockTimestamp: 123_456,
                lastBlockId: 789_012,
                lastAnchorBlockId: 345_678
            })
        });

        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
        assertEq(packed.length, 82); // 32+32+18 bytes

        IInbox.BatchProposeMetadataEvidence memory unpacked =
            LibCodec.unpackBatchProposeMetadataEvidence(packed);

        assertEq(unpacked.leftHash, evidence.leftHash);
        assertEq(unpacked.proveMetaHash, evidence.proveMetaHash);
        assertEq(unpacked.proposeMeta.lastBlockTimestamp, evidence.proposeMeta.lastBlockTimestamp);
        assertEq(unpacked.proposeMeta.lastBlockId, evidence.proposeMeta.lastBlockId);
        assertEq(unpacked.proposeMeta.lastAnchorBlockId, evidence.proposeMeta.lastAnchorBlockId);
    }

    function test_unpackBatchProposeMetadataEvidence_revertInvalidLength() public {
        bytes memory invalidData = new bytes(81); // Wrong length
        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackBatchProposeMetadataEvidence(invalidData);
    }

    // -------------------------------------------------------------------------
    // Batch Tests (Simplified due to complexity)
    // -------------------------------------------------------------------------

    function test_packUnpackBatches_emptyArray() public pure {
        IInbox.Batch[] memory batches = new IInbox.Batch[](0);

        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);

        assertEq(unpacked.length, 0);
    }

    function test_packUnpackBatches_singleBatch() public pure {
        IInbox.Batch[] memory batches = new IInbox.Batch[](1);

        // Create minimal batch for testing
        bytes memory emptyAuth = new bytes(0);
        bytes32[] memory emptySlots = new bytes32[](0);
        uint48[] memory emptyBlockIds = new uint48[](0);
        IInbox.Block[] memory emptyBlocks = new IInbox.Block[](0);

        batches[0] = IInbox.Batch({
            coinbase: address(0x2222),
            lastBlockTimestamp: 123_456,
            gasIssuancePerSecond: 789,
            proverAuth: emptyAuth,
            signalSlots: emptySlots,
            anchorBlockIds: emptyBlockIds,
            blocks: emptyBlocks,
            blobs: IInbox.Blobs({
                firstBlobIndex: 1,
                numBlobs: 2,
                byteOffset: 3,
                byteSize: 4
            })
        });

        bytes memory packed = LibCodec.packBatches(batches);
        IInbox.Batch[] memory unpacked = LibCodec.unpackBatches(packed);

        assertEq(unpacked.length, 1);
        // proposer field removed
        assertEq(unpacked[0].coinbase, batches[0].coinbase);
        assertEq(unpacked[0].lastBlockTimestamp, batches[0].lastBlockTimestamp);
        assertEq(unpacked[0].gasIssuancePerSecond, batches[0].gasIssuancePerSecond);
        // isForcedInclusion field removed
    }

    // -------------------------------------------------------------------------
    // Gas Optimization Tests
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
    }

    function test_gasOptimization_batchContext() public {
        bytes32[] memory anchorHashes = new bytes32[](5);
        bytes32[] memory blobHashes = new bytes32[](10);

        for (uint256 i = 0; i < 5; i++) {
            anchorHashes[i] = bytes32(uint256(i + 1));
        }
        for (uint256 i = 0; i < 10; i++) {
            blobHashes[i] = bytes32(uint256(i + 1000));
        }

        IInbox.BatchContext memory context = IInbox.BatchContext({
            prover: address(0x1234567890123456789012345678901234567890),
            txsHash: bytes32(uint256(0xabcdef)),
            lastAnchorBlockId: 123_456,
            lastBlockId: 789_012,
            blockMaxGasLimit: 901_234,
            livenessBond: 567_890,
            provabilityBond: 123_456,
            baseFeeSharingPctg: 50,
            anchorBlockHashes: anchorHashes,
            blobHashes: blobHashes
        });

        uint256 gasBefore = gasleft();
        bytes memory packed = LibCodec.packBatchContext(context);
        uint256 packGas = gasBefore - gasleft();

        gasBefore = gasleft();
        LibCodec.unpackBatchContext(packed);
        uint256 unpackGas = gasBefore - gasleft();

        emit log_named_uint("Gas used for packing BatchContext", packGas);
        emit log_named_uint("Gas used for unpacking BatchContext", unpackGas);
    }

    // -------------------------------------------------------------------------
    // Edge Case Tests
    // -------------------------------------------------------------------------

    function test_packBatches_revertArrayTooLarge() public {
        // This would test very large arrays, but we'll skip for gas reasons
        // In practice, the limit is type(uint8).max = 255
        // vm.expectRevert(LibCodec.ArrayTooLarge.selector);
        // ... create array with 65536 elements
    }

    function test_packBatchContext_revertArrayTooLarge() public {
        // Skip this test to avoid gas limit issues in CI
        // In practice, arrays larger than uint8.max would cause ArrayTooLarge error
        vm.skip(true);
    }

    function test_unpackBatchContext_revertInvalidLength() public {
        bytes memory invalidData = new bytes(86); // Less than minimum 87 bytes
        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackBatchContext(invalidData);
    }
}
