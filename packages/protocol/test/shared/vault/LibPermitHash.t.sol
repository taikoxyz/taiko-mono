// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "src/shared/vault/LibPermitHash.sol";

contract LibPermitHashTest is CommonTest {
    bytes32 private constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    /// @notice Fuzz test to verify both functions produce identical results
    function testFuzz_HashConsistency(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    )
        public
        pure
    {
        bytes32 originalHash =
            LibPermitHash.hashOriginal(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline);
        bytes32 optimizedHash =
            LibPermitHash.hashOptimized(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline);

        assertEq(
            originalHash,
            optimizedHash,
            "Hash mismatch: optimized version must produce same result as original"
        );
    }

    /// @notice Test with specific edge cases
    function test_HashEdgeCases() public {
        // Test with zero values
        bytes32 hash1Orig =
            LibPermitHash.hashOriginal(PERMIT_TYPEHASH, address(0), address(0), 0, 0, 0);
        bytes32 hash1Opt =
            LibPermitHash.hashOptimized(PERMIT_TYPEHASH, address(0), address(0), 0, 0, 0);
        assertEq(hash1Orig, hash1Opt, "Zero values mismatch");

        // Test with max values
        bytes32 hash2Orig = LibPermitHash.hashOriginal(
            bytes32(type(uint256).max),
            address(type(uint160).max),
            address(type(uint160).max),
            type(uint256).max,
            type(uint256).max,
            type(uint256).max
        );
        bytes32 hash2Opt = LibPermitHash.hashOptimized(
            bytes32(type(uint256).max),
            address(type(uint160).max),
            address(type(uint160).max),
            type(uint256).max,
            type(uint256).max,
            type(uint256).max
        );
        assertEq(hash2Orig, hash2Opt, "Max values mismatch");

        // Test with realistic values
        address owner = address(0x1234567890123456789012345678901234567890);
        address spender = address(0xabCDEF1234567890ABcDEF1234567890aBCDeF12);
        uint256 value = 1000 ether;
        uint256 nonce = 42;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 hash3Orig =
            LibPermitHash.hashOriginal(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline);
        bytes32 hash3Opt =
            LibPermitHash.hashOptimized(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline);
        assertEq(hash3Orig, hash3Opt, "Realistic values mismatch");
    }

    /// @notice Gas comparison test
    function test_GasComparison() public {
        address owner = address(0x1234567890123456789012345678901234567890);
        address spender = address(0xabCDEF1234567890ABcDEF1234567890aBCDeF12);
        uint256 value = 1000 ether;
        uint256 nonce = 42;
        uint256 deadline = block.timestamp + 1 hours;

        uint256 gasBefore = gasleft();
        LibPermitHash.hashOriginal(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline);
        uint256 gasAfterOriginal = gasleft();
        uint256 gasUsedOriginal = gasBefore - gasAfterOriginal;

        gasBefore = gasleft();
        LibPermitHash.hashOptimized(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline);
        uint256 gasAfterOptimized = gasleft();
        uint256 gasUsedOptimized = gasBefore - gasAfterOptimized;

        console.log("Gas used (original):", gasUsedOriginal);
        console.log("Gas used (optimized):", gasUsedOptimized);
        console.log("Gas saved:", gasUsedOriginal - gasUsedOptimized);

        // The optimized version should use less gas
        assertLt(gasUsedOptimized, gasUsedOriginal, "Optimized version should use less gas");
    }
}
