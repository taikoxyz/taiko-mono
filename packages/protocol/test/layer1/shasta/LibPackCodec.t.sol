// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibPackCodec } from "contracts/layer1/shasta/libs/LibPackCodec.sol";

/// @title LibPackCodecTest
/// @notice Comprehensive tests for LibPackCodec functions
/// @custom:security-contact security@taiko.xyz
contract LibPackCodecTest is Test {
    // ---------------------------------------------------------------
    // Test packUint8 / unpackUint8
    // ---------------------------------------------------------------
    
    function test_packUnpackUint8_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        // Pack value
        uint8 value = 0;
        uint256 newPtr = LibPackCodec.packUint8(buffer, ptr, value);
        assertEq(newPtr, ptr + 1);
        
        // Unpack value
        (uint8 unpacked, uint256 readPtr) = LibPackCodec.unpackUint8(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 1);
    }
    
    function test_packUnpackUint8_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        // Pack value
        uint8 value = type(uint8).max;
        uint256 newPtr = LibPackCodec.packUint8(buffer, ptr, value);
        assertEq(newPtr, ptr + 1);
        
        // Unpack value
        (uint8 unpacked, uint256 readPtr) = LibPackCodec.unpackUint8(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 1);
    }
    
    function test_packUnpackUint8_various() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint8[] memory testValues = new uint8[](5);
        testValues[0] = 0;
        testValues[1] = 1;
        testValues[2] = 127;
        testValues[3] = 128;
        testValues[4] = 255;
        
        for (uint256 i = 0; i < testValues.length; i++) {
            uint256 writePtr = ptr + i;
            uint256 newPtr = LibPackCodec.packUint8(buffer, writePtr, testValues[i]);
            assertEq(newPtr, writePtr + 1);
            
            (uint8 unpacked,) = LibPackCodec.unpackUint8(buffer, writePtr);
            assertEq(unpacked, testValues[i]);
        }
    }
    
    // ---------------------------------------------------------------
    // Test packUint16 / unpackUint16
    // ---------------------------------------------------------------
    
    function test_packUnpackUint16_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint16 value = 0;
        uint256 newPtr = LibPackCodec.packUint16(buffer, ptr, value);
        assertEq(newPtr, ptr + 2);
        
        (uint16 unpacked, uint256 readPtr) = LibPackCodec.unpackUint16(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 2);
    }
    
    function test_packUnpackUint16_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint16 value = type(uint16).max;
        uint256 newPtr = LibPackCodec.packUint16(buffer, ptr, value);
        assertEq(newPtr, ptr + 2);
        
        (uint16 unpacked, uint256 readPtr) = LibPackCodec.unpackUint16(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 2);
    }
    
    function test_packUnpackUint16_bigEndian() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint16 value = 0x1234; // Test big-endian encoding
        LibPackCodec.packUint16(buffer, ptr, value);
        
        // Check raw bytes are big-endian
        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);
        
        (uint16 unpacked,) = LibPackCodec.unpackUint16(buffer, ptr);
        assertEq(unpacked, value);
    }
    
    // ---------------------------------------------------------------
    // Test packUint32 / unpackUint32
    // ---------------------------------------------------------------
    
    function test_packUnpackUint32_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint32 value = 0;
        uint256 newPtr = LibPackCodec.packUint32(buffer, ptr, value);
        assertEq(newPtr, ptr + 4);
        
        (uint32 unpacked, uint256 readPtr) = LibPackCodec.unpackUint32(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 4);
    }
    
    function test_packUnpackUint32_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint32 value = type(uint32).max;
        uint256 newPtr = LibPackCodec.packUint32(buffer, ptr, value);
        assertEq(newPtr, ptr + 4);
        
        (uint32 unpacked, uint256 readPtr) = LibPackCodec.unpackUint32(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 4);
    }
    
    function test_packUnpackUint32_bigEndian() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint32 value = 0x12345678;
        LibPackCodec.packUint32(buffer, ptr, value);
        
        // Check raw bytes are big-endian
        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);
        assertEq(uint8(buffer[2]), 0x56);
        assertEq(uint8(buffer[3]), 0x78);
        
        (uint32 unpacked,) = LibPackCodec.unpackUint32(buffer, ptr);
        assertEq(unpacked, value);
    }
    
    // ---------------------------------------------------------------
    // Test packUint48 / unpackUint48
    // ---------------------------------------------------------------
    
    function test_packUnpackUint48_zero() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint48 value = 0;
        uint256 newPtr = LibPackCodec.packUint48(buffer, ptr, value);
        assertEq(newPtr, ptr + 6);
        
        (uint48 unpacked, uint256 readPtr) = LibPackCodec.unpackUint48(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 6);
    }
    
    function test_packUnpackUint48_max() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint48 value = type(uint48).max;
        uint256 newPtr = LibPackCodec.packUint48(buffer, ptr, value);
        assertEq(newPtr, ptr + 6);
        
        (uint48 unpacked, uint256 readPtr) = LibPackCodec.unpackUint48(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 6);
    }
    
    function test_packUnpackUint48_bigEndian() public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint48 value = 0x123456789ABC;
        LibPackCodec.packUint48(buffer, ptr, value);
        
        // Check raw bytes are big-endian
        assertEq(uint8(buffer[0]), 0x12);
        assertEq(uint8(buffer[1]), 0x34);
        assertEq(uint8(buffer[2]), 0x56);
        assertEq(uint8(buffer[3]), 0x78);
        assertEq(uint8(buffer[4]), 0x9A);
        assertEq(uint8(buffer[5]), 0xBC);
        
        (uint48 unpacked,) = LibPackCodec.unpackUint48(buffer, ptr);
        assertEq(unpacked, value);
    }
    
    // ---------------------------------------------------------------
    // Test packUint256 / unpackUint256
    // ---------------------------------------------------------------
    
    function test_packUnpackUint256_zero() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint256 value = 0;
        uint256 newPtr = LibPackCodec.packUint256(buffer, ptr, value);
        assertEq(newPtr, ptr + 32);
        
        (uint256 unpacked, uint256 readPtr) = LibPackCodec.unpackUint256(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 32);
    }
    
    function test_packUnpackUint256_max() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint256 value = type(uint256).max;
        uint256 newPtr = LibPackCodec.packUint256(buffer, ptr, value);
        assertEq(newPtr, ptr + 32);
        
        (uint256 unpacked, uint256 readPtr) = LibPackCodec.unpackUint256(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 32);
    }
    
    function test_packUnpackUint256_various() public pure {
        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        uint256[] memory testValues = new uint256[](3);
        testValues[0] = 1;
        testValues[1] = 0x123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF;
        testValues[2] = type(uint256).max - 1;
        
        uint256 currentPtr = ptr;
        for (uint256 i = 0; i < testValues.length; i++) {
            uint256 newPtr = LibPackCodec.packUint256(buffer, currentPtr, testValues[i]);
            assertEq(newPtr, currentPtr + 32);
            
            (uint256 unpacked,) = LibPackCodec.unpackUint256(buffer, currentPtr);
            assertEq(unpacked, testValues[i]);
            
            currentPtr = newPtr;
        }
    }
    
    // ---------------------------------------------------------------
    // Test packBytes32 / unpackBytes32
    // ---------------------------------------------------------------
    
    function test_packUnpackBytes32_zero() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        bytes32 value = bytes32(0);
        uint256 newPtr = LibPackCodec.packBytes32(buffer, ptr, value);
        assertEq(newPtr, ptr + 32);
        
        (bytes32 unpacked, uint256 readPtr) = LibPackCodec.unpackBytes32(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 32);
    }
    
    function test_packUnpackBytes32_max() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        bytes32 value = bytes32(type(uint256).max);
        uint256 newPtr = LibPackCodec.packBytes32(buffer, ptr, value);
        assertEq(newPtr, ptr + 32);
        
        (bytes32 unpacked, uint256 readPtr) = LibPackCodec.unpackBytes32(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 32);
    }
    
    function test_packUnpackBytes32_hash() public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        bytes32 value = keccak256("test data");
        uint256 newPtr = LibPackCodec.packBytes32(buffer, ptr, value);
        assertEq(newPtr, ptr + 32);
        
        (bytes32 unpacked, uint256 readPtr) = LibPackCodec.unpackBytes32(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 32);
    }
    
    // ---------------------------------------------------------------
    // Test packAddress / unpackAddress
    // ---------------------------------------------------------------
    
    function test_packUnpackAddress_zero() public pure {
        bytes memory buffer = new bytes(30);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        address value = address(0);
        uint256 newPtr = LibPackCodec.packAddress(buffer, ptr, value);
        assertEq(newPtr, ptr + 20);
        
        (address unpacked, uint256 readPtr) = LibPackCodec.unpackAddress(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 20);
    }
    
    function test_packUnpackAddress_max() public pure {
        bytes memory buffer = new bytes(30);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        address value = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        uint256 newPtr = LibPackCodec.packAddress(buffer, ptr, value);
        assertEq(newPtr, ptr + 20);
        
        (address unpacked, uint256 readPtr) = LibPackCodec.unpackAddress(buffer, ptr);
        assertEq(unpacked, value);
        assertEq(readPtr, ptr + 20);
    }
    
    function test_packUnpackAddress_various() public pure {
        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        address[] memory testAddresses = new address[](4);
        testAddresses[0] = address(0);
        testAddresses[1] = address(0x1234567890123456789012345678901234567890);
        testAddresses[2] = address(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
        testAddresses[3] = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        
        uint256 currentPtr = ptr;
        for (uint256 i = 0; i < testAddresses.length; i++) {
            uint256 newPtr = LibPackCodec.packAddress(buffer, currentPtr, testAddresses[i]);
            assertEq(newPtr, currentPtr + 20);
            
            (address unpacked,) = LibPackCodec.unpackAddress(buffer, currentPtr);
            assertEq(unpacked, testAddresses[i]);
            
            currentPtr = newPtr;
        }
    }
    
    function test_packUnpackAddress_bigEndian() public pure {
        bytes memory buffer = new bytes(30);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        address value = address(0x1234567890AbcdEF1234567890aBcdef12345678);
        LibPackCodec.packAddress(buffer, ptr, value);
        
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
        
        (address unpacked,) = LibPackCodec.unpackAddress(buffer, ptr);
        assertEq(unpacked, value);
    }
    
    // ---------------------------------------------------------------
    // Test utility functions
    // ---------------------------------------------------------------
    
    function test_dataPtr() public pure {
        bytes memory data = new bytes(100);
        uint256 ptr = LibPackCodec.dataPtr(data);
        
        // The pointer should be 32 bytes after the data memory location
        // This skips the length prefix
        // The pointer should be 32 bytes after the data memory location
        // This skips the length prefix
        assembly {
            let expectedPtr := add(data, 0x20)
            if iszero(eq(ptr, expectedPtr)) {
                revert(0, 0)
            }
        }
    }
    
    function test_calculateClaimRecordSize_zero() public pure {
        uint256 size = LibPackCodec.calculateClaimRecordSize(0);
        
        // Fixed size: 6 + 128 + 6 + 40 + 1 + 2 = 183 bytes
        uint256 expectedSize = 6 + 32 * 4 + 6 + 20 * 2 + 1 + 2;
        assertEq(size, expectedSize);
        assertEq(size, 183);
    }
    
    function test_calculateClaimRecordSize_withBondInstructions() public pure {
        uint256 size1 = LibPackCodec.calculateClaimRecordSize(1);
        uint256 expectedSize1 = 183 + 47; // Fixed + 1 bond instruction
        assertEq(size1, expectedSize1);
        
        uint256 size10 = LibPackCodec.calculateClaimRecordSize(10);
        uint256 expectedSize10 = 183 + 470; // Fixed + 10 bond instructions
        assertEq(size10, expectedSize10);
        
        uint256 size100 = LibPackCodec.calculateClaimRecordSize(100);
        uint256 expectedSize100 = 183 + 4700; // Fixed + 100 bond instructions
        assertEq(size100, expectedSize100);
    }
    
    // ---------------------------------------------------------------
    // Test sequential packing/unpacking
    // ---------------------------------------------------------------
    
    function test_sequentialPackUnpack() public pure {
        bytes memory buffer = new bytes(100);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        // Test uint8 + uint16
        {
            uint8 val1 = 42;
            uint16 val2 = 1234;
            
            uint256 writePtr = ptr;
            writePtr = LibPackCodec.packUint8(buffer, writePtr, val1);
            writePtr = LibPackCodec.packUint16(buffer, writePtr, val2);
            
            uint256 readPtr = ptr;
            (uint8 read1, uint256 newPtr1) = LibPackCodec.unpackUint8(buffer, readPtr);
            (uint16 read2, uint256 newPtr2) = LibPackCodec.unpackUint16(buffer, newPtr1);
            
            assertEq(read1, val1);
            assertEq(read2, val2);
            assertEq(writePtr, newPtr2);
        }
        
        // Test uint32 + uint48
        {
            uint32 val3 = 567890;
            uint48 val4 = 999999999999;
            
            uint256 writePtr = ptr + 3; // offset past previous data
            writePtr = LibPackCodec.packUint32(buffer, writePtr, val3);
            writePtr = LibPackCodec.packUint48(buffer, writePtr, val4);
            
            uint256 readPtr = ptr + 3;
            (uint32 read3, uint256 newPtr3) = LibPackCodec.unpackUint32(buffer, readPtr);
            (uint48 read4, uint256 newPtr4) = LibPackCodec.unpackUint48(buffer, newPtr3);
            
            assertEq(read3, val3);
            assertEq(read4, val4);
            assertEq(writePtr, newPtr4);
        }
        
        // Test address + bytes32
        {
            address val5 = address(0x1234567890123456789012345678901234567890);
            bytes32 val6 = keccak256("test");
            
            uint256 writePtr = ptr + 13; // offset past previous data
            writePtr = LibPackCodec.packAddress(buffer, writePtr, val5);
            writePtr = LibPackCodec.packBytes32(buffer, writePtr, val6);
            
            uint256 readPtr = ptr + 13;
            (address read5, uint256 newPtr5) = LibPackCodec.unpackAddress(buffer, readPtr);
            (bytes32 read6, uint256 newPtr6) = LibPackCodec.unpackBytes32(buffer, newPtr5);
            
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
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        LibPackCodec.packUint8(buffer, ptr, value);
        (uint8 unpacked,) = LibPackCodec.unpackUint8(buffer, ptr);
        assertEq(unpacked, value);
    }
    
    function testFuzz_packUnpackUint16(uint16 value) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        LibPackCodec.packUint16(buffer, ptr, value);
        (uint16 unpacked,) = LibPackCodec.unpackUint16(buffer, ptr);
        assertEq(unpacked, value);
    }
    
    function testFuzz_packUnpackUint32(uint32 value) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        LibPackCodec.packUint32(buffer, ptr, value);
        (uint32 unpacked,) = LibPackCodec.unpackUint32(buffer, ptr);
        assertEq(unpacked, value);
    }
    
    function testFuzz_packUnpackUint48(uint48 value) public pure {
        bytes memory buffer = new bytes(10);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        LibPackCodec.packUint48(buffer, ptr, value);
        (uint48 unpacked,) = LibPackCodec.unpackUint48(buffer, ptr);
        assertEq(unpacked, value);
    }
    
    function testFuzz_packUnpackUint256(uint256 value) public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        LibPackCodec.packUint256(buffer, ptr, value);
        (uint256 unpacked,) = LibPackCodec.unpackUint256(buffer, ptr);
        assertEq(unpacked, value);
    }
    
    function testFuzz_packUnpackBytes32(bytes32 value) public pure {
        bytes memory buffer = new bytes(40);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        LibPackCodec.packBytes32(buffer, ptr, value);
        (bytes32 unpacked,) = LibPackCodec.unpackBytes32(buffer, ptr);
        assertEq(unpacked, value);
    }
    
    function testFuzz_packUnpackAddress(address value) public pure {
        bytes memory buffer = new bytes(30);
        uint256 ptr = LibPackCodec.dataPtr(buffer);
        
        LibPackCodec.packAddress(buffer, ptr, value);
        (address unpacked,) = LibPackCodec.unpackAddress(buffer, ptr);
        assertEq(unpacked, value);
    }
}