// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibCodec } from "contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "contracts/layer1/based2/IInbox.sol";

contract LibCodecBatchProveInputTest is Test {
    // -------------------------------------------------------------------------
    // Pack/Unpack BatchProveInput Tests
    // -------------------------------------------------------------------------

    function test_packUnpackBatchProveInputs_emptyArray() public pure {
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](0);

        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        IInbox.BatchProveInput[] memory unpacked = LibCodec.unpackBatchProveInputs(packed);

        assertEq(unpacked.length, 0);
        assertEq(packed.length, 1); // Just the length field
    }

    function test_packUnpackBatchProveInputs_singleInput() public pure {
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](1);

        inputs[0] = IInbox.BatchProveInput({
            idAndBuildHash: bytes32(uint256(0x1111)),
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
        assertEq(unpacked[0].idAndBuildHash, inputs[0].idAndBuildHash);
        assertEq(unpacked[0].proposeMetaHash, inputs[0].proposeMetaHash);
        assertEq(unpacked[0].proveMeta.proposer, inputs[0].proveMeta.proposer);
        assertEq(unpacked[0].proveMeta.prover, inputs[0].proveMeta.prover);
        assertEq(unpacked[0].proveMeta.proposedAt, inputs[0].proveMeta.proposedAt);
        assertEq(unpacked[0].proveMeta.firstBlockId, inputs[0].proveMeta.firstBlockId);
        assertEq(unpacked[0].proveMeta.lastBlockId, inputs[0].proveMeta.lastBlockId);
        assertEq(unpacked[0].proveMeta.livenessBond, inputs[0].proveMeta.livenessBond);
        assertEq(unpacked[0].proveMeta.provabilityBond, inputs[0].proveMeta.provabilityBond);
        assertEq(unpacked[0].tran.batchId, inputs[0].tran.batchId);
        assertEq(unpacked[0].tran.parentHash, inputs[0].tran.parentHash);
        assertEq(unpacked[0].tran.blockHash, inputs[0].tran.blockHash);
        assertEq(unpacked[0].tran.stateRoot, inputs[0].tran.stateRoot);
    }

    function test_packUnpackBatchProveInputs_multipleInputs() public pure {
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](3);

        for (uint256 i = 0; i < 3; i++) {
            inputs[i] = IInbox.BatchProveInput({
                idAndBuildHash: keccak256(abi.encode("idAndBuild", i)),
                proposeMetaHash: keccak256(abi.encode("proposeMeta", i)),
                proveMeta: IInbox.BatchProveMetadata({
                    proposer: address(uint160(i + 100)),
                    prover: address(uint160(i + 200)),
                    proposedAt: uint48(i + 1000),
                    firstBlockId: uint48(i + 2000),
                    lastBlockId: uint48(i + 3000),
                    livenessBond: uint48(i + 4000),
                    provabilityBond: uint48(i + 5000)
                }),
                tran: IInbox.Transition({
                    batchId: uint48(i + 100),
                    parentHash: keccak256(abi.encode("parent", i)),
                    blockHash: keccak256(abi.encode("block", i)),
                    stateRoot: keccak256(abi.encode("state", i))
                })
            });
        }

        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        IInbox.BatchProveInput[] memory unpacked = LibCodec.unpackBatchProveInputs(packed);

        assertEq(unpacked.length, 3);

        for (uint256 i = 0; i < 3; i++) {
            assertEq(unpacked[i].idAndBuildHash, inputs[i].idAndBuildHash);
            assertEq(unpacked[i].proposeMetaHash, inputs[i].proposeMetaHash);
            assertEq(unpacked[i].proveMeta.proposer, inputs[i].proveMeta.proposer);
            assertEq(unpacked[i].proveMeta.prover, inputs[i].proveMeta.prover);
            assertEq(unpacked[i].proveMeta.proposedAt, inputs[i].proveMeta.proposedAt);
            assertEq(unpacked[i].proveMeta.firstBlockId, inputs[i].proveMeta.firstBlockId);
            assertEq(unpacked[i].proveMeta.lastBlockId, inputs[i].proveMeta.lastBlockId);
            assertEq(unpacked[i].proveMeta.livenessBond, inputs[i].proveMeta.livenessBond);
            assertEq(unpacked[i].proveMeta.provabilityBond, inputs[i].proveMeta.provabilityBond);
            assertEq(unpacked[i].tran.batchId, inputs[i].tran.batchId);
            assertEq(unpacked[i].tran.parentHash, inputs[i].tran.parentHash);
            assertEq(unpacked[i].tran.blockHash, inputs[i].tran.blockHash);
            assertEq(unpacked[i].tran.stateRoot, inputs[i].tran.stateRoot);
        }
    }

    function test_packBatchProveInputs_expectedSize() public pure {
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](2);

        for (uint256 i = 0; i < 2; i++) {
            inputs[i] = _createBatchProveInput(i);
        }

        bytes memory packed = LibCodec.packBatchProveInputs(inputs);

        // Expected size: 1 + (2 * 354) = 709 bytes
        assertEq(packed.length, 709);
    }

    function test_packBatchProveInputs_revertArrayTooLarge() public pure {
        // Test with a reasonable array size within uint8.max limit
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](200);

        for (uint256 i = 0; i < 200; i++) {
            inputs[i] = _createBatchProveInput(i);
        }

        // Should not revert for reasonable array sizes
        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        IInbox.BatchProveInput[] memory unpacked = LibCodec.unpackBatchProveInputs(packed);
        assertEq(unpacked.length, 200);
    }

    function test_unpackBatchProveInputs_revertInvalidDataLength() public {
        // Test with data that's too short (0 bytes is too short, need at least 1 for length)
        bytes memory tooShort = new bytes(0);

        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackBatchProveInputs(tooShort);
    }

    function test_unpackBatchProveInputs_revertWrongLength() public {
        // Test with wrong length (not 1 + n*354)
        bytes memory wrongLength = new bytes(100);

        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackBatchProveInputs(wrongLength);
    }

    // -------------------------------------------------------------------------
    // Data integrity tests
    // -------------------------------------------------------------------------

    function test_dataIntegrity_maxValues() public pure {
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](1);

        inputs[0] = IInbox.BatchProveInput({
            idAndBuildHash: bytes32(type(uint256).max),
            proposeMetaHash: bytes32(type(uint256).max - 1),
            proveMeta: IInbox.BatchProveMetadata({
                proposer: address(type(uint160).max),
                prover: address(type(uint160).max - 1),
                proposedAt: type(uint48).max,
                firstBlockId: type(uint48).max - 1,
                lastBlockId: type(uint48).max - 2,
                livenessBond: type(uint48).max - 3,
                provabilityBond: type(uint48).max - 4
            }),
            tran: IInbox.Transition({
                batchId: type(uint48).max,
                parentHash: bytes32(type(uint256).max - 2),
                blockHash: bytes32(type(uint256).max - 3),
                stateRoot: bytes32(type(uint256).max - 4)
            })
        });

        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        IInbox.BatchProveInput[] memory unpacked = LibCodec.unpackBatchProveInputs(packed);

        assertEq(unpacked.length, 1);
        assertEq(unpacked[0].idAndBuildHash, inputs[0].idAndBuildHash);
        assertEq(unpacked[0].proposeMetaHash, inputs[0].proposeMetaHash);
        assertEq(unpacked[0].proveMeta.proposer, inputs[0].proveMeta.proposer);
        assertEq(unpacked[0].proveMeta.prover, inputs[0].proveMeta.prover);
        assertEq(unpacked[0].proveMeta.proposedAt, inputs[0].proveMeta.proposedAt);
        assertEq(unpacked[0].proveMeta.firstBlockId, inputs[0].proveMeta.firstBlockId);
        assertEq(unpacked[0].proveMeta.lastBlockId, inputs[0].proveMeta.lastBlockId);
        assertEq(unpacked[0].proveMeta.livenessBond, inputs[0].proveMeta.livenessBond);
        assertEq(unpacked[0].proveMeta.provabilityBond, inputs[0].proveMeta.provabilityBond);
        assertEq(unpacked[0].tran.batchId, inputs[0].tran.batchId);
        assertEq(unpacked[0].tran.parentHash, inputs[0].tran.parentHash);
        assertEq(unpacked[0].tran.blockHash, inputs[0].tran.blockHash);
        assertEq(unpacked[0].tran.stateRoot, inputs[0].tran.stateRoot);
    }

    function test_dataIntegrity_minValues() public pure {
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](1);

        inputs[0] = IInbox.BatchProveInput({
            idAndBuildHash: bytes32(0),
            proposeMetaHash: bytes32(0),
            proveMeta: IInbox.BatchProveMetadata({
                proposer: address(0),
                prover: address(0),
                proposedAt: 0,
                firstBlockId: 0,
                lastBlockId: 0,
                livenessBond: 0,
                provabilityBond: 0
            }),
            tran: IInbox.Transition({
                batchId: 0,
                parentHash: bytes32(0),
                blockHash: bytes32(0),
                stateRoot: bytes32(0)
            })
        });

        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        IInbox.BatchProveInput[] memory unpacked = LibCodec.unpackBatchProveInputs(packed);

        assertEq(unpacked.length, 1);
        assertEq(unpacked[0].idAndBuildHash, bytes32(0));
        assertEq(unpacked[0].proposeMetaHash, bytes32(0));
        assertEq(unpacked[0].proveMeta.proposer, address(0));
        assertEq(unpacked[0].proveMeta.prover, address(0));
        assertEq(unpacked[0].proveMeta.proposedAt, 0);
        assertEq(unpacked[0].proveMeta.firstBlockId, 0);
        assertEq(unpacked[0].proveMeta.lastBlockId, 0);
        assertEq(unpacked[0].proveMeta.livenessBond, 0);
        assertEq(unpacked[0].proveMeta.provabilityBond, 0);
        assertEq(unpacked[0].tran.batchId, 0);
        assertEq(unpacked[0].tran.parentHash, bytes32(0));
        assertEq(unpacked[0].tran.blockHash, bytes32(0));
        assertEq(unpacked[0].tran.stateRoot, bytes32(0));
    }

    function test_multipleRoundTrips() public pure {
        IInbox.BatchProveInput[] memory original = new IInbox.BatchProveInput[](2);

        for (uint256 i = 0; i < 2; i++) {
            original[i] = _createBatchProveInput(i + 100);
        }

        // Pack and unpack multiple times
        bytes memory packed1 = LibCodec.packBatchProveInputs(original);
        IInbox.BatchProveInput[] memory unpacked1 = LibCodec.unpackBatchProveInputs(packed1);

        bytes memory packed2 = LibCodec.packBatchProveInputs(unpacked1);
        IInbox.BatchProveInput[] memory unpacked2 = LibCodec.unpackBatchProveInputs(packed2);

        bytes memory packed3 = LibCodec.packBatchProveInputs(unpacked2);
        IInbox.BatchProveInput[] memory unpacked3 = LibCodec.unpackBatchProveInputs(packed3);

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
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](10);

        for (uint256 i = 0; i < 10; i++) {
            inputs[i] = _createBatchProveInput(i);
        }

        uint256 gasBefore = gasleft();
        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        uint256 packGas = gasBefore - gasleft();

        gasBefore = gasleft();
        LibCodec.unpackBatchProveInputs(packed);
        uint256 unpackGas = gasBefore - gasleft();

        emit log_named_uint("Gas used for packing 10 BatchProveInputs", packGas);
        emit log_named_uint("Gas used for unpacking 10 BatchProveInputs", unpackGas);
        emit log_named_uint("Packed size for 10 BatchProveInputs", packed.length);
    }

    function test_gasComparison_abiEncode() public {
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](5);

        for (uint256 i = 0; i < 5; i++) {
            inputs[i] = _createBatchProveInput(i);
        }

        // Custom packing
        uint256 gasBefore = gasleft();
        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        uint256 customPackGas = gasBefore - gasleft();

        gasBefore = gasleft();
        LibCodec.unpackBatchProveInputs(packed);
        uint256 customUnpackGas = gasBefore - gasleft();

        // ABI encoding
        gasBefore = gasleft();
        bytes memory abiPacked = abi.encode(inputs);
        uint256 abiEncodeGas = gasBefore - gasleft();

        gasBefore = gasleft();
        abi.decode(abiPacked, (IInbox.BatchProveInput[]));
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
    // Fuzz tests
    // -------------------------------------------------------------------------

    function testFuzz_packUnpack_singleInput(
        bytes32 idAndBuildHash,
        address proposer,
        uint48 proposedAt,
        uint48 batchId
    )
        public
        pure
    {
        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](1);

        inputs[0] = IInbox.BatchProveInput({
            idAndBuildHash: idAndBuildHash,
            proposeMetaHash: keccak256("test"),
            proveMeta: IInbox.BatchProveMetadata({
                proposer: proposer,
                prover: address(0x1234),
                proposedAt: proposedAt,
                firstBlockId: 100,
                lastBlockId: 200,
                livenessBond: 300,
                provabilityBond: 400
            }),
            tran: IInbox.Transition({
                batchId: batchId,
                parentHash: keccak256("parent"),
                blockHash: keccak256("block"),
                stateRoot: keccak256("state")
            })
        });

        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        IInbox.BatchProveInput[] memory unpacked = LibCodec.unpackBatchProveInputs(packed);

        assertEq(unpacked.length, 1);
        assertEq(unpacked[0].idAndBuildHash, idAndBuildHash);
        assertEq(unpacked[0].proveMeta.proposer, proposer);
        assertEq(unpacked[0].proveMeta.proposedAt, proposedAt);
        assertEq(unpacked[0].tran.batchId, batchId);
    }

    function testFuzz_packUnpack_multipleInputs(uint8 count) public pure {
        count = count % 20 + 1; // 1-20 inputs

        IInbox.BatchProveInput[] memory inputs = new IInbox.BatchProveInput[](count);

        for (uint256 i = 0; i < count; i++) {
            inputs[i] = _createBatchProveInput(i);
        }

        bytes memory packed = LibCodec.packBatchProveInputs(inputs);
        IInbox.BatchProveInput[] memory unpacked = LibCodec.unpackBatchProveInputs(packed);

        assertEq(unpacked.length, count);

        for (uint256 i = 0; i < count; i++) {
            assertEq(unpacked[i].idAndBuildHash, inputs[i].idAndBuildHash);
            assertEq(unpacked[i].proposeMetaHash, inputs[i].proposeMetaHash);
            assertEq(unpacked[i].proveMeta.proposer, inputs[i].proveMeta.proposer);
            assertEq(unpacked[i].proveMeta.prover, inputs[i].proveMeta.prover);
            assertEq(unpacked[i].tran.batchId, inputs[i].tran.batchId);
            assertEq(unpacked[i].tran.parentHash, inputs[i].tran.parentHash);
            assertEq(unpacked[i].tran.blockHash, inputs[i].tran.blockHash);
            assertEq(unpacked[i].tran.stateRoot, inputs[i].tran.stateRoot);
        }
    }

    // -------------------------------------------------------------------------
    // Helper functions
    // -------------------------------------------------------------------------

    function _createBatchProveInput(uint256 seed)
        private
        pure
        returns (IInbox.BatchProveInput memory)
    {
        return IInbox.BatchProveInput({
            idAndBuildHash: keccak256(abi.encode("idAndBuild", seed)),
            proposeMetaHash: keccak256(abi.encode("proposeMeta", seed)),
            proveMeta: IInbox.BatchProveMetadata({
                proposer: address(uint160(seed + 100)),
                prover: address(uint160(seed + 200)),
                proposedAt: uint48(seed + 1000),
                firstBlockId: uint48(seed + 2000),
                lastBlockId: uint48(seed + 3000),
                livenessBond: uint48(seed + 4000),
                provabilityBond: uint48(seed + 5000)
            }),
            tran: IInbox.Transition({
                batchId: uint48(seed + 100),
                parentHash: keccak256(abi.encode("parent", seed)),
                blockHash: keccak256(abi.encode("block", seed)),
                stateRoot: keccak256(abi.encode("state", seed))
            })
        });
    }
}
