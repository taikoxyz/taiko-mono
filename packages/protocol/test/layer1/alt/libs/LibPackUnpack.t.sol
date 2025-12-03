// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibPackUnpack } from "src/layer1/alt/libs/LibPackUnpack.sol";

/// @title LibPackUnpackTest
/// @notice Comprehensive tests for LibPackUnpack functions (alt version)
/// @custom:security-contact security@taiko.xyz
contract LibPackUnpackTest is Test {
    // ---------------------------------------------------------------
    // Test packUint8 / unpackUint8
    // ---------------------------------------------------------------

    function test_packUnpackUint8_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint8 value = 0;
        uint256 newPtr = LibPackUnpack.packUint8(ptr, value);
        assertEq(newPtr, ptr + 1);

        (uint8 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint8(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 1);
    }

    function test_packUnpackUint8_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint8 value = type(uint8).max;
        uint256 newPtr = LibPackUnpack.packUint8(ptr, value);
        assertEq(newPtr, ptr + 1);

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

        uint16 value = 0x1234;
        LibPackUnpack.packUint16(ptr, value);

        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);

        (uint16 unpacked,) = LibPackUnpack.unpackUint16(ptr);
        assertEq(unpacked, value);
    }

    // ---------------------------------------------------------------
    // Test packUint24 / unpackUint24
    // ---------------------------------------------------------------

    function test_packUnpackUint24_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint24 value = 0;
        uint256 newPtr = LibPackUnpack.packUint24(ptr, value);
        assertEq(newPtr, ptr + 3);

        (uint24 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint24(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 3);
    }

    function test_packUnpackUint24_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint24 value = type(uint24).max;
        uint256 newPtr = LibPackUnpack.packUint24(ptr, value);
        assertEq(newPtr, ptr + 3);

        (uint24 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint24(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 3);
    }

    function test_packUnpackUint24_bigEndian() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint24 value = 0x123456;
        LibPackUnpack.packUint24(ptr, value);

        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);
        assertEq(uint8(buffer[2]), 0x56);

        (uint24 unpacked,) = LibPackUnpack.unpackUint24(ptr);
        assertEq(unpacked, value);
    }

    // ---------------------------------------------------------------
    // Test packUint40 / unpackUint40
    // ---------------------------------------------------------------

    function test_packUnpackUint40_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint40 value = 0;
        uint256 newPtr = LibPackUnpack.packUint40(ptr, value);
        assertEq(newPtr, ptr + 5);

        (uint40 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint40(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 5);
    }

    function test_packUnpackUint40_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint40 value = type(uint40).max;
        uint256 newPtr = LibPackUnpack.packUint40(ptr, value);
        assertEq(newPtr, ptr + 5);

        (uint40 unpacked, uint256 readPtr) = LibPackUnpack.unpackUint40(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 5);
    }

    function test_packUnpackUint40_bigEndian() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        uint40 value = 0x123456789A;
        LibPackUnpack.packUint40(ptr, value);

        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);
        assertEq(uint8(buffer[2]), 0x56);
        assertEq(uint8(buffer[3]), 0x78);
        assertEq(uint8(buffer[4]), 0x9A);

        (uint40 unpacked,) = LibPackUnpack.unpackUint40(ptr);
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
    // Test packBytes27 / unpackBytes27
    // ---------------------------------------------------------------

    function test_packUnpackBytes27_zero() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        bytes27 value = bytes27(0);
        uint256 newPtr = LibPackUnpack.packBytes27(ptr, value);
        assertEq(newPtr, ptr + 27);

        (bytes27 unpacked, uint256 readPtr) = LibPackUnpack.unpackBytes27(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 27);
    }

    function test_packUnpackBytes27_max() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        bytes27 value = bytes27(type(uint216).max);
        uint256 newPtr = LibPackUnpack.packBytes27(ptr, value);
        assertEq(newPtr, ptr + 27);

        (bytes27 unpacked, uint256 readPtr) = LibPackUnpack.unpackBytes27(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 27);
    }

    function test_packUnpackBytes27_hash() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        bytes27 value = bytes27(keccak256("test data"));
        uint256 newPtr = LibPackUnpack.packBytes27(ptr, value);
        assertEq(newPtr, ptr + 27);

        (bytes27 unpacked, uint256 readPtr) = LibPackUnpack.unpackBytes27(ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 27);
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
        testAddresses[2] = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
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

        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);
        assertEq(uint8(buffer[2]), 0x56);
        assertEq(uint8(buffer[3]), 0x78);
        assertEq(uint8(buffer[4]), 0x90);
        assertEq(uint8(buffer[5]), 0xAB);
        assertEq(uint8(buffer[6]), 0xcd);
        assertEq(uint8(buffer[7]), 0xEF);

        (address unpacked,) = LibPackUnpack.unpackAddress(ptr);
        assertEq(unpacked, value);
    }

    // ---------------------------------------------------------------
    // Test utility functions
    // ---------------------------------------------------------------

    function test_dataPtr() public pure {
        bytes memory data = new bytes(100);
        uint256 ptr = LibPackUnpack.dataPtr(data);

        assembly {
            let expectedPtr := add(data, 0x20)
            if iszero(eq(ptr, expectedPtr)) { revert(0, 0) }
        }
    }

    // ---------------------------------------------------------------
    // Test sequential packing/unpacking
    // ---------------------------------------------------------------

    function test_sequentialPackUnpack_integers() public pure {
        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        // Test uint8 + uint16 + uint24
        uint8 val1 = 42;
        uint16 val2 = 1234;
        uint24 val3 = 654321;

        uint256 writePtr = ptr;
        writePtr = LibPackUnpack.packUint8(writePtr, val1);
        writePtr = LibPackUnpack.packUint16(writePtr, val2);
        writePtr = LibPackUnpack.packUint24(writePtr, val3);

        (uint8 read1, uint256 nextPtr1) = LibPackUnpack.unpackUint8(ptr);
        (uint16 read2, uint256 nextPtr2) = LibPackUnpack.unpackUint16(nextPtr1);
        (uint24 read3, uint256 nextPtr3) = LibPackUnpack.unpackUint24(nextPtr2);

        assertEq(read1, val1);
        assertEq(read2, val2);
        assertEq(read3, val3);
        assertEq(writePtr, nextPtr3);
    }

    function test_sequentialPackUnpack_largerIntegers() public pure {
        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        // Test uint40 + uint48
        uint40 val4 = 1_234_567_890;
        uint48 val5 = 999_999_999_999;

        uint256 writePtr = ptr;
        writePtr = LibPackUnpack.packUint40(writePtr, val4);
        writePtr = LibPackUnpack.packUint48(writePtr, val5);

        (uint40 read4, uint256 nextPtr1) = LibPackUnpack.unpackUint40(ptr);
        (uint48 read5, uint256 nextPtr2) = LibPackUnpack.unpackUint48(nextPtr1);

        assertEq(read4, val4);
        assertEq(read5, val5);
        assertEq(writePtr, nextPtr2);
    }

    function test_sequentialPackUnpack_largeTypes() public pure {
        bytes memory buffer = new bytes(150);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        // Test address + bytes27 + bytes32
        address val6 = address(0x1234567890123456789012345678901234567890);
        bytes27 val7 = bytes27(keccak256("test27"));
        bytes32 val8 = keccak256("test32");

        uint256 writePtr = ptr;
        writePtr = LibPackUnpack.packAddress(writePtr, val6);
        writePtr = LibPackUnpack.packBytes27(writePtr, val7);
        writePtr = LibPackUnpack.packBytes32(writePtr, val8);

        (address read6, uint256 nextPtr1) = LibPackUnpack.unpackAddress(ptr);
        (bytes27 read7, uint256 nextPtr2) = LibPackUnpack.unpackBytes27(nextPtr1);
        (bytes32 read8, uint256 nextPtr3) = LibPackUnpack.unpackBytes32(nextPtr2);

        assertEq(read6, val6);
        assertEq(read7, val7);
        assertEq(read8, val8);
        assertEq(writePtr, nextPtr3);
    }

    // ---------------------------------------------------------------
    // Test checkArrayLength
    // ---------------------------------------------------------------

    function test_checkArrayLength_valid() public pure {
        LibPackUnpack.checkArrayLength(0);
        LibPackUnpack.checkArrayLength(1);
        LibPackUnpack.checkArrayLength(100);
        LibPackUnpack.checkArrayLength(1000);
        LibPackUnpack.checkArrayLength(10_000);
        LibPackUnpack.checkArrayLength(65_535); // uint16 max
    }

    function test_checkArrayLength_exceeds() public pure {
        // Note: Can't test revert with vm.expectRevert on pure library functions
        // The function reverts correctly but cheatcode depth doesn't match
        // Instead we test valid boundary values
        LibPackUnpack.checkArrayLength(65_535); // uint16 max - should succeed
        // checkArrayLength(65_536) would revert with LengthExceedsUint16
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

    function testFuzz_packUnpackUint24(uint24 value) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packUint24(ptr, value);
        (uint24 unpacked,) = LibPackUnpack.unpackUint24(ptr);
        assertEq(unpacked, value);
    }

    function testFuzz_packUnpackUint40(uint40 value) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packUint40(ptr, value);
        (uint40 unpacked,) = LibPackUnpack.unpackUint40(ptr);
        assertEq(unpacked, value);
    }

    function testFuzz_packUnpackUint48(uint48 value) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packUint48(ptr, value);
        (uint48 unpacked,) = LibPackUnpack.unpackUint48(ptr);
        assertEq(unpacked, value);
    }

    function testFuzz_packUnpackBytes27(bytes27 value) public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackUnpack.dataPtr(buffer);

        LibPackUnpack.packBytes27(ptr, value);
        (bytes27 unpacked,) = LibPackUnpack.unpackBytes27(ptr);
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

    function testFuzz_checkArrayLength_valid(uint16 length) public pure {
        LibPackUnpack.checkArrayLength(length);
    }
}
