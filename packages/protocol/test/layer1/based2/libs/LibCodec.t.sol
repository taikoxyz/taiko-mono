// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibCodec } from "contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "contracts/layer1/based2/IInbox.sol";

contract LibCodecTest is Test {
    using LibCodec for IInbox.TransitionMeta;

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
            uint16(123), // provabilityBond
            uint16(456), // livenessBond
            uint8(18) // bondDecimals
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
                    uint16(i * 10), // provabilityBond
                    uint16(i * 20), // livenessBond
                    uint8(18) // bondDecimals
                )
            );
        }

        // Pack the metas
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Verify each packed meta
        for (uint256 i = 0; i < 3; i++) {
            _verifyPackedMeta(packed, i * 121, testMetas[i]);
        }
    }

    function test_packTransitionMetas_emptyArray() public view {
        // Pack empty array
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Verify empty array unpacks correctly
        IInbox.TransitionMeta[] memory unpacked = _unpackTransitionMetas(packed);
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
                    uint16(i),
                    uint16(i),
                    uint8(18) // bondDecimals
                )
            );
        }

        // Pack should succeed
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Verify by unpacking and checking length
        IInbox.TransitionMeta[] memory unpacked = _unpackTransitionMetas(packed);
        assertEq(unpacked.length, 255);
    }

    function test_packTransitionMetas_revertArrayTooLarge() public {
        // Create 256 elements (one more than max)
        for (uint256 i = 0; i < 256; i++) {
            testMetas.push(
                _createTransitionMeta(
                    bytes32(uint256(i)),
                    bytes32(uint256(i)),
                    address(uint160(i)),
                    IInbox.ProofTiming.InProvingWindow,
                    uint48(i),
                    false,
                    uint48(i),
                    uint16(i),
                    uint16(i),
                    uint8(18) // bondDecimals
                )
            );
        }

        // Should succeed since we removed the length limit
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Verify by unpacking and checking length
        IInbox.TransitionMeta[] memory unpacked = _unpackTransitionMetas(packed);
        assertEq(unpacked.length, 256);
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
            uint16(5000),
            uint16(10000),
            uint8(18) // bondDecimals
        );

        testMetas.push(originalMeta);
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Unpack
        IInbox.TransitionMeta[] memory unpacked = _unpackTransitionMetas(packed);

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
                    uint16(i * 1000),
                    uint16(i * 2000),
                    uint8(18) // bondDecimals
                )
            );
        }

        bytes memory packed = LibCodec.packTransitionMetas(testMetas);

        // Unpack
        IInbox.TransitionMeta[] memory unpacked = _unpackTransitionMetas(packed);

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
        IInbox.TransitionMeta[] memory unpacked = _unpackTransitionMetas(packed);

        // Verify
        assertEq(unpacked.length, 0);
    }

    function test_unpackTransitionMetas_revertEmptyInput() public pure {
        // Try to unpack empty bytes - should return empty array
        bytes memory empty;

        IInbox.TransitionMeta[] memory result = _unpackTransitionMetas(empty);
        assertEq(result.length, 0);
    }

    function test_unpackTransitionMetas_revertInvalidDataLength() public {
        // Create invalid packed data (wrong length)
        bytes memory invalidPacked = new bytes(100); // Not n*121

        vm.expectRevert(LibCodec.InvalidDataLength.selector);
        _unpackTransitionMetas(invalidPacked);
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
                uint16(type(uint96).max),
                uint16(type(uint96).max),
                uint8(18) // bondDecimals
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
                0,
                uint8(18) // bondDecimals
            )
        );

        // Pack and unpack
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);
        IInbox.TransitionMeta[] memory unpacked = _unpackTransitionMetas(packed);

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
        uint16 provabilityBond,
        uint16 livenessBond
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
            livenessBond,
            uint8(18) // bondDecimals
        );

        testMetas.push(meta);

        // Pack and unpack
        bytes memory packed = LibCodec.packTransitionMetas(testMetas);
        IInbox.TransitionMeta[] memory unpacked = _unpackTransitionMetas(packed);

        // Verify
        assertEq(unpacked.length, 1);
        _assertTransitionMetaEq(unpacked[0], meta);
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
                        uint16(j),
                        uint16(j),
                        uint8(18) // bondDecimals
                    )
                );
            }

            // Measure gas for packing
            uint256 gasBefore = gasleft();
            LibCodec.packTransitionMetas(testMetas);
            uint256 gasUsed = gasBefore - gasleft();

            emit log_named_uint(
                string(abi.encodePacked("Gas used for packing ", vm.toString(sizes[i]), " elements")), gasUsed
            );
        }
    }

    // -------------------------------------------------------------------------
    // Helper functions
    // -------------------------------------------------------------------------

    function _unpackTransitionMetas(bytes memory packed)
        private
        pure
        returns (IInbox.TransitionMeta[] memory)
    {
        return LibCodec.unpackTransitionMetas(packed);
    }

    function _createTransitionMeta(
        bytes32 blockHash,
        bytes32 stateRoot,
        address prover,
        IInbox.ProofTiming proofTiming,
        uint48 createdAt,
        bool byAssignedProver,
        uint48 lastBlockId,
        uint16 provabilityBond,
        uint16 livenessBond,
        uint8 bondDecimals
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
            createdAt: createdAt,
            byAssignedProver: byAssignedProver,
            lastBlockId: lastBlockId,
            provabilityBond: provabilityBond,
            livenessBond: livenessBond,
            bondDecimals: bondDecimals
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
        bytes memory singleMetaPacked = new bytes(121);
        for (uint256 i = 0; i < 121; i++) {
            singleMetaPacked[i] = packed[offset + i];
        }

        // Unpack and compare using hash
        IInbox.TransitionMeta[] memory unpacked = LibCodec.unpackTransitionMetas(singleMetaPacked);
        assertEq(unpacked.length, 1);
        _assertTransitionMetaEq(unpacked[0], meta);
    }
}
