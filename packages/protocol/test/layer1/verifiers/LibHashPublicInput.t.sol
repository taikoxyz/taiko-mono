// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/layer1/verifiers/libs/LibHashPublicInput.sol";

/// @title LibHashPublicInputTest
/// @notice Fuzz tests to verify equivalence and gas savings
contract LibHashPublicInputTest is Test {
    using LibHashPublicInput for *;

    function test_hashEquivalence() public pure {
        uint64 chainId = 1;
        address verifierContract = address(0x1234567890123456789012345678901234567890);
        bytes32 aggregatedProvingHash =
            0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd;
        address newInstance = address(0x0987654321098765432109876543210987654321);

        bytes32 original =
            LibHashPublicInput.hashOriginal(chainId, verifierContract, aggregatedProvingHash, newInstance);
        bytes32 optimized = LibHashPublicInput.hashOptimized(
            chainId, verifierContract, aggregatedProvingHash, newInstance
        );

        assertEq(original, optimized, "Hashes should match");
    }

    function testFuzz_hashEquivalence(
        uint64 chainId,
        address verifierContract,
        bytes32 aggregatedProvingHash,
        address newInstance
    )
        public
        pure
    {
        bytes32 original =
            LibHashPublicInput.hashOriginal(chainId, verifierContract, aggregatedProvingHash, newInstance);
        bytes32 optimized = LibHashPublicInput.hashOptimized(
            chainId, verifierContract, aggregatedProvingHash, newInstance
        );

        assertEq(original, optimized, "Fuzz: Hashes must always match");
    }

    function test_gasComparison() public {
        uint64 chainId = 1;
        address verifierContract = address(0x1234567890123456789012345678901234567890);
        bytes32 aggregatedProvingHash =
            0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd;
        address newInstance = address(0x0987654321098765432109876543210987654321);

        uint256 gasBefore = gasleft();
        LibHashPublicInput.hashOriginal(chainId, verifierContract, aggregatedProvingHash, newInstance);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        LibHashPublicInput.hashOptimized(
            chainId, verifierContract, aggregatedProvingHash, newInstance
        );
        uint256 gasOptimized = gasBefore - gasleft();

        emit log_named_uint("Original gas", gasOriginal);
        emit log_named_uint("Optimized gas", gasOptimized);
        emit log_named_uint("Gas saved", gasOriginal - gasOptimized);
        emit log_named_uint(
            "Savings %", gasOriginal > 0 ? ((gasOriginal - gasOptimized) * 100) / gasOriginal : 0
        );

        assertLt(gasOptimized, gasOriginal, "Optimized should use less gas");
    }
}
