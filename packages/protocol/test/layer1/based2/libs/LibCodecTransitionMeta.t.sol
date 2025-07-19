// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibCodec } from "contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "contracts/layer1/based2/IInbox.sol";

contract LibCodecTransitionMetaTest is Test {
    // Test data
    IInbox.TransitionMeta[] private testMetas;

    function setUp() public {
        // Initialize test data
        delete testMetas;
    }

    // -------------------------------------------------------------------------
    // Tests for packTransitionMetas
    // -------------------------------------------------------------------------

    function test_packTransitionMetas_singleElement() public {
        // Create a single TransitionMeta
        IInbox.TransitionMeta memory meta = _createTransitionMeta(
            bytes32(uint256(1)), // blockHash
            bytes32(uint256(2)), // stateRoot
            address(0x1234567890123456789012345678901234567890), // prover
            IInbox.ProofTiming.InProvingWindow, // proofTiming
            uint48(1000), // createdAt
            true, // byAssignedProver
            uint48(100), // lastBlockId
            uint48(19_291), // provabilityBond
            uint48(99_818) // livenessBond
        );

        testMetas.push(meta);

        // Pack the meta
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Verify packed data structure
        _verifyPackedMeta(packed, 0, meta);
    }

    function test_packTransitionMetas_multipleElements() public {
        // Create multiple TransitionMetas
        for (uint256 i = 1; i <= 3; i++) {
            testMetas.push(
                _createTransitionMeta(
                    bytes32(uint256(i)), // blockHash
                    bytes32(uint256(i * 2)), // stateRoot
                    address(uint160(i * 1000)), // prover
                    IInbox.ProofTiming(i % 3), // proofTiming
                    uint48(i * 100), // createdAt
                    i % 2 == 0, // byAssignedProver
                    uint48(i * 10), // lastBlockId
                    uint48(i * 0.1 ether), // provabilityBond
                    uint48(i * 0.2 ether) // livenessBond
                )
            );
        }

        // Pack the metas
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Verify each packed meta
        for (uint256 i = 0; i < 3; i++) {
            _verifyPackedMeta(packed, i * 109, testMetas[i]);
        }
    }

    function test_packTransitionMetas_emptyArray() public view {
        // Pack empty array
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Verify empty array unpacks correctly
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);
        assertEq(unpacked.length, 0);
    }

    function test_packTransitionMetas_maxLength() public {
        // Create max allowed elements (255)
        for (uint256 i = 0; i < 255; i++) {
            testMetas.push(
                _createTransitionMeta(
                    bytes32(uint256(i)),
                    bytes32(uint256(i)),
                    address(uint160(i)),
                    IInbox.ProofTiming.InProvingWindow,
                    uint48(i),
                    false,
                    uint48(i),
                    uint48(i),
                    uint48(i)
                )
            );
        }

        // Pack should succeed
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Verify by unpacking and checking length
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);
        assertEq(unpacked.length, 255);
    }

    function test_packTransitionMetas_revertArrayTooLarge() public {
        // Create one more than max allowed elements (256 > 255)
        for (uint256 i = 0; i <= 255; i++) {
            testMetas.push(
                _createTransitionMeta(
                    bytes32(uint256(i)),
                    bytes32(uint256(i)),
                    address(uint160(i)),
                    IInbox.ProofTiming.InProvingWindow,
                    uint48(i),
                    false,
                    uint48(i),
                    uint48(i),
                    uint48(i)
                )
            );
        }

        // Should revert with TransitionMetasArrayTooLarge error
        vm.expectRevert(LibCodec.TransitionMetasArrayTooLarge.selector);
        LibCodec.packTransitionMetas(testMetas);
    }

    function test_packTransitionMetas_largeArray() public {
        // Create 200 elements (within uint8.max limit)
        for (uint256 i = 0; i < 200; i++) {
            testMetas.push(
                _createTransitionMeta(
                    keccak256(abi.encode("blockHash", i)),
                    keccak256(abi.encode("stateRoot", i)),
                    address(uint160(i + 1)),
                    IInbox.ProofTiming(i % 3),
                    uint48(i + 1),
                    i % 2 == 0,
                    uint48(i + 1),
                    uint48((i + 1) * 1000),
                    uint48((i + 1) * 2000)
                )
            );
        }

        // Pack and unpack
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);

        // Verify length and spot check a few elements
        assertEq(unpacked.length, 200);
        _assertTransitionMetaEq(unpacked[0], testMetas[0]);
        _assertTransitionMetaEq(unpacked[100], testMetas[100]);
        _assertTransitionMetaEq(unpacked[199], testMetas[199]);
    }

    // -------------------------------------------------------------------------
    // Tests for unpackTransitionMetas
    // -------------------------------------------------------------------------

    function test_unpackTransitionMetas_singleElement() public {
        // Create and pack a single meta
        IInbox.TransitionMeta memory originalMeta = _createTransitionMeta(
            bytes32(uint256(0x1234567890abcdef)),
            bytes32(uint256(0xfedcba0987654321)),
            address(0xdEADBEeF00000000000000000000000000000000),
            IInbox.ProofTiming.OutOfExtendedProvingWindow,
            uint48(123_456),
            true,
            uint48(999),
            uint48(2222),
            uint48(5555)
        );

        testMetas.push(originalMeta);
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Unpack
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);

        // Verify
        assertEq(unpacked.length, 1);
        _assertTransitionMetaEq(unpacked[0], originalMeta);
    }

    function test_unpackTransitionMetas_multipleElements() public {
        // Create and pack multiple metas
        for (uint256 i = 1; i <= 5; i++) {
            testMetas.push(
                _createTransitionMeta(
                    bytes32(uint256(i * 0x1111111111111111)),
                    bytes32(uint256(i * 0x2222222222222222)),
                    address(uint160(i * 0x3333333333333333)),
                    IInbox.ProofTiming(i % 3),
                    uint48(i * 1000),
                    i % 2 == 1,
                    uint48(i * 100),
                    uint48(i * 1 ether),
                    uint48(i * 2 ether)
                )
            );
        }

        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Unpack
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);

        // Verify
        assertEq(unpacked.length, 5);
        for (uint256 i = 0; i < 5; i++) {
            _assertTransitionMetaEq(unpacked[i], testMetas[i]);
        }
    }

    function test_unpackTransitionMetas_emptyArray() public view {
        // Pack empty array
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Unpack
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);

        // Verify
        assertEq(unpacked.length, 0);
    }

    function test_unpackTransitionMetas_revertEmptyInput() public pure {
        // Try to unpack empty bytes - should return empty array
        bytes memory empty;

        IInbox.TransitionMeta[] memory result = LibCodec.unpackTransitionMetas(empty);
        assertEq(result.length, 0);
    }

    function test_unpackTransitionMetas_revertInvalidDataLength() public {
        // Create invalid packed data (wrong length)
        bytes memory invalidPacked = new bytes(100); // Not n*109

        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        LibCodec.unpackTransitionMetas(invalidPacked);
    }

    // -------------------------------------------------------------------------
    // Round-trip tests
    // -------------------------------------------------------------------------

    function test_packUnpack_roundTrip() public {
        // Create diverse test data
        testMetas.push(
            _createTransitionMeta(
                bytes32(type(uint256).max),
                bytes32(type(uint256).max),
                address(type(uint160).max),
                IInbox.ProofTiming.InProvingWindow,
                type(uint48).max,
                true,
                type(uint48).max,
                type(uint48).max,
                type(uint48).max
            )
        );

        testMetas.push(
            _createTransitionMeta(
                bytes32(0),
                bytes32(0),
                address(0),
                IInbox.ProofTiming.OutOfExtendedProvingWindow,
                0,
                false,
                0,
                0,
                0
            )
        );

        // Pack and unpack
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);

        // Verify round trip
        assertEq(unpacked.length, testMetas.length);
        for (uint256 i = 0; i < testMetas.length; i++) {
            _assertTransitionMetaEq(unpacked[i], testMetas[i]);
        }
    }

    function testFuzz_packUnpack_roundTrip(
        bytes32 blockHash,
        bytes32 stateRoot,
        address prover,
        uint8 proofTimingRaw,
        uint48 createdAt,
        bool byAssignedProver,
        uint48 lastBlockId,
        uint48 provabilityBond,
        uint48 livenessBond
    )
        public
    {
        // Bound proofTiming to valid enum values
        IInbox.ProofTiming proofTiming = IInbox.ProofTiming(proofTimingRaw % 3);

        // Create meta
        IInbox.TransitionMeta memory meta = _createTransitionMeta(
            blockHash,
            stateRoot,
            prover,
            proofTiming,
            createdAt,
            byAssignedProver,
            lastBlockId,
            provabilityBond,
            livenessBond
        );

        testMetas.push(meta);

        // Pack and unpack
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);

        // Verify
        assertEq(unpacked.length, 1);
        _assertTransitionMetaEq(unpacked[0], meta);
    }

    function testFuzz_packUnpack_multipleElements(uint8 count) public {
        count = count % 50 + 1; // 1-50 elements

        for (uint256 i = 0; i < count; i++) {
            testMetas.push(
                _createTransitionMeta(
                    keccak256(abi.encode("fuzz", i, block.timestamp)),
                    keccak256(abi.encode("state", i, block.timestamp)),
                    address(uint160(i + 1)),
                    IInbox.ProofTiming(i % 3),
                    uint48(i + 1),
                    i % 2 == 0,
                    uint48(i + 1),
                    uint48((i + 1) * 1000),
                    uint48((i + 1) * 2000)
                )
            );
        }

        bytes memory packed = LibCodec.packTransitionMetas(testMetas);
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);

        assertEq(unpacked.length, count);
        for (uint256 i = 0; i < count; i++) {
            _assertTransitionMetaEq(unpacked[i], testMetas[i]);
        }
    }

    // -------------------------------------------------------------------------
    // Gas optimization tests
    // -------------------------------------------------------------------------

    function test_gasOptimization_packing() public {
        // Create test data of various sizes
        uint256[] memory sizes = new uint256[](4);
        sizes[0] = 1;
        sizes[1] = 10;
        sizes[2] = 50;
        sizes[3] = 100;

        for (uint256 i = 0; i < sizes.length; i++) {
            delete testMetas;

            // Create test metas
            for (uint256 j = 0; j < sizes[i]; j++) {
                testMetas.push(
                    _createTransitionMeta(
                        bytes32(uint256(j)),
                        bytes32(uint256(j)),
                        address(uint160(j)),
                        IInbox.ProofTiming.InProvingWindow,
                        uint48(j),
                        false,
                        uint48(j),
                        uint48(j),
                        uint48(j)
                    )
                );
            }

            // Measure gas for packing
            uint256 gasBefore = gasleft();
            LibCodec.packTransitionMetas(testMetas);
            uint256 gasUsed = gasBefore - gasleft();

            emit log_named_uint(
                string.concat("Gas used for packing ", vm.toString(sizes[i]), " elements"), gasUsed
            );
        }
    }

    function test_gasOptimization_unpacking() public {
        // Create test data
        for (uint256 i = 0; i < 100; i++) {
            testMetas.push(
                _createTransitionMeta(
                    bytes32(uint256(i)),
                    bytes32(uint256(i)),
                    address(uint160(i)),
                    IInbox.ProofTiming.InProvingWindow,
                    uint48(i),
                    false,
                    uint48(i),
                    uint48(i),
                    uint48(i)
                )
            );
        }

        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Measure gas for unpacking
        uint256 gasBefore = gasleft();
        LibCodec.unpackTransitionMetas(packed);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for unpacking 100 elements", gasUsed);
    }

    // -------------------------------------------------------------------------
    // Data integrity tests
    // -------------------------------------------------------------------------

    function test_dataIntegrity_allProofTimingValues() public {
        // Test all proof timing enum values
        for (uint256 i = 0; i < 3; i++) {
            testMetas.push(
                _createTransitionMeta(
                    bytes32(uint256(i)),
                    bytes32(uint256(i)),
                    address(uint160(i)),
                    IInbox.ProofTiming(i),
                    uint48(i),
                    i % 2 == 0,
                    uint48(i),
                    uint48(i),
                    uint48(i)
                )
            );
        }

        bytes memory packed = LibCodec.packTransitionMetas(testMetas);
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);

        for (uint256 i = 0; i < 3; i++) {
            assertEq(uint256(unpacked[i].proofTiming), i);
        }
    }

    function test_dataIntegrity_byAssignedProverFlag() public {
        // Test both true and false values for byAssignedProver
        testMetas.push(
            _createTransitionMeta(
                bytes32(uint256(1)),
                bytes32(uint256(1)),
                address(1),
                IInbox.ProofTiming.InProvingWindow,
                1,
                true,
                1,
                1,
                1
            )
        );

        testMetas.push(
            _createTransitionMeta(
                bytes32(uint256(2)),
                bytes32(uint256(2)),
                address(2),
                IInbox.ProofTiming.InProvingWindow,
                2,
                false,
                2,
                2,
                2
            )
        );

        bytes memory packed = LibCodec.packTransitionMetas(testMetas);
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(packed);

        assertEq(unpacked[0].byAssignedProver, true);
        assertEq(unpacked[1].byAssignedProver, false);
    }

    // -------------------------------------------------------------------------
    // Helper functions
    // -------------------------------------------------------------------------

    function _createTransitionMeta(
        bytes32 blockHash,
        bytes32 stateRoot,
        address prover,
        IInbox.ProofTiming proofTiming,
        uint48 createdAt,
        bool byAssignedProver,
        uint48 lastBlockId,
        uint48 provabilityBond,
        uint48 livenessBond
    )
        private
        pure
        returns (IInbox.TransitionMeta memory)
    {
        return IInbox.TransitionMeta({
            blockHash: blockHash,
            stateRoot: stateRoot,
            prover: prover,
            proofTiming: proofTiming,
            provedAt: createdAt,
            byAssignedProver: byAssignedProver,
            lastBlockId: lastBlockId,
            provabilityBond: provabilityBond,
            livenessBond: livenessBond
        });
    }

    function _assertTransitionMetaEq(
        IInbox.TransitionMeta memory a,
        IInbox.TransitionMeta memory b
    )
        private
        pure
    {
        assertEq(keccak256(abi.encode(a)), keccak256(abi.encode(b)));
    }

    function _verifyPackedMeta(
        bytes memory packed,
        uint256 offset,
        IInbox.TransitionMeta memory meta
    )
        private
        pure
    {
        // Extract single meta from packed data
        bytes memory singleMetaPacked = new bytes(109);
        for (uint256 i = 0; i < 109; i++) {
            singleMetaPacked[i] = packed[offset + i];
        }

        // Unpack and compare using hash
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(singleMetaPacked);
        assertEq(unpacked.length, 1);
        _assertTransitionMetaEq(unpacked[0], meta);
    }
}
