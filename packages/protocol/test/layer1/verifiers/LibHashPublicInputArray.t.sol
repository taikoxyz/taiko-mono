// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/layer1/verifiers/libs/LibHashPublicInputArray.sol";

/// @title LibHashPublicInputArrayTest
/// @notice Fuzz tests to verify equivalence and gas savings
contract LibHashPublicInputArrayTest is Test {
    using LibHashPublicInputArray for *;

    function test_hashEquivalence_twoElements() public pure {
        bytes32[] memory input = new bytes32[](2);
        input[0] = bytes32(uint256(uint160(address(0x1234))));
        input[1] = 0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd;

        bytes32 original = LibHashPublicInputArray.hashOriginal(input);
        bytes32 optimized = LibHashPublicInputArray.hashOptimized(input);

        assertEq(original, optimized, "Hashes should match for 2 elements");
    }

    function test_hashEquivalence_empty() public pure {
        bytes32[] memory input = new bytes32[](0);

        bytes32 original = LibHashPublicInputArray.hashOriginal(input);
        bytes32 optimized = LibHashPublicInputArray.hashOptimized(input);

        assertEq(original, optimized, "Hashes should match for empty array");
    }

    function testFuzz_hashEquivalence(bytes32[] memory input) public pure {
        vm.assume(input.length <= 100); // Reasonable limit

        bytes32 original = LibHashPublicInputArray.hashOriginal(input);
        bytes32 optimized = LibHashPublicInputArray.hashOptimized(input);

        assertEq(original, optimized, "Fuzz: Hashes must always match");
    }

    function test_gasComparison_twoElements() public {
        bytes32[] memory input = new bytes32[](2);
        input[0] = bytes32(uint256(uint160(address(0x1234))));
        input[1] = 0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd;

        uint256 gasBefore = gasleft();
        LibHashPublicInputArray.hashOriginal(input);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        LibHashPublicInputArray.hashOptimized(input);
        uint256 gasOptimized = gasBefore - gasleft();

        emit log_named_uint("Original gas (2 elements)", gasOriginal);
        emit log_named_uint("Optimized gas (2 elements)", gasOptimized);
        emit log_named_uint("Gas saved", gasOriginal - gasOptimized);
        emit log_named_uint(
            "Savings %", gasOriginal > 0 ? ((gasOriginal - gasOptimized) * 100) / gasOriginal : 0
        );

        assertLt(gasOptimized, gasOriginal, "Optimized should use less gas");
    }

    function test_gasComparison_fiveElements() public {
        bytes32[] memory input = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            input[i] = bytes32(i + 1);
        }

        uint256 gasBefore = gasleft();
        LibHashPublicInputArray.hashOriginal(input);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        LibHashPublicInputArray.hashOptimized(input);
        uint256 gasOptimized = gasBefore - gasleft();

        emit log_named_uint("Original gas (5 elements)", gasOriginal);
        emit log_named_uint("Optimized gas (5 elements)", gasOptimized);
        emit log_named_uint("Gas saved", gasOriginal - gasOptimized);
        emit log_named_uint(
            "Savings %", gasOriginal > 0 ? ((gasOriginal - gasOptimized) * 100) / gasOriginal : 0
        );

        assertLt(gasOptimized, gasOriginal, "Optimized should use less gas");
    }
}
