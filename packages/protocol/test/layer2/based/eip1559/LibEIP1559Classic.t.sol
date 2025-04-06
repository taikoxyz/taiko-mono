// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/layer2/Layer2Test.sol";
import "src/layer2/based/eip1559/LibEIP1559Classic.sol";

contract LibEIP1559SimpleTest is Layer2Test {
    // Test that base fee stays the same when gas used equals gas issuance
    function test_1559classic_baseFeeStaysSameWhenGasUsedEqualsIssuance() public pure {
        // Test parameters
        uint256 parentBaseFee = 1 gwei;
        uint8 adjustmentQuotient = 8; // A reasonable adjustment quotient
        uint32 gasPerSecond = 15_000_000; // 15M gas per second
        uint256 blockTime = 12; // 12 seconds, standard Ethereum block time

        // Calculate gas used to match issuance
        // gasIssuance = blockTime * gasPerSecond
        uint256 gasUsed = blockTime * gasPerSecond;

        // Calculate new base fee
        uint256 newBaseFee = LibEIP1559Classic.calculateBaseFee(
            parentBaseFee, gasUsed, adjustmentQuotient, gasPerSecond, blockTime
        );

        // Assert that the new base fee equals the parent base fee
        assertEq(
            newBaseFee,
            parentBaseFee,
            "Base fee should remain unchanged when gas used equals issuance"
        );
    }

    // Test with different parent base fees to ensure consistency
    function test_1559classic_baseFeeStaysSameWithDifferentBaseFees(uint256 parentBaseFee)
        public
        pure
    {
        // Bound the parent base fee to reasonable values
        parentBaseFee =
            bound(parentBaseFee, LibEIP1559Classic.MIN_BASE_FEE, LibEIP1559Classic.MAX_BASE_FEE);

        uint8 adjustmentQuotient = 8; // A reasonable adjustment quotient
        uint32 gasPerSecond = 15_000_000; // 15M gas per second
        uint256 blockTime = 12; // 12 seconds

        // Gas used equals issuance
        uint256 gasUsed = blockTime * gasPerSecond;

        uint256 newBaseFee = LibEIP1559Classic.calculateBaseFee(
            parentBaseFee, gasUsed, adjustmentQuotient, gasPerSecond, blockTime
        );

        assertEq(
            newBaseFee,
            parentBaseFee,
            "Base fee should remain unchanged regardless of initial base fee value"
        );
    }

    // Test with different block times (up to cap)
    function test_1559classic_baseFeeStaysSameWithDifferentBlockTimes(uint256 blockTime)
        public
        pure
    {
        // Bound block time to reasonable values up to cap
        blockTime = bound(blockTime, 1, LibEIP1559Classic.BLOCK_TIME_CALCULATION_CAP);

        uint256 parentBaseFee = 1 gwei;
        uint8 adjustmentQuotient = 8;
        uint32 gasPerSecond = 15_000_000;

        // Gas used equals issuance for the effective block time
        uint256 effectiveBlockTime = blockTime > LibEIP1559Classic.BLOCK_TIME_CALCULATION_CAP
            ? LibEIP1559Classic.BLOCK_TIME_CALCULATION_CAP
            : blockTime;
        uint256 gasUsed = effectiveBlockTime * gasPerSecond;

        uint256 newBaseFee = LibEIP1559Classic.calculateBaseFee(
            parentBaseFee, gasUsed, adjustmentQuotient, gasPerSecond, blockTime
        );

        assertEq(
            newBaseFee,
            parentBaseFee,
            "Base fee should remain unchanged with different block times when gas used equals issuance"
        );
    }
}
