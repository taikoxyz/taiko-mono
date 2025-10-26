// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/layer1/libs/keccak256-optimization/LibKeccak256AbiEncode.sol";

/// @title LibKeccak256AbiEncodeTest
/// @notice Fuzz tests to verify equivalence between original and optimized keccak256 implementations
contract LibKeccak256AbiEncodeTest is Test {
    using LibKeccak256AbiEncode for *;

    /// @notice Test that both implementations produce identical results for random inputs
    function testFuzz_HashEquivalence(
        uint64 chainId,
        address verifierContract,
        bytes32 aggregatedProvingHash,
        address newInstance
    )
        public
        pure
    {
        string memory str = "VERIFY_PROOF";
        bytes32 hashOrigin = LibKeccak256AbiEncode.hashOrigin(
            str, chainId, verifierContract, aggregatedProvingHash, newInstance
        );
        bytes32 hashOptimized = LibKeccak256AbiEncode.hashOptimized(
            str, chainId, verifierContract, aggregatedProvingHash, newInstance
        );

        assertEq(hashOrigin, hashOptimized, "Hash mismatch between origin and optimized");
    }

    /// @notice Test with specific known values
    function test_HashEquivalence_KnownValues() public pure {
        string memory str = "VERIFY_PROOF";
        uint64 chainId = 167_000;
        address verifierContract = address(0x1234567890123456789012345678901234567890);
        bytes32 aggregatedProvingHash = bytes32(uint256(12_345));
        address newInstance = address(0);

        bytes32 hashOrigin = LibKeccak256AbiEncode.hashOrigin(
            str, chainId, verifierContract, aggregatedProvingHash, newInstance
        );
        bytes32 hashOptimized = LibKeccak256AbiEncode.hashOptimized(
            str, chainId, verifierContract, aggregatedProvingHash, newInstance
        );

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for known values");
    }

    /// @notice Test with zero values
    function test_HashEquivalence_ZeroValues() public pure {
        string memory str = "VERIFY_PROOF";
        uint64 chainId = 0;
        address verifierContract = address(0);
        bytes32 aggregatedProvingHash = bytes32(0);
        address newInstance = address(0);

        bytes32 hashOrigin = LibKeccak256AbiEncode.hashOrigin(
            str, chainId, verifierContract, aggregatedProvingHash, newInstance
        );
        bytes32 hashOptimized = LibKeccak256AbiEncode.hashOptimized(
            str, chainId, verifierContract, aggregatedProvingHash, newInstance
        );

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for zero values");
    }

    /// @notice Test with max values
    function test_HashEquivalence_MaxValues() public pure {
        string memory str = "VERIFY_PROOF";
        uint64 chainId = type(uint64).max;
        address verifierContract = address(type(uint160).max);
        bytes32 aggregatedProvingHash = bytes32(type(uint256).max);
        address newInstance = address(type(uint160).max);

        bytes32 hashOrigin = LibKeccak256AbiEncode.hashOrigin(
            str, chainId, verifierContract, aggregatedProvingHash, newInstance
        );
        bytes32 hashOptimized = LibKeccak256AbiEncode.hashOptimized(
            str, chainId, verifierContract, aggregatedProvingHash, newInstance
        );

        assertEq(hashOrigin, hashOptimized, "Hash mismatch for max values");
    }

    /// @notice Gas comparison test
    function test_GasComparison() public view {
        string memory str = "VERIFY_PROOF";
        uint64 chainId = 167_000;
        address verifierContract = address(0x1234567890123456789012345678901234567890);
        bytes32 aggregatedProvingHash = bytes32(uint256(12_345));
        address newInstance = address(0);

        uint256 gasStartOrigin = gasleft();
        LibKeccak256AbiEncode.hashOrigin(
            str, chainId, verifierContract, aggregatedProvingHash, newInstance
        );
        uint256 gasUsedOrigin = gasStartOrigin - gasleft();

        uint256 gasStartOptimized = gasleft();
        LibKeccak256AbiEncode.hashOptimized(
            str, chainId, verifierContract, aggregatedProvingHash, newInstance
        );
        uint256 gasUsedOptimized = gasStartOptimized - gasleft();

        console.log("Gas used (origin):", gasUsedOrigin);
        console.log("Gas used (optimized):", gasUsedOptimized);
        console.log("Gas saved:", gasUsedOrigin > gasUsedOptimized ? gasUsedOrigin - gasUsedOptimized : 0);
    }
}
