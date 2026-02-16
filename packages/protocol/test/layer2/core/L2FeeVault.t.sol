// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { IL2FeeVault } from "src/layer2/core/IL2FeeVault.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";

contract L2FeeVaultTest is Test {
    address private constant ANCHOR = address(0x1670);
    address private constant PROPOSER = address(0xB0B);
    address private constant RANDOM = address(0xBEEF);
    uint256 private constant BLOB_GAS_PER_BLOB = 131_072;

    L2FeeVault private vault;

    function setUp() external {
        L2FeeVault impl = new L2FeeVault(
            100 ether,  // targetBalanceWei
            100,        // minFeePerGasWei
            1_000_000,  // maxFeePerGasWei
            8_000       // lossReimbursementBps
        );

        vault = L2FeeVault(
            payable(
                address(
                    new ERC1967Proxy(
                        address(impl),
                        abi.encodeCall(L2FeeVault.init, (address(this), ANCHOR))
                    )
                )
            )
        );
    }

    function test_importProposalFee_revertWhenUnauthorized() external {
        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 10, 1, 2, 3, 1000);
        vm.expectRevert(abi.encodeWithSignature("ACCESS_DENIED()"));
        vm.prank(RANDOM);
        vault.importProposalFee(data);
    }

    function test_importProposalFee_updatesAccounting() external {
        uint256 l1Cost = _l1Cost(10, 1, 2, 3);
        IL2FeeVault.ProposalFeeData memory data =
            _singleFeeData(1, 10, 1, 2, 3, l1Cost + 1);

        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        assertEq(vault.claimable(PROPOSER), l1Cost, "claimable");
        assertEq(vault.totalLiabilities(), l1Cost, "liabilities");
    }

    function test_importProposalFee_partialWhenLoss() external {
        uint256 l1Cost = _l1Cost(10, 1, 2, 3);
        uint256 expected = (l1Cost * 8_000) / 10_000;

        IL2FeeVault.ProposalFeeData memory data =
            _singleFeeData(1, 10, 1, 2, 3, l1Cost - 1);

        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        assertEq(vault.claimable(PROPOSER), expected, "claimable");
    }

    function test_claim_transfersAndUpdatesLiabilities() external {
        uint256 l1Cost = _l1Cost(10, 1, 2, 3);
        IL2FeeVault.ProposalFeeData memory data =
            _singleFeeData(1, 10, 1, 2, 3, l1Cost + 1);

        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        vm.deal(address(vault), l1Cost);
        vm.startPrank(PROPOSER);
        uint256 balanceBefore = PROPOSER.balance;
        vault.claim(PROPOSER, 0);
        vm.stopPrank();

        assertEq(PROPOSER.balance, balanceBefore + l1Cost, "balance");
        assertEq(vault.claimable(PROPOSER), 0, "claimable");
        assertEq(vault.totalLiabilities(), 0, "liabilities");
    }

    function test_feePerGas_updatesWithDeficit() external {
        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 0, 0, 0, 0, 0);

        uint256 feeBefore = vault.feePerGasWei();
        vm.prank(ANCHOR);
        vault.importProposalFee(data);
        uint256 feeAfter = vault.feePerGasWei();

        assertGt(feeAfter, feeBefore, "fee increased");
    }

    // ---------------------------------------------------------------
    // EIP-1559 Style Fee Adjustment Tests
    // ---------------------------------------------------------------

    function test_feeAdjustment_100PercentDeficit() external {
        // At 100% deficit (broke), fee should increase by 12.5% (1/8)
        uint256 initialFee = vault.feePerGasWei();

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        uint256 newFee = vault.feePerGasWei();
        uint256 expectedIncrease = initialFee * 125 / 1000; // 12.5%

        assertApproxEqRel(newFee, initialFee + expectedIncrease, 0.01e18, "fee should increase by ~12.5%");
    }

    function test_feeAdjustment_50PercentDeficit() external {
        // At 50% deficit, fee should increase by 6.25% (1/16)
        // Fund vault to 50 ether (50% of 100 ether target)
        vm.deal(address(vault), 50 ether);

        uint256 initialFee = vault.feePerGasWei();

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        uint256 newFee = vault.feePerGasWei();
        uint256 expectedIncrease = initialFee * 625 / 10_000; // 6.25%

        assertApproxEqRel(newFee, initialFee + expectedIncrease, 0.01e18, "fee should increase by ~6.25%");
    }

    function test_feeAdjustment_atTarget() external {
        // At target balance, fee should not change
        vm.deal(address(vault), 100 ether);

        uint256 initialFee = vault.feePerGasWei();

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        uint256 newFee = vault.feePerGasWei();

        assertEq(newFee, initialFee, "fee should not change at target");
    }

    function test_feeAdjustment_50PercentSurplus() external {
        // At 50% surplus (150% of target), fee should decrease by 6.25%
        // First, get fee to a higher level by creating deficit
        for (uint48 i = 1; i <= 5; i++) {
            IL2FeeVault.ProposalFeeData memory deficitData = _singleFeeData(i, 0, 0, 0, 0, 0);
            vm.prank(ANCHOR);
            vault.importProposalFee(deficitData);
        }

        vm.deal(address(vault), 150 ether);
        uint256 initialFee = vault.feePerGasWei();

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(6, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        uint256 newFee = vault.feePerGasWei();
        uint256 expectedDecrease = initialFee * 625 / 10_000; // 6.25%

        assertApproxEqRel(newFee, initialFee - expectedDecrease, 0.01e18, "fee should decrease by ~6.25%");
    }

    function test_feeAdjustment_100PercentSurplus() external {
        // At 100% surplus (200% of target), fee should decrease by 12.5%
        // First, get fee to a higher level by creating deficit
        for (uint48 i = 1; i <= 5; i++) {
            IL2FeeVault.ProposalFeeData memory deficitData = _singleFeeData(i, 0, 0, 0, 0, 0);
            vm.prank(ANCHOR);
            vault.importProposalFee(deficitData);
        }

        vm.deal(address(vault), 200 ether);
        uint256 initialFee = vault.feePerGasWei();

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(6, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        uint256 newFee = vault.feePerGasWei();
        uint256 expectedDecrease = initialFee * 125 / 1000; // 12.5%

        assertApproxEqRel(newFee, initialFee - expectedDecrease, 0.01e18, "fee should decrease by ~12.5%");
    }

    function test_feeAdjustment_respectsMinBound() external {
        // Create a new vault with lower min bound for testing
        L2FeeVault impl = new L2FeeVault(
            100 ether,  // targetBalanceWei
            50,         // minFeePerGasWei (lower than default)
            1_000_000,  // maxFeePerGasWei
            8_000       // lossReimbursementBps
        );
        L2FeeVault testVault = L2FeeVault(
            payable(
                address(
                    new ERC1967Proxy(
                        address(impl),
                        abi.encodeCall(L2FeeVault.init, (address(this), ANCHOR))
                    )
                )
            )
        );

        // Create massive surplus to force fee below minimum
        vm.deal(address(testVault), 1000 ether);

        // Import multiple times to drive fee down
        for (uint48 i = 1; i <= 20; i++) {
            IL2FeeVault.ProposalFeeData memory data = _singleFeeData(i, 0, 0, 0, 0, 0);
            vm.prank(ANCHOR);
            testVault.importProposalFee(data);
        }

        assertEq(testVault.feePerGasWei(), 50, "fee should respect min bound");
    }

    function test_feeAdjustment_respectsMaxBound() external {
        // Create massive deficit to test max bound
        uint128 basefee = 50_000_000_000; // 50 gwei

        // Import profitable proposal that creates huge liability
        IL2FeeVault.ProposalFeeData memory data =
            _singleFeeData(1, 10_000_000, 1, basefee, 0, 501 ether);
        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        // Import many more to drive fee up to max
        // With 12.5% increase per iteration, need ~80 iterations to go from 100 to 1,000,000
        for (uint48 i = 2; i <= 100; i++) {
            IL2FeeVault.ProposalFeeData memory data2 = _singleFeeData(i, 0, 0, 0, 0, 0);
            vm.prank(ANCHOR);
            vault.importProposalFee(data2);
        }

        assertEq(vault.feePerGasWei(), 1_000_000, "fee should respect max bound");
    }

    function test_feeAdjustment_withLiabilities() external {
        // Test that liabilities are correctly subtracted from balance
        vm.deal(address(vault), 150 ether);

        // Create 50 ether liability (150 - 50 = 100, exactly at target)
        // l1Cost = gasUsed * basefee + numBlobs * BLOB_GAS_PER_BLOB * blobBasefee
        // 50 ether = 10_000_000 * 5000 gwei
        uint128 basefee = 5_000_000_000_000; // 5000 gwei
        IL2FeeVault.ProposalFeeData memory data1 =
            _singleFeeData(1, 10_000_000, 0, basefee, 0, 51 ether);

        uint256 initialFee = vault.feePerGasWei();

        vm.prank(ANCHOR);
        vault.importProposalFee(data1);

        // Effective balance = 150 - 50 = 100 (at target)
        // Fee should not change
        uint256 newFee = vault.feePerGasWei();
        assertEq(newFee, initialFee, "fee should not change when effective balance at target");
    }

    function test_feeAdjustment_convergesExponentially() external {
        // Test that fee converges toward equilibrium
        vm.deal(address(vault), 0);

        uint256[] memory fees = new uint256[](10);
        uint256[] memory deltas = new uint256[](9);

        for (uint48 i = 1; i <= 10; i++) {
            fees[i - 1] = vault.feePerGasWei();
            IL2FeeVault.ProposalFeeData memory data = _singleFeeData(i, 0, 0, 0, 0, 0);
            vm.prank(ANCHOR);
            vault.importProposalFee(data);

            if (i > 1) {
                deltas[i - 2] = fees[i - 1] - fees[i - 2];
            }
        }

        // Each delta should be approximately 12.5% of current fee (exponential)
        for (uint256 i = 1; i < deltas.length; i++) {
            assertGt(deltas[i], deltas[i - 1], "deltas should increase as fee increases");
        }
    }

    // ---------------------------------------------------------------
    // Edge Case Tests
    // ---------------------------------------------------------------

    function test_feeAdjustment_extremeSurplus_800Percent() external {
        // Test 800% surplus (errorRatio = -8, adjustmentFactor = 0)
        // This is the boundary where adjustmentFactor reaches 0
        // Create a vault with higher initial fee for testing
        L2FeeVault impl = new L2FeeVault(
            100 ether,  // targetBalanceWei
            10,         // minFeePerGasWei
            1_000_000,  // maxFeePerGasWei
            8_000       // lossReimbursementBps
        );
        L2FeeVault testVault = L2FeeVault(
            payable(
                address(
                    new ERC1967Proxy(
                        address(impl),
                        abi.encodeCall(L2FeeVault.init, (address(this), ANCHOR))
                    )
                )
            )
        );

        // First, increase fee significantly
        for (uint48 i = 1; i <= 10; i++) {
            IL2FeeVault.ProposalFeeData memory dataLoop = _singleFeeData(i, 0, 0, 0, 0, 0);
            vm.prank(ANCHOR);
            testVault.importProposalFee(dataLoop);
        }

        // Create 800% surplus: effective = 9 * target = 900 ether
        vm.deal(address(testVault), 900 ether);

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(11, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        testVault.importProposalFee(data);

        // With 800% surplus, adjustmentFactor = 0, so fee should drop to minFee
        assertEq(testVault.feePerGasWei(), 10, "fee should drop to minimum with 800% surplus");
    }

    function test_feeAdjustment_extremeSurplus_beyond800Percent() external {
        // Test >800% surplus (capped at -8e18 to prevent negative adjustmentFactor)
        L2FeeVault impl = new L2FeeVault(
            100 ether,  // targetBalanceWei
            10,         // minFeePerGasWei
            1_000_000,  // maxFeePerGasWei
            8_000       // lossReimbursementBps
        );
        L2FeeVault testVault = L2FeeVault(
            payable(
                address(
                    new ERC1967Proxy(
                        address(impl),
                        abi.encodeCall(L2FeeVault.init, (address(this), ANCHOR))
                    )
                )
            )
        );

        // First, increase fee significantly
        for (uint48 i = 1; i <= 10; i++) {
            IL2FeeVault.ProposalFeeData memory dataLoop = _singleFeeData(i, 0, 0, 0, 0, 0);
            vm.prank(ANCHOR);
            testVault.importProposalFee(dataLoop);
        }

        // Create 2000% surplus: effective = 21 * target = 2100 ether
        // This should be capped at -8e18, same as 800% surplus
        vm.deal(address(testVault), 2100 ether);

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(11, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        testVault.importProposalFee(data);

        // Even with massive surplus, fee should drop to minFee (not negative)
        assertEq(testVault.feePerGasWei(), 10, "fee should be clamped to minimum, not negative");
    }

    function test_feeAdjustment_zeroBalanceZeroLiabilities() external {
        // Test edge case: both balance and liabilities are 0
        // effective = 0, so 100% deficit
        uint256 initialFee = vault.feePerGasWei();

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        uint256 newFee = vault.feePerGasWei();
        uint256 expectedIncrease = initialFee * 125 / 1000; // 12.5%

        assertApproxEqRel(newFee, initialFee + expectedIncrease, 0.01e18, "100% deficit should increase fee by 12.5%");
    }

    function test_feeAdjustment_balanceEqualsLiabilities() external {
        // Test edge case: balance = liabilities, so effective = 0 (100% deficit)
        vm.deal(address(vault), 50 ether);

        // Create 50 ether liability
        uint128 basefee = 5_000_000_000_000; // 5000 gwei
        IL2FeeVault.ProposalFeeData memory data1 =
            _singleFeeData(1, 10_000_000, 0, basefee, 0, 51 ether);

        vm.prank(ANCHOR);
        vault.importProposalFee(data1);

        // Now balance = 50 ether, liabilities = 50 ether, effective = 0
        uint256 initialFee = vault.feePerGasWei();

        IL2FeeVault.ProposalFeeData memory data2 = _singleFeeData(2, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        vault.importProposalFee(data2);

        uint256 newFee = vault.feePerGasWei();
        uint256 expectedIncrease = initialFee * 125 / 1000; // 12.5%

        assertApproxEqRel(newFee, initialFee + expectedIncrease, 0.01e18, "0 effective balance should increase fee by 12.5%");
    }

    function test_feeAdjustment_feeStuckAtMin() external {
        // Test that fee at minFee doesn't change when surplus persists
        L2FeeVault impl = new L2FeeVault(
            100 ether,  // targetBalanceWei
            100,        // minFeePerGasWei
            1_000_000,  // maxFeePerGasWei
            8_000       // lossReimbursementBps
        );
        L2FeeVault testVault = L2FeeVault(
            payable(
                address(
                    new ERC1967Proxy(
                        address(impl),
                        abi.encodeCall(L2FeeVault.init, (address(this), ANCHOR))
                    )
                )
            )
        );

        // Fee starts at minFee (100)
        assertEq(testVault.feePerGasWei(), 100);

        // Create surplus to try to decrease fee
        vm.deal(address(testVault), 500 ether);

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        testVault.importProposalFee(data);

        // Fee should stay at minFee
        assertEq(testVault.feePerGasWei(), 100, "fee should stay at minimum");
    }

    function test_feeAdjustment_feeStuckAtMax() external {
        // Test that fee at maxFee doesn't change when deficit persists
        L2FeeVault impl = new L2FeeVault(
            100 ether,  // targetBalanceWei
            100,        // minFeePerGasWei
            1000,       // maxFeePerGasWei (low max for testing)
            8_000       // lossReimbursementBps
        );
        L2FeeVault testVault = L2FeeVault(
            payable(
                address(
                    new ERC1967Proxy(
                        address(impl),
                        abi.encodeCall(L2FeeVault.init, (address(this), ANCHOR))
                    )
                )
            )
        );

        // Increase fee to max through deficit
        for (uint48 i = 1; i <= 20; i++) {
            IL2FeeVault.ProposalFeeData memory dataLoop = _singleFeeData(i, 0, 0, 0, 0, 0);
            vm.prank(ANCHOR);
            testVault.importProposalFee(dataLoop);
        }

        assertEq(testVault.feePerGasWei(), 1000, "fee should reach maximum");

        // Try to increase further with more deficit
        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(21, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        testVault.importProposalFee(data);

        // Fee should stay at maxFee
        assertEq(testVault.feePerGasWei(), 1000, "fee should stay at maximum");
    }

    function test_feeAdjustment_smallFeeChanges() external {
        // Test that small deficits produce proportionally small fee changes
        vm.deal(address(vault), 99 ether); // 1% deficit

        uint256 initialFee = vault.feePerGasWei();

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        uint256 newFee = vault.feePerGasWei();

        // errorRatio = 1e18 / 100 = 0.01e18
        // adjustmentFactor = 1e18 + 0.01e18 / 8 = 1.00125e18
        // Expected increase: 0.125%
        uint256 expectedIncrease = initialFee * 125 / 100_000; // 0.125%

        assertApproxEqRel(newFee, initialFee + expectedIncrease, 0.01e18, "1% deficit should increase fee by ~0.125%");
    }

    function test_feeAdjustment_multipleSequentialImports() external {
        // Test fee evolution over multiple imports
        uint256[] memory fees = new uint256[](20);

        for (uint48 i = 1; i <= 20; i++) {
            fees[i - 1] = vault.feePerGasWei();
            IL2FeeVault.ProposalFeeData memory data = _singleFeeData(i, 0, 0, 0, 0, 0);
            vm.prank(ANCHOR);
            vault.importProposalFee(data);
        }

        // Verify each fee is higher than the previous (deficit scenario)
        for (uint256 i = 1; i < fees.length; i++) {
            uint256 currentFee = fees[i];
            uint256 previousFee = fees[i - 1];
            assertGt(currentFee, previousFee, "fee should monotonically increase with persistent deficit");

            // Verify approximately 12.5% increase each time
            uint256 increase = currentFee - previousFee;
            uint256 expectedIncrease = previousFee * 125 / 1000;
            assertApproxEqRel(increase, expectedIncrease, 0.01e18, "each increase should be ~12.5%");
        }
    }

    function test_feeAdjustment_claimReducesLiabilities() external {
        // Test that claims reduce liabilities and affect fee adjustment
        vm.deal(address(vault), 100 ether);

        // Create 50 ether liability
        uint128 basefee = 5_000_000_000_000; // 5000 gwei
        IL2FeeVault.ProposalFeeData memory data1 =
            _singleFeeData(1, 10_000_000, 0, basefee, 0, 51 ether);

        vm.prank(ANCHOR);
        vault.importProposalFee(data1);

        // effective = 100 - 50 = 50 (50% deficit)
        uint256 feeBeforeClaim = vault.feePerGasWei();

        // Claim half the liability
        vm.prank(PROPOSER);
        vault.claim(PROPOSER, 25 ether);

        // Now effective = 75 - 25 = 50 (still 50% deficit, same as before claim)
        IL2FeeVault.ProposalFeeData memory data2 = _singleFeeData(2, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        vault.importProposalFee(data2);

        uint256 feeAfterClaim = vault.feePerGasWei();

        // Fee change should be similar since effective balance ratio is the same
        assertApproxEqRel(feeAfterClaim, feeBeforeClaim * 10625 / 10000, 0.01e18, "fee should increase by ~6.25%");
    }

    function test_feeAdjustment_zeroTarget() external {
        // Test edge case: target = 0 should cause early return (no fee change)
        // This is a degenerate configuration but should be handled gracefully
        L2FeeVault impl = new L2FeeVault(
            0,          // targetBalanceWei = 0 (degenerate case)
            100,        // minFeePerGasWei
            1_000_000,  // maxFeePerGasWei
            8_000       // lossReimbursementBps
        );
        L2FeeVault testVault = L2FeeVault(
            payable(
                address(
                    new ERC1967Proxy(
                        address(impl),
                        abi.encodeCall(L2FeeVault.init, (address(this), ANCHOR))
                    )
                )
            )
        );

        uint256 initialFee = testVault.feePerGasWei();

        // Try to update fee with deficit
        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 0, 0, 0, 0, 0);
        vm.prank(ANCHOR);
        testVault.importProposalFee(data);

        // Fee should not change (early return in _updateFeePerGas)
        assertEq(testVault.feePerGasWei(), initialFee, "fee should not change when target is 0");
    }

    function _singleFeeData(
        uint48 _id,
        uint64 _gasUsed,
        uint32 _numBlobs,
        uint128 _basefee,
        uint128 _blobBasefee,
        uint256 _l2Revenue
    )
        private
        pure
        returns (IL2FeeVault.ProposalFeeData memory data_)
    {
        data_ = IL2FeeVault.ProposalFeeData({
            proposalId: _id,
            proposer: PROPOSER,
            l1GasUsed: _gasUsed,
            numBlobs: _numBlobs,
            l1Basefee: _basefee,
            l1BlobBasefee: _blobBasefee,
            l2BasefeeRevenue: _l2Revenue
        });
    }

    function _l1Cost(
        uint64 _gasUsed,
        uint32 _numBlobs,
        uint128 _basefee,
        uint128 _blobBasefee
    )
        private
        pure
        returns (uint256)
    {
        uint256 gasCost = uint256(_gasUsed) * uint256(_basefee);
        uint256 blobCost = uint256(_numBlobs) * BLOB_GAS_PER_BLOB * uint256(_blobBasefee);
        return gasCost + blobCost;
    }
}
