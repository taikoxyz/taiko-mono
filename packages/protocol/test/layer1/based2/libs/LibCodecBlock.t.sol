// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibCodec } from "contracts/layer1/based2/libs/LibCodec.sol";
import { IInbox } from "contracts/layer1/based2/IInbox.sol";

contract LibCodecBlockTest is Test {
    // -------------------------------------------------------------------------
    // Pack/Unpack Block Tests
    // -------------------------------------------------------------------------

    function test_packUnpackBlock_basicValues() public pure {
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: 100,
            timeShift: 15,
            anchorBlockId: 12345,
            numSignals: 5,
            hasAnchor: true
        });

        uint256 packed = LibCodec.packBlock(blockData);
        IInbox.Block memory unpacked = LibCodec.unpackBlock(packed);

        assertEq(unpacked.numTransactions, blockData.numTransactions);
        assertEq(unpacked.timeShift, blockData.timeShift);
        assertEq(unpacked.anchorBlockId, blockData.anchorBlockId);
        assertEq(unpacked.numSignals, blockData.numSignals);
        assertEq(unpacked.hasAnchor, blockData.hasAnchor);
    }

    function test_packUnpackBlock_maxValues() public pure {
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: type(uint16).max,
            timeShift: type(uint8).max,
            anchorBlockId: type(uint48).max,
            numSignals: type(uint8).max,
            hasAnchor: true
        });

        uint256 packed = LibCodec.packBlock(blockData);
        IInbox.Block memory unpacked = LibCodec.unpackBlock(packed);

        assertEq(unpacked.numTransactions, blockData.numTransactions);
        assertEq(unpacked.timeShift, blockData.timeShift);
        assertEq(unpacked.anchorBlockId, blockData.anchorBlockId);
        assertEq(unpacked.numSignals, blockData.numSignals);
        assertEq(unpacked.hasAnchor, blockData.hasAnchor);
    }

    function test_packUnpackBlock_minValues() public pure {
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: 0,
            timeShift: 0,
            anchorBlockId: 0,
            numSignals: 0,
            hasAnchor: false
        });

        uint256 packed = LibCodec.packBlock(blockData);
        IInbox.Block memory unpacked = LibCodec.unpackBlock(packed);

        assertEq(unpacked.numTransactions, blockData.numTransactions);
        assertEq(unpacked.timeShift, blockData.timeShift);
        assertEq(unpacked.anchorBlockId, blockData.anchorBlockId);
        assertEq(unpacked.numSignals, blockData.numSignals);
        assertEq(unpacked.hasAnchor, blockData.hasAnchor);
    }

    function test_packUnpackBlock_hasAnchorFlag() public pure {
        // Test hasAnchor = true
        IInbox.Block memory blockWithAnchor = IInbox.Block({
            numTransactions: 1,
            timeShift: 1,
            anchorBlockId: 1,
            numSignals: 1,
            hasAnchor: true
        });

        uint256 packed1 = LibCodec.packBlock(blockWithAnchor);
        IInbox.Block memory unpacked1 = LibCodec.unpackBlock(packed1);
        assertEq(unpacked1.hasAnchor, true);

        // Test hasAnchor = false
        IInbox.Block memory blockWithoutAnchor = IInbox.Block({
            numTransactions: 1,
            timeShift: 1,
            anchorBlockId: 1,
            numSignals: 1,
            hasAnchor: false
        });

        uint256 packed2 = LibCodec.packBlock(blockWithoutAnchor);
        IInbox.Block memory unpacked2 = LibCodec.unpackBlock(packed2);
        assertEq(unpacked2.hasAnchor, false);
    }

    function test_packBlock_bitPacking() public pure {
        // Test that bit packing works correctly by examining the packed value
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: 0x1234, // 16 bits
            timeShift: 0x56, // 8 bits  
            anchorBlockId: 0x789ABC, // 48 bits
            numSignals: 0xDE, // 8 bits
            hasAnchor: true // 1 bit
        });

        uint256 packed = LibCodec.packBlock(blockData);

        // Verify bit layout:
        // numTransactions: bits 0-15
        // timeShift: bits 16-23  
        // anchorBlockId: bits 24-71
        // numSignals: bits 72-79
        // hasAnchor: bit 80

        assertEq(packed & 0xFFFF, 0x1234); // numTransactions
        assertEq((packed >> 16) & 0xFF, 0x56); // timeShift
        assertEq((packed >> 24) & 0xFFFFFFFFFFFF, 0x789ABC); // anchorBlockId
        assertEq((packed >> 72) & 0xFF, 0xDE); // numSignals
        assertEq((packed >> 80) & 0x01, 1); // hasAnchor
    }

    // -------------------------------------------------------------------------
    // Data integrity tests
    // -------------------------------------------------------------------------

    function test_dataIntegrity_alternatingBits() public pure {
        // Test with alternating bit patterns to ensure no bit corruption
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: 0xAAAA, // 16-bit alternating pattern
            timeShift: 0x55, // 8-bit alternating pattern
            anchorBlockId: 0x555555555555, // 48-bit alternating pattern  
            numSignals: 0xAA, // 8-bit alternating pattern
            hasAnchor: true
        });

        uint256 packed = LibCodec.packBlock(blockData);
        IInbox.Block memory unpacked = LibCodec.unpackBlock(packed);

        assertEq(unpacked.numTransactions, blockData.numTransactions);
        assertEq(unpacked.timeShift, blockData.timeShift);
        assertEq(unpacked.anchorBlockId, blockData.anchorBlockId);
        assertEq(unpacked.numSignals, blockData.numSignals);
        assertEq(unpacked.hasAnchor, blockData.hasAnchor);
    }

    function test_dataIntegrity_boundaryValues() public pure {
        // Test with boundary values for each field
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: type(uint16).max - 1,
            timeShift: 1,
            anchorBlockId: type(uint48).max - 1,
            numSignals: type(uint8).max - 1,
            hasAnchor: true
        });

        uint256 packed = LibCodec.packBlock(blockData);
        IInbox.Block memory unpacked = LibCodec.unpackBlock(packed);

        assertEq(unpacked.numTransactions, blockData.numTransactions);
        assertEq(unpacked.timeShift, blockData.timeShift);
        assertEq(unpacked.anchorBlockId, blockData.anchorBlockId);
        assertEq(unpacked.numSignals, blockData.numSignals);
        assertEq(unpacked.hasAnchor, blockData.hasAnchor);
    }

    function test_multipleRoundTrips() public pure {
        IInbox.Block memory original = IInbox.Block({
            numTransactions: 999,
            timeShift: 123,
            anchorBlockId: 456789,
            numSignals: 42,
            hasAnchor: true
        });

        // Pack and unpack multiple times
        uint256 packed1 = LibCodec.packBlock(original);
        IInbox.Block memory unpacked1 = LibCodec.unpackBlock(packed1);

        uint256 packed2 = LibCodec.packBlock(unpacked1);
        IInbox.Block memory unpacked2 = LibCodec.unpackBlock(packed2);

        uint256 packed3 = LibCodec.packBlock(unpacked2);
        IInbox.Block memory unpacked3 = LibCodec.unpackBlock(packed3);

        // All should be identical
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked1)));
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked2)));
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked3)));
        assertEq(packed1, packed2);
        assertEq(packed2, packed3);
    }

    // -------------------------------------------------------------------------
    // Gas optimization tests
    // -------------------------------------------------------------------------

    function test_gasOptimization_packing() public {
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: 1000,
            timeShift: 30,
            anchorBlockId: 123456789,
            numSignals: 10,
            hasAnchor: true
        });

        uint256 gasBefore = gasleft();
        LibCodec.packBlock(blockData);
        uint256 packGas = gasBefore - gasleft();

        uint256 packed = LibCodec.packBlock(blockData);
        gasBefore = gasleft();
        LibCodec.unpackBlock(packed);
        uint256 unpackGas = gasBefore - gasleft();

        emit log_named_uint("Gas used for packing Block", packGas);
        emit log_named_uint("Gas used for unpacking Block", unpackGas);
    }

    function test_gasComparison_abiEncode() public {
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: 1000,
            timeShift: 30,
            anchorBlockId: 123456789,
            numSignals: 10,
            hasAnchor: true
        });

        // Custom packing
        uint256 gasBefore = gasleft();
        uint256 packed = LibCodec.packBlock(blockData);
        uint256 customPackGas = gasBefore - gasleft();

        gasBefore = gasleft();
        LibCodec.unpackBlock(packed);
        uint256 customUnpackGas = gasBefore - gasleft();

        // ABI encoding
        gasBefore = gasleft();
        bytes memory abiPacked = abi.encode(blockData);
        uint256 abiEncodeGas = gasBefore - gasleft();

        gasBefore = gasleft();
        abi.decode(abiPacked, (IInbox.Block));
        uint256 abiDecodeGas = gasBefore - gasleft();

        emit log_named_uint("Custom pack gas", customPackGas);
        emit log_named_uint("Custom unpack gas", customUnpackGas);
        emit log_named_uint("ABI encode gas", abiEncodeGas);
        emit log_named_uint("ABI decode gas", abiDecodeGas);
        emit log_named_uint("Custom packed size (bytes)", 32); // uint256 = 32 bytes
        emit log_named_uint("ABI packed size", abiPacked.length);

        // Custom packing should be much more efficient
        assertTrue(32 < abiPacked.length, "Custom packing should be smaller");
    }

    function test_gasOptimization_multipleBlocks() public {
        IInbox.Block[] memory blocks = new IInbox.Block[](100);
        
        for (uint256 i = 0; i < 100; i++) {
            blocks[i] = IInbox.Block({
                numTransactions: uint16(i + 1),
                timeShift: uint8(i % 256),
                anchorBlockId: uint48(i * 1000),
                numSignals: uint8(i % 100),
                hasAnchor: i % 2 == 0
            });
        }

        uint256 gasBefore = gasleft();
        for (uint256 i = 0; i < 100; i++) {
            LibCodec.packBlock(blocks[i]);
        }
        uint256 packGas = gasBefore - gasleft();

        uint256[] memory packedBlocks = new uint256[](100);
        for (uint256 i = 0; i < 100; i++) {
            packedBlocks[i] = LibCodec.packBlock(blocks[i]);
        }

        gasBefore = gasleft();
        for (uint256 i = 0; i < 100; i++) {
            LibCodec.unpackBlock(packedBlocks[i]);
        }
        uint256 unpackGas = gasBefore - gasleft();

        emit log_named_uint("Gas used for packing 100 blocks", packGas);
        emit log_named_uint("Gas used for unpacking 100 blocks", unpackGas);
        emit log_named_uint("Average pack gas per block", packGas / 100);
        emit log_named_uint("Average unpack gas per block", unpackGas / 100);
    }

    // -------------------------------------------------------------------------
    // Fuzz tests
    // -------------------------------------------------------------------------

    function testFuzz_packUnpack(
        uint16 numTransactions,
        uint8 timeShift,
        uint48 anchorBlockId,
        uint8 numSignals,
        bool hasAnchor
    ) public pure {
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: numTransactions,
            timeShift: timeShift,
            anchorBlockId: anchorBlockId,
            numSignals: numSignals,
            hasAnchor: hasAnchor
        });

        uint256 packed = LibCodec.packBlock(blockData);
        IInbox.Block memory unpacked = LibCodec.unpackBlock(packed);

        assertEq(unpacked.numTransactions, blockData.numTransactions);
        assertEq(unpacked.timeShift, blockData.timeShift);
        assertEq(unpacked.anchorBlockId, blockData.anchorBlockId);
        assertEq(unpacked.numSignals, blockData.numSignals);
        assertEq(unpacked.hasAnchor, blockData.hasAnchor);
    }

    function testFuzz_packUnpack_multipleBlocks(uint8 count) public pure {
        count = count % 50 + 1; // 1-50 blocks

        for (uint256 i = 0; i < count; i++) {
            IInbox.Block memory blockData = IInbox.Block({
                numTransactions: uint16(i + 1),
                timeShift: uint8(i),
                anchorBlockId: uint48(i * 1000),
                numSignals: uint8(i % 256),
                hasAnchor: i % 2 == 0
            });

            uint256 packed = LibCodec.packBlock(blockData);
            IInbox.Block memory unpacked = LibCodec.unpackBlock(packed);

            assertEq(unpacked.numTransactions, blockData.numTransactions);
            assertEq(unpacked.timeShift, blockData.timeShift);
            assertEq(unpacked.anchorBlockId, blockData.anchorBlockId);
            assertEq(unpacked.numSignals, blockData.numSignals);
            assertEq(unpacked.hasAnchor, blockData.hasAnchor);
        }
    }

    // -------------------------------------------------------------------------
    // Edge case tests
    // -------------------------------------------------------------------------

    function test_edgeCase_packedValueNonZero() public pure {
        // Ensure packed value is never zero for valid blocks (unless all fields are zero)
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: 1,
            timeShift: 0,
            anchorBlockId: 0,
            numSignals: 0,
            hasAnchor: false
        });

        uint256 packed = LibCodec.packBlock(blockData);
        assertTrue(packed != 0, "Packed value should not be zero for non-zero numTransactions");
    }

    function test_edgeCase_allZeroFields() public pure {
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: 0,
            timeShift: 0,
            anchorBlockId: 0,
            numSignals: 0,
            hasAnchor: false
        });

        uint256 packed = LibCodec.packBlock(blockData);
        assertEq(packed, 0, "Packed value should be zero for all-zero block");

        IInbox.Block memory unpacked = LibCodec.unpackBlock(packed);
        assertEq(unpacked.numTransactions, 0);
        assertEq(unpacked.timeShift, 0);
        assertEq(unpacked.anchorBlockId, 0);
        assertEq(unpacked.numSignals, 0);
        assertEq(unpacked.hasAnchor, false);
    }

    function test_edgeCase_onlyHasAnchorTrue() public pure {
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: 0,
            timeShift: 0,
            anchorBlockId: 0,
            numSignals: 0,
            hasAnchor: true
        });

        uint256 packed = LibCodec.packBlock(blockData);
        // Should equal 2^80 since hasAnchor is at bit 80
        assertEq(packed, 1 << 80, "Packed value should equal 2^80 for only hasAnchor=true");

        IInbox.Block memory unpacked = LibCodec.unpackBlock(packed);
        assertEq(unpacked.numTransactions, 0);
        assertEq(unpacked.timeShift, 0);
        assertEq(unpacked.anchorBlockId, 0);
        assertEq(unpacked.numSignals, 0);
        assertEq(unpacked.hasAnchor, true);
    }

    function test_edgeCase_realisticValues() public pure {
        // Test with realistic blockchain values
        IInbox.Block memory blockData = IInbox.Block({
            numTransactions: 150, // Realistic transaction count
            timeShift: 12, // 12 second block time
            anchorBlockId: 18_000_000, // Realistic Ethereum block number
            numSignals: 3, // Few signals
            hasAnchor: true
        });

        uint256 packed = LibCodec.packBlock(blockData);
        IInbox.Block memory unpacked = LibCodec.unpackBlock(packed);

        assertEq(unpacked.numTransactions, 150);
        assertEq(unpacked.timeShift, 12);
        assertEq(unpacked.anchorBlockId, 18_000_000);
        assertEq(unpacked.numSignals, 3);
        assertEq(unpacked.hasAnchor, true);
    }
}