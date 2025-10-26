// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/layer2/core/libs/LibHashProverAuth.sol";

/// @title LibHashProverAuthTest
/// @notice Fuzz tests to verify equivalence and gas savings
contract LibHashProverAuthTest is Test {
    using LibHashProverAuth for *;

    function test_hashEquivalence() public pure {
        uint48 proposalId = 12345;
        address proposer = address(0x1234567890123456789012345678901234567890);
        uint256 provingFee = 1 ether;

        bytes32 original = LibHashProverAuth.hashOriginal(proposalId, proposer, provingFee);
        bytes32 optimized = LibHashProverAuth.hashOptimized(proposalId, proposer, provingFee);

        assertEq(original, optimized, "Hashes should match");
    }

    function testFuzz_hashEquivalence(
        uint48 proposalId,
        address proposer,
        uint256 provingFee
    )
        public
        pure
    {
        bytes32 original = LibHashProverAuth.hashOriginal(proposalId, proposer, provingFee);
        bytes32 optimized = LibHashProverAuth.hashOptimized(proposalId, proposer, provingFee);

        assertEq(original, optimized, "Fuzz: Hashes must always match");
    }

    function test_gasComparison() public {
        uint48 proposalId = 12345;
        address proposer = address(0x1234567890123456789012345678901234567890);
        uint256 provingFee = 1 ether;

        uint256 gasBefore = gasleft();
        LibHashProverAuth.hashOriginal(proposalId, proposer, provingFee);
        uint256 gasOriginal = gasBefore - gasleft();

        gasBefore = gasleft();
        LibHashProverAuth.hashOptimized(proposalId, proposer, provingFee);
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
