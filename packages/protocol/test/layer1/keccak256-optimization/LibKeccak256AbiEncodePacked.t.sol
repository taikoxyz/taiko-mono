// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/layer1/libs/keccak256-optimization/LibKeccak256AbiEncodePacked.sol";

/// @title LibKeccak256AbiEncodePackedTest
/// @notice Fuzz tests to verify equivalence between original and optimized keccak256 implementations
contract LibKeccak256AbiEncodePackedTest is Test {
    using LibKeccak256AbiEncodePacked for *;

    /// @notice Test that both implementations produce identical results for random inputs
    function testFuzz_HashEquivalence(bytes32 input0, bytes32 input1) public pure {
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = input0;
        publicInputs[1] = input1;

        bytes32 hashOrigin = LibKeccak256AbiEncodePacked.hashOrigin(publicInputs);
        bytes32 hashOptimized = LibKeccak256AbiEncodePacked.hashOptimized(publicInputs);

        assertEq(hashOrigin, hashOptimized, "Hash mismatch between origin and optimized");
    }

    /// @notice Test with specific known values (SGX verifier use case)
    function test_HashEquivalence_KnownValues() public pure {
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = bytes32(uint256(uint160(address(0x1234567890123456789012345678901234567890))));
        publicInputs[1] = keccak256(
            abi.encode("VERIFY_PROOF", uint64(167_000), address(0x5678), bytes32(uint256(12_345)), address(0))
        );

        bytes32 hashOrigin = LibKeccak256AbiEncodePacked.hashOrigin(publicInputs);
        bytes32 hashOptimized = LibKeccak256AbiEncodePacked.hashOptimized(publicInputs);

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for known values");
    }

    /// @notice Test with zero values
    function test_HashEquivalence_ZeroValues() public pure {
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = bytes32(0);
        publicInputs[1] = bytes32(0);

        bytes32 hashOrigin = LibKeccak256AbiEncodePacked.hashOrigin(publicInputs);
        bytes32 hashOptimized = LibKeccak256AbiEncodePacked.hashOptimized(publicInputs);

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for zero values");
    }

    /// @notice Test with max values
    function test_HashEquivalence_MaxValues() public pure {
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = bytes32(type(uint256).max);
        publicInputs[1] = bytes32(type(uint256).max);

        bytes32 hashOrigin = LibKeccak256AbiEncodePacked.hashOrigin(publicInputs);
        bytes32 hashOptimized = LibKeccak256AbiEncodePacked.hashOptimized(publicInputs);

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for max values");
    }

    /// @notice Test with empty array
    function test_HashEquivalence_EmptyArray() public pure {
        bytes32[] memory publicInputs = new bytes32[](0);

        bytes32 hashOrigin = LibKeccak256AbiEncodePacked.hashOrigin(publicInputs);
        bytes32 hashOptimized = LibKeccak256AbiEncodePacked.hashOptimized(publicInputs);

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for empty array");
    }

    /// @notice Test with single element
    function test_HashEquivalence_SingleElement() public pure {
        bytes32[] memory publicInputs = new bytes32[](1);
        publicInputs[0] = bytes32(uint256(12_345));

        bytes32 hashOrigin = LibKeccak256AbiEncodePacked.hashOrigin(publicInputs);
        bytes32 hashOptimized = LibKeccak256AbiEncodePacked.hashOptimized(publicInputs);

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for single element");
    }

    /// @notice Gas comparison test
    function test_GasComparison() public view {
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = bytes32(uint256(uint160(address(0x1234567890123456789012345678901234567890))));
        publicInputs[1] = keccak256(
            abi.encode("VERIFY_PROOF", uint64(167_000), address(0x5678), bytes32(uint256(12_345)), address(0))
        );

        uint256 gasStartOrigin = gasleft();
        LibKeccak256AbiEncodePacked.hashOrigin(publicInputs);
        uint256 gasUsedOrigin = gasStartOrigin - gasleft();

        uint256 gasStartOptimized = gasleft();
        LibKeccak256AbiEncodePacked.hashOptimized(publicInputs);
        uint256 gasUsedOptimized = gasStartOptimized - gasleft();

        console.log("Gas used (origin):", gasUsedOrigin);
        console.log("Gas used (optimized):", gasUsedOptimized);
        console.log("Gas saved:", gasUsedOrigin > gasUsedOptimized ? gasUsedOrigin - gasUsedOptimized : 0);
    }
}
