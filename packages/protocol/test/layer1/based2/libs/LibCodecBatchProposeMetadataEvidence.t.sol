// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibCodec } from "contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "contracts/layer1/based2/IInbox.sol";

contract LibCodecBatchProposeMetadataEvidenceTest is Test {
    // -------------------------------------------------------------------------
    // Pack/Unpack BatchProposeMetadataEvidence Tests
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

    function test_packBatchProposeMetadataEvidence_expectedSize() public pure {
        IInbox.BatchProposeMetadataEvidence memory evidence = _createEvidence(1);

        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);

        // Expected size: 32 (leftHash) + 32 (proveMetaHash) + 6 + 6 + 6 (proposeMeta) = 82
        // bytes
        assertEq(packed.length, 82);
    }

    function test_unpackBatchProposeMetadataEvidence_revertInvalidLength() public {
        bytes memory invalidData = new bytes(81); // Wrong length
        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackBatchProposeMetadataEvidence(invalidData);
    }

    function test_unpackBatchProposeMetadataEvidence_revertTooShort() public {
        bytes memory tooShort = new bytes(50);
        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackBatchProposeMetadataEvidence(tooShort);
    }

    function test_unpackBatchProposeMetadataEvidence_revertTooLong() public {
        bytes memory tooLong = new bytes(100);
        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackBatchProposeMetadataEvidence(tooLong);
    }

    // -------------------------------------------------------------------------
    // Data integrity tests
    // -------------------------------------------------------------------------

    function test_dataIntegrity_maxValues() public pure {
        IInbox.BatchProposeMetadataEvidence memory evidence = IInbox.BatchProposeMetadataEvidence({
            leftHash: bytes32(type(uint256).max),
            proveMetaHash: bytes32(type(uint256).max - 1),
            proposeMeta: IInbox.BatchProposeMetadata({
                lastBlockTimestamp: type(uint48).max,
                lastBlockId: type(uint48).max - 1,
                lastAnchorBlockId: type(uint48).max - 2
            })
        });

        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
        IInbox.BatchProposeMetadataEvidence memory unpacked =
            LibCodec.unpackBatchProposeMetadataEvidence(packed);

        assertEq(unpacked.leftHash, evidence.leftHash);
        assertEq(unpacked.proveMetaHash, evidence.proveMetaHash);
        assertEq(unpacked.proposeMeta.lastBlockTimestamp, evidence.proposeMeta.lastBlockTimestamp);
        assertEq(unpacked.proposeMeta.lastBlockId, evidence.proposeMeta.lastBlockId);
        assertEq(unpacked.proposeMeta.lastAnchorBlockId, evidence.proposeMeta.lastAnchorBlockId);
    }

    function test_dataIntegrity_minValues() public pure {
        IInbox.BatchProposeMetadataEvidence memory evidence = IInbox.BatchProposeMetadataEvidence({
            leftHash: bytes32(0),
            proveMetaHash: bytes32(0),
            proposeMeta: IInbox.BatchProposeMetadata({
                lastBlockTimestamp: 0,
                lastBlockId: 0,
                lastAnchorBlockId: 0
            })
        });

        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
        IInbox.BatchProposeMetadataEvidence memory unpacked =
            LibCodec.unpackBatchProposeMetadataEvidence(packed);

        assertEq(unpacked.leftHash, bytes32(0));
        assertEq(unpacked.proveMetaHash, bytes32(0));
        assertEq(unpacked.proposeMeta.lastBlockTimestamp, 0);
        assertEq(unpacked.proposeMeta.lastBlockId, 0);
        assertEq(unpacked.proposeMeta.lastAnchorBlockId, 0);
    }

    function test_dataIntegrity_alternatingBits() public pure {
        // Test with alternating bit patterns to ensure no bit corruption
        IInbox.BatchProposeMetadataEvidence memory evidence = IInbox.BatchProposeMetadataEvidence({
            leftHash: bytes32(0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA),
            proveMetaHash: bytes32(0x5555555555555555555555555555555555555555555555555555555555555555),
            proposeMeta: IInbox.BatchProposeMetadata({
                lastBlockTimestamp: 0xAAAAAA, // 24-bit alternating pattern
                lastBlockId: 0x555555, // 24-bit alternating pattern
                lastAnchorBlockId: 0xAAAAAA
            })
        });

        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
        IInbox.BatchProposeMetadataEvidence memory unpacked =
            LibCodec.unpackBatchProposeMetadataEvidence(packed);

        assertEq(unpacked.leftHash, evidence.leftHash);
        assertEq(unpacked.proveMetaHash, evidence.proveMetaHash);
        assertEq(unpacked.proposeMeta.lastBlockTimestamp, evidence.proposeMeta.lastBlockTimestamp);
        assertEq(unpacked.proposeMeta.lastBlockId, evidence.proposeMeta.lastBlockId);
        assertEq(unpacked.proposeMeta.lastAnchorBlockId, evidence.proposeMeta.lastAnchorBlockId);
    }

    function test_dataIntegrity_boundaryValues() public pure {
        // Test with boundary values for each field type
        IInbox.BatchProposeMetadataEvidence memory evidence = IInbox.BatchProposeMetadataEvidence({
            leftHash: bytes32(uint256(1)),
            proveMetaHash: bytes32(type(uint256).max - 1),
            proposeMeta: IInbox.BatchProposeMetadata({
                lastBlockTimestamp: type(uint48).max,
                lastBlockId: 1,
                lastAnchorBlockId: type(uint48).max - 1
            })
        });

        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
        IInbox.BatchProposeMetadataEvidence memory unpacked =
            LibCodec.unpackBatchProposeMetadataEvidence(packed);

        assertEq(unpacked.leftHash, evidence.leftHash);
        assertEq(unpacked.proveMetaHash, evidence.proveMetaHash);
        assertEq(unpacked.proposeMeta.lastBlockTimestamp, evidence.proposeMeta.lastBlockTimestamp);
        assertEq(unpacked.proposeMeta.lastBlockId, evidence.proposeMeta.lastBlockId);
        assertEq(unpacked.proposeMeta.lastAnchorBlockId, evidence.proposeMeta.lastAnchorBlockId);
    }

    function test_multipleRoundTrips() public pure {
        IInbox.BatchProposeMetadataEvidence memory original = _createEvidence(12_345);

        // Pack and unpack multiple times
        bytes memory packed1 = LibCodec.packBatchProposeMetadataEvidence(original);
        IInbox.BatchProposeMetadataEvidence memory unpacked1 =
            LibCodec.unpackBatchProposeMetadataEvidence(packed1);

        bytes memory packed2 = LibCodec.packBatchProposeMetadataEvidence(unpacked1);
        IInbox.BatchProposeMetadataEvidence memory unpacked2 =
            LibCodec.unpackBatchProposeMetadataEvidence(packed2);

        bytes memory packed3 = LibCodec.packBatchProposeMetadataEvidence(unpacked2);
        IInbox.BatchProposeMetadataEvidence memory unpacked3 =
            LibCodec.unpackBatchProposeMetadataEvidence(packed3);

        // All should be identical
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked1)));
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked2)));
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked3)));
        assertEq(keccak256(packed1), keccak256(packed2));
        assertEq(keccak256(packed2), keccak256(packed3));
    }

    // -------------------------------------------------------------------------
    // Gas optimization tests
    // -------------------------------------------------------------------------

    function test_gasOptimization_packing() public {
        IInbox.BatchProposeMetadataEvidence memory evidence = _createEvidence(999);

        uint256 gasBefore = gasleft();
        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
        uint256 packGas = gasBefore - gasleft();

        gasBefore = gasleft();
        LibCodec.unpackBatchProposeMetadataEvidence(packed);
        uint256 unpackGas = gasBefore - gasleft();

        emit log_named_uint("Gas used for packing BatchProposeMetadataEvidence", packGas);
        emit log_named_uint("Gas used for unpacking BatchProposeMetadataEvidence", unpackGas);
        emit log_named_uint("Packed size", packed.length);
    }

    function test_gasComparison_abiEncode() public {
        IInbox.BatchProposeMetadataEvidence memory evidence = _createEvidence(777);

        // Custom packing
        uint256 gasBefore = gasleft();
        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
        uint256 customPackGas = gasBefore - gasleft();

        gasBefore = gasleft();
        LibCodec.unpackBatchProposeMetadataEvidence(packed);
        uint256 customUnpackGas = gasBefore - gasleft();

        // ABI encoding
        gasBefore = gasleft();
        bytes memory abiPacked = abi.encode(evidence);
        uint256 abiEncodeGas = gasBefore - gasleft();

        gasBefore = gasleft();
        abi.decode(abiPacked, (IInbox.BatchProposeMetadataEvidence));
        uint256 abiDecodeGas = gasBefore - gasleft();

        emit log_named_uint("Custom pack gas", customPackGas);
        emit log_named_uint("Custom unpack gas", customUnpackGas);
        emit log_named_uint("ABI encode gas", abiEncodeGas);
        emit log_named_uint("ABI decode gas", abiDecodeGas);
        emit log_named_uint("Custom packed size", packed.length);
        emit log_named_uint("ABI packed size", abiPacked.length);

        // Custom packing should be more efficient
        assertTrue(packed.length < abiPacked.length, "Custom packing should be smaller");
    }

    // -------------------------------------------------------------------------
    // Fuzz tests
    // -------------------------------------------------------------------------

    function testFuzz_packUnpack(
        bytes32 leftHash,
        bytes32 proveMetaHash,
        uint48 lastBlockTimestamp,
        uint48 lastBlockId,
        uint48 lastAnchorBlockId
    )
        public
        pure
    {
        IInbox.BatchProposeMetadataEvidence memory evidence = IInbox.BatchProposeMetadataEvidence({
            leftHash: leftHash,
            proveMetaHash: proveMetaHash,
            proposeMeta: IInbox.BatchProposeMetadata({
                lastBlockTimestamp: lastBlockTimestamp,
                lastBlockId: lastBlockId,
                lastAnchorBlockId: lastAnchorBlockId
            })
        });

        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
        IInbox.BatchProposeMetadataEvidence memory unpacked =
            LibCodec.unpackBatchProposeMetadataEvidence(packed);

        assertEq(unpacked.leftHash, evidence.leftHash);
        assertEq(unpacked.proveMetaHash, evidence.proveMetaHash);
        assertEq(unpacked.proposeMeta.lastBlockTimestamp, evidence.proposeMeta.lastBlockTimestamp);
        assertEq(unpacked.proposeMeta.lastBlockId, evidence.proposeMeta.lastBlockId);
        assertEq(unpacked.proposeMeta.lastAnchorBlockId, evidence.proposeMeta.lastAnchorBlockId);
    }

    function testFuzz_packUnpack_multipleEvidence(uint8 count) public pure {
        count = count % 10 + 1; // 1-10 evidence items

        for (uint256 i = 0; i < count; i++) {
            IInbox.BatchProposeMetadataEvidence memory evidence = _createEvidence(i);

            bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
            IInbox.BatchProposeMetadataEvidence memory unpacked =
                LibCodec.unpackBatchProposeMetadataEvidence(packed);

            assertEq(unpacked.leftHash, evidence.leftHash);
            assertEq(unpacked.proveMetaHash, evidence.proveMetaHash);
            assertEq(
                unpacked.proposeMeta.lastBlockTimestamp, evidence.proposeMeta.lastBlockTimestamp
            );
            assertEq(unpacked.proposeMeta.lastBlockId, evidence.proposeMeta.lastBlockId);
            assertEq(unpacked.proposeMeta.lastAnchorBlockId, evidence.proposeMeta.lastAnchorBlockId);
        }
    }

    // -------------------------------------------------------------------------
    // Edge case tests
    // -------------------------------------------------------------------------

    function test_edgeCase_sequentialValues() public pure {
        // Test with sequential values to ensure no value mixing
        IInbox.BatchProposeMetadataEvidence memory evidence = IInbox.BatchProposeMetadataEvidence({
            leftHash: bytes32(
                uint256(0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef)
            ),
            proveMetaHash: bytes32(
                uint256(0xfedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210)
            ),
            proposeMeta: IInbox.BatchProposeMetadata({
                lastBlockTimestamp: 111_111,
                lastBlockId: 222_222,
                lastAnchorBlockId: 333_333
            })
        });

        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
        IInbox.BatchProposeMetadataEvidence memory unpacked =
            LibCodec.unpackBatchProposeMetadataEvidence(packed);

        assertEq(unpacked.leftHash, evidence.leftHash);
        assertEq(unpacked.proveMetaHash, evidence.proveMetaHash);
        assertEq(unpacked.proposeMeta.lastBlockTimestamp, evidence.proposeMeta.lastBlockTimestamp);
        assertEq(unpacked.proposeMeta.lastBlockId, evidence.proposeMeta.lastBlockId);
        assertEq(unpacked.proposeMeta.lastAnchorBlockId, evidence.proposeMeta.lastAnchorBlockId);
    }

    function test_edgeCase_randomHashes() public pure {
        // Test with realistic hash values
        IInbox.BatchProposeMetadataEvidence memory evidence = IInbox.BatchProposeMetadataEvidence({
            leftHash: keccak256("test_id_and_build_hash"),
            proveMetaHash: keccak256("test_prove_meta_hash"),
            proposeMeta: IInbox.BatchProposeMetadata({
                lastBlockTimestamp: 1_640_995_200, // Jan 1, 2022
                lastBlockId: 1_000_000,
                lastAnchorBlockId: 999_999
            })
        });

        bytes memory packed = LibCodec.packBatchProposeMetadataEvidence(evidence);
        IInbox.BatchProposeMetadataEvidence memory unpacked =
            LibCodec.unpackBatchProposeMetadataEvidence(packed);

        assertEq(unpacked.leftHash, evidence.leftHash);
        assertEq(unpacked.proveMetaHash, evidence.proveMetaHash);
        assertEq(unpacked.proposeMeta.lastBlockTimestamp, evidence.proposeMeta.lastBlockTimestamp);
        assertEq(unpacked.proposeMeta.lastBlockId, evidence.proposeMeta.lastBlockId);
        assertEq(unpacked.proposeMeta.lastAnchorBlockId, evidence.proposeMeta.lastAnchorBlockId);
    }

    // -------------------------------------------------------------------------
    // Helper functions
    // -------------------------------------------------------------------------

    function _createEvidence(uint256 seed)
        private
        pure
        returns (IInbox.BatchProposeMetadataEvidence memory)
    {
        return IInbox.BatchProposeMetadataEvidence({
            leftHash: keccak256(abi.encode("idAndBuild", seed)),
            proveMetaHash: keccak256(abi.encode("proveMeta", seed)),
            proposeMeta: IInbox.BatchProposeMetadata({
                lastBlockTimestamp: uint48(seed + 1000),
                lastBlockId: uint48(seed + 2000),
                lastAnchorBlockId: uint48(seed + 3000)
            })
        });
    }
}
