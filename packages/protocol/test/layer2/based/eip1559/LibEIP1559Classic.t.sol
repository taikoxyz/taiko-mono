// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/layer2/Layer2Test.sol";
import "src/layer2/based/eip1559/LibEIP1559Classic.sol";

contract LibEIP1559ClassicWrapper {
    // Expose the calculateBaseFee function of LibEIP1559Classic so revert can be tested with new
    // Foundry release. See https://github.com/foundry-rs/foundry/issues/5367?utm_source=chatgpt.com
    function calculateBaseFee(
        uint256 _parentBasefee,
        uint64 _parentGasUsed,
        uint8 _adjustmentQuotient,
        uint32 _gasPerSeconds,
        uint256 _blockTime
    )
        external
        pure
        returns (uint256)
    {
        return LibEIP1559Classic.calculateBaseFee(
            _parentBasefee, _parentGasUsed, _adjustmentQuotient, _gasPerSeconds, _blockTime
        );
    }
}

contract LibEIP1559ClassicTest is Layer2Test {
    LibEIP1559ClassicWrapper private wrapper;

    function setUp() public override {
        super.setUp();
        wrapper = new LibEIP1559ClassicWrapper();
    }

    // Test that base fee stays the same when gas used equals gas issuance
    function test_1559classic_baseFeeStaysSameWhenGasUsedEqualsIssuance() public view {
        // Test parameters
        uint256 parentBaseFee = 1 gwei;
        uint8 adjustmentQuotient = 8; // A reasonable adjustment quotient
        uint32 gasPerSecond = 15_000_000; // 15M gas per second
        uint256 blockTime = 12; // 12 seconds, standard Ethereum block time

        // Calculate gas used to match issuance
        // gasIssuance = blockTime * gasPerSecond
        uint64 gasUsed = uint64(blockTime * gasPerSecond);

        // Calculate new base fee
        uint256 newBaseFee = wrapper.calculateBaseFee(
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
        view
    {
        // Bound the parent base fee to reasonable values
        parentBaseFee =
            bound(parentBaseFee, LibEIP1559Classic.MIN_BASE_FEE, LibEIP1559Classic.MAX_BASE_FEE);

        uint8 adjustmentQuotient = 8; // A reasonable adjustment quotient
        uint32 gasPerSecond = 15_000_000; // 15M gas per second
        uint256 blockTime = 12; // 12 seconds

        // Gas used equals issuance
        uint64 gasUsed = uint64(blockTime * gasPerSecond);

        uint256 newBaseFee = wrapper.calculateBaseFee(
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
        view
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
        uint64 gasUsed = uint64(effectiveBlockTime * gasPerSecond);

        uint256 newBaseFee = wrapper.calculateBaseFee(
            parentBaseFee, gasUsed, adjustmentQuotient, gasPerSecond, blockTime
        );

        assertEq(
            newBaseFee,
            parentBaseFee,
            "Base fee should remain unchanged with different block times when gas used equals issuance"
        );
    }

    function test_1559classic_calculateBaseFee_MaxInputs_ShouldNotRevert() public view {
        // Test with maximum possible values for each input
        uint256 parentBaseFee = LibEIP1559Classic.MAX_BASE_FEE;
        uint64 parentGasUsed = type(uint64).max;
        uint8 adjustmentQuotient = type(uint8).max; // 255
        uint32 gasPerSecond = type(uint32).max; // 4,294,967,295
        uint256 blockTime = LibEIP1559Classic.BLOCK_TIME_CALCULATION_CAP;

        // This should not revert
        uint256 newBaseFee = wrapper.calculateBaseFee(
            parentBaseFee, parentGasUsed, adjustmentQuotient, gasPerSecond, blockTime
        );

        // The result should be capped at MAX_BASE_FEE
        assertLe(newBaseFee, LibEIP1559Classic.MAX_BASE_FEE);
    }

    function test_1559classic_calculateBaseFee_MaxInputsCombinations() public view {
        // Test various combinations of max values

        // Test 1: Max parent base fee with normal other values
        uint256 newBaseFee1 = wrapper.calculateBaseFee(
            type(uint256).max, // parentBaseFee
            15_000_000 * 12, // normal gas used
            8, // normal adjustment quotient
            15_000_000, // normal gas per second
            12 // normal block time
        );
        assertLe(newBaseFee1, LibEIP1559Classic.MAX_BASE_FEE);

        // Test 2: Max gas used with normal other values
        uint256 newBaseFee2 = wrapper.calculateBaseFee(
            1 gwei, // normal parent base fee
            type(uint64).max, // parentGasUsed
            8, // normal adjustment quotient
            15_000_000, // normal gas per second
            12 // normal block time
        );
        assertLe(newBaseFee2, LibEIP1559Classic.MAX_BASE_FEE);

        // Test 3: Max adjustment quotient with normal other values
        uint256 newBaseFee3 = wrapper.calculateBaseFee(
            1 gwei, // normal parent base fee
            15_000_000 * 12, // normal gas used
            type(uint8).max, // max adjustment quotient
            15_000_000, // normal gas per second
            12 // normal block time
        );
        assertLe(newBaseFee3, LibEIP1559Classic.MAX_BASE_FEE);

        // Test 4: Max gas per second with normal other values
        uint256 newBaseFee4 = wrapper.calculateBaseFee(
            1 gwei, // normal parent base fee
            15_000_000 * 12, // normal gas used
            8, // normal adjustment quotient
            type(uint32).max, // max gas per second
            12 // normal block time
        );
        assertLe(newBaseFee4, LibEIP1559Classic.MAX_BASE_FEE);

        // Test 5: Max block time with normal other values
        uint256 newBaseFee5 = wrapper.calculateBaseFee(
            1 gwei, // normal parent base fee
            15_000_000 * 12, // normal gas used
            8, // normal adjustment quotient
            15_000_000, // normal gas per second
            type(uint256).max // max block time
        );
        assertLe(newBaseFee5, LibEIP1559Classic.MAX_BASE_FEE);
    }

    function test_1559classic_calculateBaseFee_MinInputs_ShouldNotRevert() public view {
        // Test with minimum valid values
        uint256 newBaseFee = wrapper.calculateBaseFee(
            LibEIP1559Classic.MIN_BASE_FEE, // minimum valid base fee
            1, // minimum gas used
            1, // minimum valid adjustment quotient
            1, // minimum valid gas per second
            1 // minimum valid block time
        );

        // Result should be at least MIN_BASE_FEE
        assertGe(newBaseFee, LibEIP1559Classic.MIN_BASE_FEE);
    }

    function test_1559classic_calculateBaseFee_ZeroBlockTime_ShouldRevert() public {
        // Test that zero block time reverts
        vm.expectRevert(LibEIP1559Classic.ZeroBlockTime.selector);
        wrapper.calculateBaseFee(
            1 gwei, // parent base fee
            15_000_000, // gas used
            8, // adjustment quotient
            15_000_000, // gas per second
            0 // zero block time - should revert
        );
    }

    function test_1559classic_calculateBaseFee_ZeroGasPerSecond_ShouldRevert() public {
        // Test that zero gas per second reverts
        vm.expectRevert(LibEIP1559Classic.ZeroGasPerSecond.selector);
        wrapper.calculateBaseFee(
            1 gwei, // parent base fee
            15_000_000, // gas used
            8, // adjustment quotient
            0, // zero gas per second - should revert
            12 // block time
        );
    }
}
