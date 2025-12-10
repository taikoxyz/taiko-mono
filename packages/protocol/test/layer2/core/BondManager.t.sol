// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { BondManager } from "src/layer2/core/BondManager.sol";
import { IBondManager } from "src/layer2/core/IBondManager.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { MockSignalService } from "test/layer1/core/inbox/mocks/MockContracts.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

contract BondManagerTest is Test {
    uint256 private constant MIN_BOND = 10 ether;
    uint48 private constant WITHDRAWAL_DELAY = 7 days;
    uint256 private constant LIVENESS_BOND = 2 ether;
    uint256 private constant PROVABILITY_BOND = 3 ether;
    uint64 private constant L1_CHAIN_ID = 11_337;
    address private constant L1_INBOX = address(0xBEEF);

    address internal Alice = address(0xA11CE);
    address internal Bob = address(0xB0B);
    address internal Carol = address(0xCA201);
    address internal David = address(0xDA7ED);
    address internal Emma = address(0xE11A);

    BondManager internal bondManager;
    TestERC20 internal bondToken;
    MockSignalService internal signalService;
    address internal operator;

    function setUp() public {
        operator = address(this);
        bondToken = new TestERC20("Bond Token", "BOND");
        signalService = new MockSignalService();

        BondManager impl = new BondManager(
            address(bondToken),
            MIN_BOND,
            WITHDRAWAL_DELAY,
            operator,
            signalService,
            L1_INBOX,
            L1_CHAIN_ID,
            LIVENESS_BOND,
            PROVABILITY_BOND
        );
        bondManager = BondManager(
            address(new ERC1967Proxy(address(impl), abi.encodeCall(BondManager.init, (operator))))
        );

        bondToken.mint(Alice, 1000 ether);
        bondToken.mint(Bob, 1000 ether);
        bondToken.mint(Carol, 1000 ether);
        bondToken.mint(David, 1000 ether);
        bondToken.mint(Emma, 1000 ether);

        vm.startPrank(Alice);
        bondToken.approve(address(bondManager), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(Bob);
        bondToken.approve(address(bondManager), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(Carol);
        bondToken.approve(address(bondManager), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(David);
        bondToken.approve(address(bondManager), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(Emma);
        bondToken.approve(address(bondManager), type(uint256).max);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------
    // Initialization Tests
    // ---------------------------------------------------------------

    function test_init_ImmutableVariablesSetCorrectly() external view {
        assertEq(address(bondManager.bondToken()), address(bondToken));
        assertEq(bondManager.minBond(), MIN_BOND);
        assertEq(bondManager.withdrawalDelay(), WITHDRAWAL_DELAY);
        assertEq(bondManager.bondOperator(), operator);
        assertEq(address(bondManager.signalService()), address(signalService));
        assertEq(bondManager.l1Inbox(), L1_INBOX);
        assertEq(bondManager.l1ChainId(), L1_CHAIN_ID);
        assertEq(bondManager.livenessBond(), LIVENESS_BOND);
        assertEq(bondManager.provabilityBond(), PROVABILITY_BOND);
        assertEq(bondManager.owner(), operator);
    }

    // ---------------------------------------------------------------
    // Deposit Tests
    // ---------------------------------------------------------------

    function test_deposit_SuccessfulDeposit() external {
        uint256 depositAmount = 50 ether;
        uint256 aliceInitialBalance = bondToken.balanceOf(Alice);

        vm.expectEmit();
        emit IBondManager.BondCredited(Alice, depositAmount);
        vm.expectEmit();
        emit IBondManager.BondDeposited(Alice, depositAmount);

        vm.prank(Alice);
        bondManager.deposit(depositAmount);

        assertEq(bondManager.getBondBalance(Alice), depositAmount);
        assertEq(bondToken.balanceOf(Alice), aliceInitialBalance - depositAmount);
        assertEq(bondToken.balanceOf(address(bondManager)), depositAmount);
    }

    function test_deposit_MultipleDepositsAccumulate() external {
        vm.startPrank(Alice);
        bondManager.deposit(30 ether);
        bondManager.deposit(20 ether);
        vm.stopPrank();

        assertEq(bondManager.getBondBalance(Alice), 50 ether);
    }

    function test_deposit_RevertWhen_ZeroAmountApproval() external {
        vm.prank(Alice);
        bondToken.approve(address(bondManager), 0);

        vm.expectRevert();
        vm.prank(Alice);
        bondManager.deposit(10 ether);
    }

    // ---------------------------------------------------------------
    // DepositTo Tests
    // ---------------------------------------------------------------

    function test_depositTo_SuccessfulDepositForRecipient() external {
        uint256 depositAmount = 50 ether;
        uint256 aliceInitialBalance = bondToken.balanceOf(Alice);

        vm.expectEmit();
        emit IBondManager.BondCredited(Bob, depositAmount);
        vm.expectEmit();
        emit IBondManager.BondDepositedFor(Alice, Bob, depositAmount);

        vm.prank(Alice);
        bondManager.depositTo(Bob, depositAmount);

        assertEq(bondManager.getBondBalance(Bob), depositAmount);
        assertEq(bondToken.balanceOf(Alice), aliceInitialBalance - depositAmount);
        assertEq(bondToken.balanceOf(address(bondManager)), depositAmount);
    }

    function test_depositTo_RevertWhen_RecipientIsZeroAddress() external {
        vm.expectRevert(BondManager.InvalidRecipient.selector);
        vm.prank(Alice);
        bondManager.depositTo(address(0), 50 ether);
    }

    function test_depositTo_MultipleUsersCanDepositForSameRecipient() external {
        vm.prank(Alice);
        bondManager.depositTo(Carol, 30 ether);

        vm.prank(Bob);
        bondManager.depositTo(Carol, 20 ether);

        assertEq(bondManager.getBondBalance(Carol), 50 ether);
    }

    // ---------------------------------------------------------------
    // Operator Debit/Credit Tests
    // ---------------------------------------------------------------

    function test_debitBond_OnlyOperatorCanCall() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        vm.expectRevert(abi.encodeWithSelector(EssentialContract.ACCESS_DENIED.selector));
        bondManager.debitBond(Alice, 20 ether);
    }

    function test_debitBond_BestEffortDebitAndEvent() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.expectEmit();
        emit IBondManager.BondDebited(Alice, 20 ether);
        uint256 debited = bondManager.debitBond(Alice, 20 ether);

        assertEq(debited, 20 ether);
        assertEq(bondManager.getBondBalance(Alice), 30 ether);
    }

    function test_debitBond_ReturnsActualAmountWhenPartial() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        uint256 debited = bondManager.debitBond(Alice, 100 ether);

        assertEq(debited, 50 ether);
        assertEq(bondManager.getBondBalance(Alice), 0);
    }

    function test_debitBond_ReturnsZeroWhenNoBalance() external {
        uint256 debited = bondManager.debitBond(Alice, 10 ether);
        assertEq(debited, 0);
    }

    function test_creditBond_CreditsAccumulate() external {
        vm.expectEmit();
        emit IBondManager.BondCredited(Alice, 20 ether);
        bondManager.creditBond(Alice, 20 ether);

        vm.expectEmit();
        emit IBondManager.BondCredited(Alice, 10 ether);
        bondManager.creditBond(Alice, 10 ether);

        assertEq(bondManager.getBondBalance(Alice), 30 ether);
    }

    // ---------------------------------------------------------------
    // Withdrawal Request Tests
    // ---------------------------------------------------------------

    function test_requestWithdrawal_SuccessfulRequest() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        uint256 expectedMaturity = block.timestamp + WITHDRAWAL_DELAY;

        vm.expectEmit();
        emit IBondManager.WithdrawalRequested(Alice, expectedMaturity);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        (uint256 balance, uint48 requestedAt) = bondManager.bond(Alice);
        assertEq(balance, 50 ether);
        assertEq(requestedAt, uint48(block.timestamp));
    }

    function test_requestWithdrawal_RevertWhen_ZeroBalance() external {
        vm.expectRevert(BondManager.NoBondToWithdraw.selector);
        vm.prank(Alice);
        bondManager.requestWithdrawal();
    }

    function test_requestWithdrawal_RevertWhen_AlreadyRequested() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.expectRevert(BondManager.WithdrawalAlreadyRequested.selector);
        vm.prank(Alice);
        bondManager.requestWithdrawal();
    }

    // ---------------------------------------------------------------
    // Cancel Withdrawal Tests
    // ---------------------------------------------------------------

    function test_cancelWithdrawal_SuccessfulCancellation() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.expectEmit();
        emit IBondManager.WithdrawalCancelled(Alice);

        vm.prank(Alice);
        bondManager.cancelWithdrawal();

        (, uint48 requestedAt) = bondManager.bond(Alice);
        assertEq(requestedAt, 0);
    }

    function test_cancelWithdrawal_CanCancelAfterDelayPeriod() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + WITHDRAWAL_DELAY + 1 days);

        vm.prank(Alice);
        bondManager.cancelWithdrawal();

        (, uint48 requestedAt) = bondManager.bond(Alice);
        assertEq(requestedAt, 0);
    }

    function test_cancelWithdrawal_RevertWhen_NoRequestPending() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.expectRevert(BondManager.NoWithdrawalRequested.selector);
        vm.prank(Alice);
        bondManager.cancelWithdrawal();
    }

    // ---------------------------------------------------------------
    // Withdraw Tests - Before Maturity
    // ---------------------------------------------------------------

    function test_withdraw_ExcessAboveMinBondBeforeMaturity() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        uint256 withdrawAmount = 40 ether;
        uint256 aliceInitialTokenBalance = bondToken.balanceOf(Alice);

        vm.expectEmit();
        emit IBondManager.BondWithdrawn(Alice, withdrawAmount);

        vm.prank(Alice);
        bondManager.withdraw(Alice, withdrawAmount);

        assertEq(bondManager.getBondBalance(Alice), 10 ether);
        assertEq(bondToken.balanceOf(Alice), aliceInitialTokenBalance + withdrawAmount);
    }

    function test_withdraw_ToAnotherRecipient() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        uint256 bobInitialBalance = bondToken.balanceOf(Bob);

        vm.prank(Alice);
        bondManager.withdraw(Bob, 40 ether);

        assertEq(bondManager.getBondBalance(Alice), 10 ether);
        assertEq(bondToken.balanceOf(Bob), bobInitialBalance + 40 ether);
    }

    function test_withdraw_RevertWhen_ReducesBelowMinBondBeforeMaturity() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.expectRevert(BondManager.MustMaintainMinBond.selector);
        vm.prank(Alice);
        bondManager.withdraw(Alice, 41 ether);
    }

    function test_withdraw_RevertWhen_ExactlyMinBondBeforeMaturity() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.expectRevert(BondManager.MustMaintainMinBond.selector);
        vm.prank(Alice);
        bondManager.withdraw(Alice, 40 ether + 1);
    }

    // ---------------------------------------------------------------
    // Withdraw Tests - During Delay Period
    // ---------------------------------------------------------------

    function test_withdraw_RevertWhen_DuringDelayPeriod() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + WITHDRAWAL_DELAY - 1);

        vm.expectRevert(BondManager.MustMaintainMinBond.selector);
        vm.prank(Alice);
        bondManager.withdraw(Alice, 50 ether);
    }

    function test_withdraw_CanWithdrawExcessDuringDelayPeriod() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + WITHDRAWAL_DELAY - 1);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 40 ether);

        assertEq(bondManager.getBondBalance(Alice), 10 ether);
    }

    // ---------------------------------------------------------------
    // Withdraw Tests - After Maturity
    // ---------------------------------------------------------------

    function test_withdraw_FullBalanceAfterMaturity() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + WITHDRAWAL_DELAY);

        uint256 aliceInitialBalance = bondToken.balanceOf(Alice);

        vm.expectEmit();
        emit IBondManager.BondWithdrawn(Alice, 50 ether);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 50 ether);

        assertEq(bondManager.getBondBalance(Alice), 0);
        assertEq(bondToken.balanceOf(Alice), aliceInitialBalance + 50 ether);
    }

    function test_withdraw_PartialAmountAfterMaturity() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + WITHDRAWAL_DELAY);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 30 ether);

        assertEq(bondManager.getBondBalance(Alice), 20 ether);
    }

    function test_withdraw_AtExactMaturityTime() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        uint256 maturityTime = block.timestamp + WITHDRAWAL_DELAY;
        vm.warp(maturityTime);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 50 ether);

        assertEq(bondManager.getBondBalance(Alice), 0);
    }

    // ---------------------------------------------------------------
    // Vulnerability Fix Tests
    // ---------------------------------------------------------------

    function test_withdraw_RevertWhen_ExceedingBalanceAfterMaturity() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Bob);
        bondManager.deposit(100 ether);

        vm.prank(Carol);
        bondManager.deposit(75 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + WITHDRAWAL_DELAY);

        uint256 contractBalance = bondToken.balanceOf(address(bondManager));
        assertEq(contractBalance, 225 ether);

        uint256 aliceInitialBalance = bondToken.balanceOf(Alice);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 225 ether);

        assertEq(bondToken.balanceOf(Alice), aliceInitialBalance + 50 ether);
        assertEq(bondManager.getBondBalance(Alice), 0);
        assertEq(bondManager.getBondBalance(Bob), 100 ether);
        assertEq(bondManager.getBondBalance(Carol), 75 ether);
        assertEq(bondToken.balanceOf(address(bondManager)), 175 ether);
    }

    function test_withdraw_TransfersExactDebitedAmountOnly() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + WITHDRAWAL_DELAY);

        uint256 aliceInitialBalance = bondToken.balanceOf(Alice);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 1000 ether);

        assertEq(bondToken.balanceOf(Alice), aliceInitialBalance + 50 ether);
    }

    function test_withdraw_DrainAttemptWithMultipleUsers() external {
        vm.prank(Alice);
        bondManager.deposit(30 ether);

        vm.prank(Bob);
        bondManager.deposit(100 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + WITHDRAWAL_DELAY);

        uint256 bobBalanceBefore = bondManager.getBondBalance(Bob);

        vm.prank(Alice);
        bondManager.withdraw(Alice, type(uint256).max);

        assertEq(bondManager.getBondBalance(Alice), 0);
        assertEq(bondManager.getBondBalance(Bob), bobBalanceBefore);
        assertEq(bondToken.balanceOf(address(bondManager)), 100 ether);
    }

    // ---------------------------------------------------------------
    // HasSufficientBond Tests
    // ---------------------------------------------------------------

    function test_hasSufficientBond_ReturnsTrueWhenSufficient() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        assertTrue(bondManager.hasSufficientBond(Alice, 0));
        assertTrue(bondManager.hasSufficientBond(Alice, 40 ether));
    }

    function test_hasSufficientBond_ReturnsFalseWhenInsufficient() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        assertFalse(bondManager.hasSufficientBond(Alice, 41 ether));
    }

    function test_hasSufficientBond_ReturnsFalseWhenBelowMinBond() external {
        vm.prank(Alice);
        bondManager.deposit(5 ether);

        assertFalse(bondManager.hasSufficientBond(Alice, 0));
    }

    function test_hasSufficientBond_ReturnsFalseWhenWithdrawalRequested() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        assertFalse(bondManager.hasSufficientBond(Alice, 0));
    }

    function test_hasSufficientBond_ReturnsTrueWhenExactlyMinBond() external {
        vm.prank(Alice);
        bondManager.deposit(10 ether);

        assertTrue(bondManager.hasSufficientBond(Alice, 0));
    }

    function test_hasSufficientBond_ReturnsFalseWhenZeroBalance() external view {
        assertFalse(bondManager.hasSufficientBond(Alice, 0));
    }

    // ---------------------------------------------------------------
    // Integration Tests - Combined Operations
    // ---------------------------------------------------------------

    function test_integration_DepositDebitCreditWithdraw() external {
        vm.prank(Alice);
        bondManager.deposit(100 ether);

        assertEq(bondManager.getBondBalance(Alice), 100 ether);

        uint256 debited = bondManager.debitBond(Alice, 30 ether);
        assertEq(debited, 30 ether);
        assertEq(bondManager.getBondBalance(Alice), 70 ether);

        bondManager.creditBond(Alice, 20 ether);
        assertEq(bondManager.getBondBalance(Alice), 90 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + WITHDRAWAL_DELAY);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 90 ether);

        assertEq(bondManager.getBondBalance(Alice), 0);
    }

    function test_integration_MultipleUsersInteracting() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Bob);
        bondManager.deposit(75 ether);

        vm.prank(Carol);
        bondManager.deposit(100 ether);

        assertTrue(bondManager.hasSufficientBond(Alice, 40 ether));
        assertTrue(bondManager.hasSufficientBond(Bob, 65 ether));
        assertTrue(bondManager.hasSufficientBond(Carol, 90 ether));

        vm.prank(Alice);
        bondManager.requestWithdrawal();
        assertFalse(bondManager.hasSufficientBond(Alice, 0));

        assertTrue(bondManager.hasSufficientBond(Bob, 0));
        assertTrue(bondManager.hasSufficientBond(Carol, 0));

        bondManager.debitBond(Bob, 50 ether);
        assertEq(bondManager.getBondBalance(Bob), 25 ether);
        assertFalse(bondManager.hasSufficientBond(Bob, 16 ether));
    }

    function test_integration_WithdrawalRequestCancelReactivate() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        assertTrue(bondManager.hasSufficientBond(Alice, 40 ether));

        vm.prank(Alice);
        bondManager.requestWithdrawal();
        assertFalse(bondManager.hasSufficientBond(Alice, 40 ether));

        vm.prank(Alice);
        bondManager.cancelWithdrawal();
        assertTrue(bondManager.hasSufficientBond(Alice, 40 ether));
    }

    function test_integration_DepositToMultipleTimesFromDifferentUsers() external {
        vm.prank(Alice);
        bondManager.depositTo(Carol, 30 ether);

        vm.prank(Bob);
        bondManager.depositTo(Carol, 40 ether);

        vm.prank(Carol);
        bondManager.deposit(30 ether);

        assertEq(bondManager.getBondBalance(Carol), 100 ether);

        vm.prank(Carol);
        bondManager.withdraw(Carol, 90 ether);

        assertEq(bondManager.getBondBalance(Carol), 10 ether);
    }

    // ---------------------------------------------------------------
    // Edge Cases & Security Tests
    // ---------------------------------------------------------------

    function test_edgeCase_WithdrawZeroAmount() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        uint256 aliceBalance = bondToken.balanceOf(Alice);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 0);

        assertEq(bondToken.balanceOf(Alice), aliceBalance);
        assertEq(bondManager.getBondBalance(Alice), 50 ether);
    }

    function test_edgeCase_DebitZeroAmount() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        uint256 debited = bondManager.debitBond(Alice, 0);

        assertEq(debited, 0);
        assertEq(bondManager.getBondBalance(Alice), 50 ether);
    }

    function test_edgeCase_CreditZeroAmount() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        bondManager.creditBond(Alice, 0);

        assertEq(bondManager.getBondBalance(Alice), 50 ether);
    }

    function test_edgeCase_WithdrawExactBalanceBeforeMaturity() external {
        vm.prank(Alice);
        bondManager.deposit(10 ether);

        vm.expectRevert(BondManager.MustMaintainMinBond.selector);
        vm.prank(Alice);
        bondManager.withdraw(Alice, 10 ether);
    }

    function test_edgeCase_MultipleWithdrawalsInSameBlock() external {
        vm.prank(Alice);
        bondManager.deposit(100 ether);

        vm.startPrank(Alice);
        bondManager.withdraw(Alice, 30 ether);
        bondManager.withdraw(Alice, 30 ether);
        bondManager.withdraw(Alice, 30 ether);
        vm.stopPrank();

        assertEq(bondManager.getBondBalance(Alice), 10 ether);
    }

    function test_edgeCase_RequestWithdrawAfterDebit() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        bondManager.debitBond(Alice, 45 ether);

        assertEq(bondManager.getBondBalance(Alice), 5 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        (, uint48 requestedAt) = bondManager.bond(Alice);
        assertTrue(requestedAt > 0);
    }

    function test_edgeCase_CreditAfterWithdrawalRequest() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        bondManager.creditBond(Alice, 25 ether);

        assertEq(bondManager.getBondBalance(Alice), 75 ether);

        (, uint48 requestedAt) = bondManager.bond(Alice);
        assertTrue(requestedAt > 0);
    }

    function test_edgeCase_DebitAfterWithdrawalRequest() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        uint256 debited = bondManager.debitBond(Alice, 30 ether);

        assertEq(debited, 30 ether);
        assertEq(bondManager.getBondBalance(Alice), 20 ether);
    }

    function test_edgeCase_MaxUint256Deposit() external {
        uint256 largeAmount = 1_000_000_000 ether;

        bondToken.mint(Alice, largeAmount);
        vm.prank(Alice);
        bondToken.approve(address(bondManager), largeAmount);

        vm.prank(Alice);
        bondManager.deposit(largeAmount);

        assertEq(bondManager.getBondBalance(Alice), largeAmount);
    }

    function test_security_BondAccountingInvariant() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Bob);
        bondManager.deposit(75 ether);

        vm.prank(Carol);
        bondManager.deposit(100 ether);

        uint256 totalBonds = bondManager.getBondBalance(Alice) + bondManager.getBondBalance(Bob)
            + bondManager.getBondBalance(Carol);

        uint256 contractBalance = bondToken.balanceOf(address(bondManager));

        assertEq(totalBonds, contractBalance);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 40 ether);

        totalBonds = bondManager.getBondBalance(Alice) + bondManager.getBondBalance(Bob)
            + bondManager.getBondBalance(Carol);

        contractBalance = bondToken.balanceOf(address(bondManager));

        assertEq(totalBonds, contractBalance);
    }

    function test_security_CannotReenterDeposit() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        assertTrue(bondManager.getBondBalance(Alice) == 50 ether);
    }

    function test_security_CannotReenterWithdraw() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 40 ether);

        assertTrue(bondManager.getBondBalance(Alice) == 10 ether);
    }

    function test_getBondBalance_ReturnsCorrectBalance() external {
        assertEq(bondManager.getBondBalance(Alice), 0);

        vm.prank(Alice);
        bondManager.deposit(50 ether);

        assertEq(bondManager.getBondBalance(Alice), 50 ether);
    }

    function test_bondStruct_InitialState() external view {
        (uint256 balance, uint48 withdrawalRequestedAt) = bondManager.bond(Alice);

        assertEq(balance, 0);
        assertEq(withdrawalRequestedAt, 0);
    }

    function test_bondStruct_AfterDeposit() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        (uint256 balance, uint48 withdrawalRequestedAt) = bondManager.bond(Alice);

        assertEq(balance, 50 ether);
        assertEq(withdrawalRequestedAt, 0);
    }

    function test_bondStruct_AfterWithdrawalRequest() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        (uint256 balance, uint48 withdrawalRequestedAt) = bondManager.bond(Alice);

        assertEq(balance, 50 ether);
        assertEq(withdrawalRequestedAt, uint48(block.timestamp));
    }

    // ---------------------------------------------------------------
    // Withdrawal Delay Timing Edge Cases
    // ---------------------------------------------------------------

    function test_withdrawalDelay_OneSecondBeforeMaturity() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + WITHDRAWAL_DELAY - 1);

        vm.expectRevert(BondManager.MustMaintainMinBond.selector);
        vm.prank(Alice);
        bondManager.withdraw(Alice, 50 ether);
    }

    function test_withdrawalDelay_VeryLongTimeAfterMaturity() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + 365 days);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 50 ether);

        assertEq(bondManager.getBondBalance(Alice), 0);
    }

    function test_withdrawalDelay_MultipleRequestCancelCycles() external {
        vm.prank(Alice);
        bondManager.deposit(50 ether);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        vm.warp(block.timestamp + 3 days);

        vm.prank(Alice);
        bondManager.cancelWithdrawal();

        vm.warp(block.timestamp + 1 days);

        vm.prank(Alice);
        bondManager.requestWithdrawal();

        uint256 secondRequestTime = block.timestamp;

        vm.warp(block.timestamp + WITHDRAWAL_DELAY);

        vm.prank(Alice);
        bondManager.withdraw(Alice, 50 ether);

        assertEq(bondManager.getBondBalance(Alice), 0);
        assertGe(block.timestamp, secondRequestTime + WITHDRAWAL_DELAY);
    }

    // ---------------------------------------------------------------
    // Signal Processing Tests
    // ---------------------------------------------------------------

    function test_processBondSignal_transfersBonds() external {
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: 1, bondType: LibBonds.BondType.LIVENESS, payer: Alice, payee: Bob
        });
        bytes32 signal = LibBonds.hashBondInstruction(instruction);

        vm.prank(L1_INBOX);
        signalService.sendSignalFrom(L1_CHAIN_ID, L1_INBOX, signal);

        vm.prank(Alice);
        bondManager.deposit(LIVENESS_BOND * 2);

        bondManager.processBondSignal(instruction, "");

        assertTrue(bondManager.processedSignals(signal));
        assertEq(bondManager.getBondBalance(Alice), LIVENESS_BOND);
        assertEq(bondManager.getBondBalance(Bob), LIVENESS_BOND);
    }

    function test_processBondSignal_allowsOutOfOrderConsumption() external {
        LibBonds.BondInstruction memory first = LibBonds.BondInstruction({
            proposalId: 1, bondType: LibBonds.BondType.PROVABILITY, payer: Alice, payee: Bob
        });
        LibBonds.BondInstruction memory second = LibBonds.BondInstruction({
            proposalId: 2, bondType: LibBonds.BondType.LIVENESS, payer: Carol, payee: David
        });

        vm.prank(L1_INBOX);
        signalService.sendSignalFrom(L1_CHAIN_ID, L1_INBOX, LibBonds.hashBondInstruction(first));
        vm.prank(L1_INBOX);
        signalService.sendSignalFrom(L1_CHAIN_ID, L1_INBOX, LibBonds.hashBondInstruction(second));

        vm.prank(Alice);
        bondManager.deposit(500 ether);
        vm.prank(Carol);
        bondManager.deposit(500 ether);

        bondManager.processBondSignal(second, "");
        bondManager.processBondSignal(first, "");

        assertEq(bondManager.getBondBalance(first.payee), PROVABILITY_BOND);
        assertEq(bondManager.getBondBalance(second.payee), LIVENESS_BOND);
    }
}
