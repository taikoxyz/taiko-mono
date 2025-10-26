// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "src/shared/signal/LibSignalServiceHash.sol";

contract LibSignalServiceHashTest is CommonTest {
    /// @notice Fuzz test to verify both functions produce identical results
    function testFuzz_HashConsistency(
        uint64 _chainId,
        address _app,
        bytes32 _signal
    )
        public
        pure
    {
        bytes32 originalHash = LibSignalServiceHash.hashOriginal(_chainId, _app, _signal);
        bytes32 optimizedHash = LibSignalServiceHash.hashOptimized(_chainId, _app, _signal);

        assertEq(
            originalHash,
            optimizedHash,
            "Hash mismatch: optimized version must produce same result as original"
        );
    }

    /// @notice Test with specific edge cases
    function test_HashEdgeCases() public pure {
        // Test with zero values
        bytes32 hash1Orig = LibSignalServiceHash.hashOriginal(0, address(0), bytes32(0));
        bytes32 hash1Opt = LibSignalServiceHash.hashOptimized(0, address(0), bytes32(0));
        assertEq(hash1Orig, hash1Opt, "Zero values mismatch");

        // Test with max values
        bytes32 hash2Orig =
            LibSignalServiceHash.hashOriginal(type(uint64).max, address(type(uint160).max), bytes32(type(uint256).max));
        bytes32 hash2Opt =
            LibSignalServiceHash.hashOptimized(type(uint64).max, address(type(uint160).max), bytes32(type(uint256).max));
        assertEq(hash2Orig, hash2Opt, "Max values mismatch");

        // Test with realistic values
        bytes32 hash3Orig =
            LibSignalServiceHash.hashOriginal(1, address(0x1234567890123456789012345678901234567890), keccak256("test"));
        bytes32 hash3Opt =
            LibSignalServiceHash.hashOptimized(1, address(0x1234567890123456789012345678901234567890), keccak256("test"));
        assertEq(hash3Orig, hash3Opt, "Realistic values mismatch");
    }

    /// @notice Gas comparison test
    function test_GasComparison() public {
        uint64 chainId = 167_000;
        address app = address(0x1234567890123456789012345678901234567890);
        bytes32 signal = keccak256("test signal");

        uint256 gasBefore = gasleft();
        LibSignalServiceHash.hashOriginal(chainId, app, signal);
        uint256 gasAfterOriginal = gasleft();
        uint256 gasUsedOriginal = gasBefore - gasAfterOriginal;

        gasBefore = gasleft();
        LibSignalServiceHash.hashOptimized(chainId, app, signal);
        uint256 gasAfterOptimized = gasleft();
        uint256 gasUsedOptimized = gasBefore - gasAfterOptimized;

        console.log("Gas used (original):", gasUsedOriginal);
        console.log("Gas used (optimized):", gasUsedOptimized);
        console.log("Gas saved:", gasUsedOriginal - gasUsedOptimized);

        // The optimized version should use less gas
        assertLt(gasUsedOptimized, gasUsedOriginal, "Optimized version should use less gas");
    }
}
