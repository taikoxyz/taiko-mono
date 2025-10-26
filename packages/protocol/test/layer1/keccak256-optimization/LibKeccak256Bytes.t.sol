// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/layer1/libs/keccak256-optimization/LibKeccak256Bytes.sol";

/// @title LibKeccak256BytesTest
/// @notice Fuzz tests to verify equivalence between original and optimized keccak256 implementations
contract LibKeccak256BytesTest is Test {
    using LibKeccak256Bytes for *;

    /// @notice Test that both implementations produce identical results for random bytes
    function testFuzz_HashEquivalence(bytes memory data) public pure {
        bytes32 hashOrigin = LibKeccak256Bytes.hashOrigin(data);
        bytes32 hashOptimized = LibKeccak256Bytes.hashOptimized(data);

        assertEq(hashOrigin, hashOptimized, "Hash mismatch between origin and optimized");
    }

    /// @notice Test with empty bytes
    function test_HashEquivalence_Empty() public pure {
        bytes memory data = "";
        bytes32 hashOrigin = LibKeccak256Bytes.hashOrigin(data);
        bytes32 hashOptimized = LibKeccak256Bytes.hashOptimized(data);

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for empty bytes");
    }

    /// @notice Test with specific size bytes (32 bytes - common case)
    function test_HashEquivalence_32Bytes() public pure {
        bytes memory data = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            data[i] = bytes1(uint8(i));
        }

        bytes32 hashOrigin = LibKeccak256Bytes.hashOrigin(data);
        bytes32 hashOptimized = LibKeccak256Bytes.hashOptimized(data);

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for 32 bytes");
    }

    /// @notice Test with specific size bytes (65 bytes - public key size)
    function test_HashEquivalence_65Bytes() public pure {
        bytes memory data = new bytes(65);
        for (uint256 i = 0; i < 65; i++) {
            data[i] = bytes1(uint8(i));
        }

        bytes32 hashOrigin = LibKeccak256Bytes.hashOrigin(data);
        bytes32 hashOptimized = LibKeccak256Bytes.hashOptimized(data);

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for 65 bytes");
    }

    /// @notice Gas comparison test
    function test_GasComparison() public view {
        bytes memory data = new bytes(65);
        for (uint256 i = 0; i < 65; i++) {
            data[i] = bytes1(uint8(i));
        }

        uint256 gasStartOrigin = gasleft();
        LibKeccak256Bytes.hashOrigin(data);
        uint256 gasUsedOrigin = gasStartOrigin - gasleft();

        uint256 gasStartOptimized = gasleft();
        LibKeccak256Bytes.hashOptimized(data);
        uint256 gasUsedOptimized = gasStartOptimized - gasleft();

        console.log("Gas used (origin):", gasUsedOrigin);
        console.log("Gas used (optimized):", gasUsedOptimized);
        console.log("Gas saved:", gasUsedOrigin > gasUsedOptimized ? gasUsedOrigin - gasUsedOptimized : 0);
    }
}
