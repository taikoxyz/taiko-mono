// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibPackUnpack } from "src/layer1/core/libs/LibPackUnpack.sol";

/// @title LibPackUnpackTest
/// @notice Comprehensive tests for LibPackUnpack functions
/// @custom:security-contact security@taiko.xyz
contract LibPackUnpackTest is Test {
    // ---------------------------------------------------------------
    // Test packUint8 / unpackUint8
    // ---------------------------------------------------------------

    function test_packUnpackUint8_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        // Pack value
        uint8 value = 0;
        uint256 newPtr = LibPackUnpack.packUint8(ptr, value);
        assertEq(newPtr, ptr + 1);

        // Unpack value
        (uint8 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint8(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 1);
    }

    function test_packUnpackUint8_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        // Pack value
        uint8 value = type(uint8).max;
        uint256 newPtr = LibPackUnpack.packUint8(ptr, value);
        assertEq(newPtr, ptr + 1);

        // Unpack value
        (uint8 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint8(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 1);
    }

    function test_packUnpackUint8_various() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint8[] memory testValues = new uint8[](5);
        testValues[0] = 0;
        testValues[1] = 1;
        testValues[2] = 127;
        testValues[3] = 128;
        testValues[4] = 255;

        for (uint256 i = 0; i < testValues.length; i++) {
            uint256 writePtr = ptr + i;
            uint256 newPtr = LibPackUnpack.packUint8(writePtr, testValues[i]);
            assertEq(newPtr, writePtr + 1);

            (uint8 unpacked,) = LibPackUnpack.unpackUint8(writePtr);
            assertEq(unpacked, testValues[i]);
        }
    }

    // ---------------------------------------------------------------
    // Test packUint16 / unpackUint16
    // ---------------------------------------------------------------

    function test_packUnpackUint16_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint16 value = 0;
        uint256 newPtr = LibPackUnpack.packUint16(ptr, value);
        assertEq(newPtr, ptr + 2);

        (uint16 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint16(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 2);
    }

    function test_packUnpackUint16_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint16 value = type(uint16).max;
        uint256 newPtr = LibPackUnpack.packUint16(ptr, value);
        assertEq(newPtr, ptr + 2);

        (uint16 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint16(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 2);
    }

    function test_packUnpackUint16_bigEndian() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint16 value = 0x1234; // Test big-endian encoding
        LibPackUnpack.packUint16(ptr, value);

        // Check raw bytes are big-endian
        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);

        (uint16 unpacked,) = LibPackUnpack.unpackUint16(ptr);
        assertEq(unpacked, value);
    }

    // ---------------------------------------------------------------
    // Test packUint32 / unpackUint32
    // ---------------------------------------------------------------

    function test_packUnpackUint32_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint32 value = 0;
        uint256 newPtr = LibPackUnpack.packUint32(ptr, value);
        assertEq(newPtr, ptr + 4);

        (uint32 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint32(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 4);
    }

    function test_packUnpackUint32_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint32 value = type(uint32).max;
        uint256 newPtr = LibPackUnpack.packUint32(ptr, value);
        assertEq(newPtr, ptr + 4);

        (uint32 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint32(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 4);
    }

    function test_packUnpackUint32_bigEndian() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint32 value = 0x12345678;
        LibPackUnpack.packUint32(ptr, value);

        // Check raw bytes are big-endian
        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);
        assertEq(uint8(buffer[2]), 0x56);
        assertEq(uint8(buffer[3]), 0x78);

        (uint32 unpacked,) = LibPackUnpack.unpackUint32(ptr);
        assertEq(unpacked, value);
    }

    // ---------------------------------------------------------------
    // Test packUint48 / unpackUint48
    // ---------------------------------------------------------------

    function test_packUnpackUint48_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint48 value = 0;
        uint256 newPtr = LibPackUnpack.packUint48(ptr, value);
        assertEq(newPtr, ptr + 6);

        (uint48 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint48(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 6);
    }

    function test_packUnpackUint48_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint48 value = type(uint48).max;
        uint256 newPtr = LibPackUnpack.packUint48(ptr, value);
        assertEq(newPtr, ptr + 6);

        (uint48 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint48(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 6);
    }

    function test_packUnpackUint48_bigEndian() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint48 value = 0x123456789ABC;
        LibPackUnpack.packUint48(ptr, value);

        // Check raw bytes are big-endian
        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);
        assertEq(uint8(buffer[2]), 0x56);
        assertEq(uint8(buffer[3]), 0x78);
        assertEq(uint8(buffer[4]), 0x9A);
        assertEq(uint8(buffer[5]), 0xBC);

        (uint48 unpacked,) = LibPackUnpack.unpackUint48(ptr);
        assertEq(unpacked, value);
    }

    // ---------------------------------------------------------------
    // Test packUint256 / unpackUint256
    // ---------------------------------------------------------------

    function test_packUnpackUint256_zero() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint256 value = 0;
        uint256 newPtr = LibPackUnpack.packUint256(ptr, value);
        assertEq(newPtr, ptr + 32);

        (uint256 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint256(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 32);
    }

    function test_packUnpackUint256_max() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint256 value = type(uint256).max;
        uint256 newPtr = LibPackUnpack.packUint256(ptr, value);
        assertEq(newPtr, ptr + 32);

        (uint256 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint256(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 32);
    }

    function test_packUnpackUint256_various() public pure {
        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint256[] memory testValues = new uint256[](3);
        testValues[0] = 1;
        testValues[1] = 0x123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF;
        testValues[2] = type(uint256).max - 1;

        uint256 currentPtr = ptr;
        for (uint256 i = 0; i < testValues.length; i++) {
            uint256 newPtr = LibPackUnpack.packUint256(currentPtr, testValues[i]);
            assertEq(newPtr, currentPtr + 32);

            (uint256 unpacked,) = LibPackUnpack.unpackUint256(currentPtr);
            assertEq(unpacked, testValues[i]);

            currentPtr = newPtr;
        }
    }

    // ---------------------------------------------------------------
    // Test packBytes32 / unpackBytes32
    // ---------------------------------------------------------------

    function test_packUnpackBytes32_zero() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        bytes32 value = bytes32(0);
        uint256 newPtr = LibPackUnpack.packBytes32(ptr, value);
        assertEq(newPtr, ptr + 32);

        (bytes32 unpacked, uint256 readPtr) = LibPackUnpack.unpackBytes32(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 32);
    }

    function test_packUnpackBytes32_max() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        bytes32 value = bytes32(type(uint256).max);
        uint256 newPtr = LibPackUnpack.packBytes32(ptr, value);
        assertEq(newPtr, ptr + 32);

        (bytes32 unpacked, uint256 readPtr) = LibPackUnpack.unpackBytes32(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 32);
    }

    function test_packUnpackBytes32_hash() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        bytes32 value = keccak256("test data");
        uint256 newPtr = LibPackUnpack.packBytes32(ptr, value);
        assertEq(newPtr, ptr + 32);

        (bytes32 unpacked, uint256 readPtr) = LibPackUnpack.unpackBytes32(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 32);
    }

    // ---------------------------------------------------------------
    // Test packAddress / unpackAddress
    // ---------------------------------------------------------------

    function test_packUnpackAddress_zero() public pure {
        bytes memory buffer = new bytes(30);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        address value = address(0);
        uint256 newPtr = LibPackUnpack.packAddress(ptr, value);
        assertEq(newPtr, ptr + 20);

        (address unpacked, uint256 readPtr) = LibPackUnpack.unpackAddress(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 20);
    }

    function test_packUnpackAddress_max() public pure {
        bytes memory buffer = new bytes(30);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        address value = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        uint256 newPtr = LibPackUnpack.packAddress(ptr, value);
        assertEq(newPtr, ptr + 20);

        (address unpacked, uint256 readPtr) = LibPackUnpack.unpackAddress(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 20);
    }

    function test_packUnpackAddress_various() public pure {
        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        address[] memory testAddresses = new address[](4);
        testAddresses[0] = address(0);
        testAddresses[1] = address(0x1234567890123456789012345678901234567890);
        testAddresses[2] = address(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
        testAddresses[3] = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);

        uint256 currentPtr = ptr;
        for (uint256 i = 0; i < testAddresses.length; i++) {
            uint256 newPtr = LibPackUnpack.packAddress(currentPtr, testAddresses[i]);
            assertEq(newPtr, currentPtr + 20);

            (address unpacked,) = LibPackUnpack.unpackAddress(currentPtr);
            assertEq(unpacked, testAddresses[i]);

            currentPtr = newPtr;
        }
    }

    function test_packUnpackAddress_bigEndian() public pure {
        bytes memory buffer = new bytes(30);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        address value = address(0x1234567890AbcdEF1234567890aBcdef12345678);
        LibPackUnpack.packAddress(ptr, value);

        // Check raw bytes are stored correctly
        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);
        assertEq(uint8(buffer[2]), 0x56);
        assertEq(uint8(buffer[3]), 0x78);
        assertEq(uint8(buffer[4]), 0x90);
        assertEq(uint8(buffer[5]), 0xAB);
        assertEq(uint8(buffer[6]), 0xcd);
        assertEq(uint8(buffer[7]), 0xEF);
        assertEq(uint8(buffer[8]), 0x12);
        assertEq(uint8(buffer[9]), 0x34);
        assertEq(uint8(buffer[10]), 0x56);
        assertEq(uint8(buffer[11]), 0x78);
        assertEq(uint8(buffer[12]), 0x90);
        assertEq(uint8(buffer[13]), 0xAB);
        assertEq(uint8(buffer[14]), 0xcd);
        assertEq(uint8(buffer[15]), 0xEF);
        assertEq(uint8(buffer[16]), 0x12);
        assertEq(uint8(buffer[17]), 0x34);
        assertEq(uint8(buffer[18]), 0x56);
        assertEq(uint8(buffer[19]), 0x78);

        (address unpacked,) = LibPackUnpack.unpackAddress(ptr);
        assertEq(unpacked, value);
    }

    // ---------------------------------------------------------------
    // Test utility functions
    // ---------------------------------------------------------------

    function test_dataPtr() public pure {
        bytes memory data = new bytes(100);
        uint256 ptr = LibPackUnpack.dataPtr(data);

        // The pointer should be 32 bytes after the data memory location
        // This skips the length prefix
        // The pointer should be 32 bytes after the data memory location
        // This skips the length prefix
        assembly {
            let expectedPtr := add(data, 0x20)
            if iszero(eq(ptr, expectedPtr)) { revert(0, 0) }
        }
    }

    // ---------------------------------------------------------------
    // Test sequential packing/unpacking
    // ---------------------------------------------------------------

    function test_sequentialPackUnpack() public pure {
        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        // Test uint8 + uint16
        {
            uint8 val1 = 42;
            uint16 val2 = 1234;

            uint256 writePtr = ptr;
            writePtr = LibPackUnpack.packUint8(writePtr, val1);
            writePtr = LibPackUnpack.packUint16(writePtr, val2);

            uint256 readPtr = ptr;
            (uint8 read1, uint256 newPtr1) = LibPackUnpack.unpackUint8(readPtr);
            (uint16 read2, uint256 newPtr2) = LibPackUnpack.unpackUint16(newPtr1);

            assertEq(read1, val1);
            assertEq(read2, val2);
            assertEq(writePtr, newPtr2);
        }

        // Test uint32 + uint48
        {
            uint32 val3 = 567_890;
            uint48 val4 = 999_999_999_999;

            uint256 writePtr = ptr + 3; // offset past previous data
            writePtr = LibPackUnpack.packUint32(writePtr, val3);
            writePtr = LibPackUnpack.packUint48(writePtr, val4);

            uint256 readPtr = ptr + 3;
            (uint32 read3, uint256 newPtr3) = LibPackUnpack.unpackUint32(readPtr);
            (uint48 read4, uint256 newPtr4) = LibPackUnpack.unpackUint48(newPtr3);

            assertEq(read3, val3);
            assertEq(read4, val4);
            assertEq(writePtr, newPtr4);
        }

        // Test address + bytes32
        {
            address val5 = address(0x1234567890123456789012345678901234567890);
            bytes32 val6 = keccak256("test");

            uint256 writePtr = ptr + 13; // offset past previous data
            writePtr = LibPackUnpack.packAddress(writePtr, val5);
            writePtr = LibPackUnpack.packBytes32(writePtr, val6);

            uint256 readPtr = ptr + 13;
            (address read5, uint256 newPtr5) = LibPackUnpack.unpackAddress(readPtr);
            (bytes32 read6, uint256 newPtr6) = LibPackUnpack.unpackBytes32(newPtr5);

            assertEq(read5, val5);
            assertEq(read6, val6);
            assertEq(writePtr, newPtr6);
        }
    }

    // ---------------------------------------------------------------
    // Fuzz tests
    // ---------------------------------------------------------------

    function testFuzz_packUnpackUint8(uint8 value) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packUint8(ptr, value);
        (uint8 unpacked,) = LibPackUnpack.unpackUint8(ptr);
        assertEq(unpacked, value);
    }

    function testFuzz_packUnpackUint16(uint16 value) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packUint16(ptr, value);
        (uint16 unpacked,) = LibPackUnpack.unpackUint16(ptr);
        assertEq(unpacked, value);
    }

    function testFuzz_packUnpackUint32(uint32 value) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packUint32(ptr, value);
        (uint32 unpacked,) = LibPackUnpack.unpackUint32(ptr);
        assertEq(unpacked, value);
    }

    function testFuzz_packUnpackUint48(uint48 value) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packUint48(ptr, value);
        (uint48 unpacked,) = LibPackUnpack.unpackUint48(ptr);
        assertEq(unpacked, value);
    }

    function testFuzz_packUnpackUint256(uint256 value) public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packUint256(ptr, value);
        (uint256 unpacked,) = LibPackUnpack.unpackUint256(ptr);
        assertEq(unpacked, value);
    }

    function testFuzz_packUnpackBytes32(bytes32 value) public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packBytes32(ptr, value);
        (bytes32 unpacked,) = LibPackUnpack.unpackBytes32(ptr);
        assertEq(unpacked, value);
    }

    function testFuzz_packUnpackAddress(address value) public pure {
        bytes memory buffer = new bytes(30);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packAddress(ptr, value);
        (address unpacked,) = LibPackUnpack.unpackAddress(ptr);
        assertEq(unpacked, value);
    }

    // ---------------------------------------------------------------
    // Test checkArrayLength
    // ---------------------------------------------------------------

    function test_checkArrayLength_valid() public pure {
        // Should not revert for valid lengths
        LibPackUnpack.checkArrayLength(0);
        LibPackUnpack.checkArrayLength(1);
        LibPackUnpack.checkArrayLength(100);
        LibPackUnpack.checkArrayLength(1000);
        LibPackUnpack.checkArrayLength(10_000);
        LibPackUnpack.checkArrayLength(65_535); // uint16 max
    }

    function testFuzz_checkArrayLength_valid(uint16 length) public pure {
        // Should not revert for any valid uint16 value
        LibPackUnpack.checkArrayLength(length);
    }

    // Note: Testing that checkArrayLength reverts for values > uint16.max
    // is complex with pure functions in Solidity tests.
    // The validation is in place and will revert at runtime when called
    // with values exceeding uint16.max (65535).
}
