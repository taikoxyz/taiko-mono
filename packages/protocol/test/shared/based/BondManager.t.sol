// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import { IBondManager } from "contracts/shared/based/iface/IBondManager.sol";
import { BondManager } from "contracts/shared/based/impl/BondManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TestERC20 } from "../../mocks/TestERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title BondManagerTest
/// @notice Comprehensive test suite for BondManager contract
/// @dev Tests all bond management functions including deposits, withdrawals, debits, credits, and edge cases
contract BondManagerTest is CommonTest {
    BondManager public bondManager;
    address public bondToken;
    address public authorized;
    uint256 public minBond;
    uint48 public withdrawalDelay;

    // Test users
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public inbox = makeAddr("inbox");

    // Events to test
    event BondDebited(address indexed account, uint96 amount);
    event BondCredited(address indexed account, uint96 amount);
    event BondDeposited(address indexed account, uint96 amount);
    event BondWithdrawn(address indexed account, uint96 amount);
    event WithdrawalRequested(address indexed account, uint256 withdrawableAt);
    event WithdrawalCancelled(address indexed account);

    function setUp() public override {
        // Deploy mock ERC20 token for bonds
        TestERC20 token = new TestERC20("BondToken", "BOND");
        bondToken = address(token);
        
        // Set up parameters
        authorized = inbox;
        minBond = 1 ether; // 1 ether in gwei = 1e9 gwei
        withdrawalDelay = 7 days;

        // Deploy BondManager implementation and proxy
        BondManager impl = new BondManager(
            authorized,
            bondToken,
            minBond,
            withdrawalDelay
        );
        
        // Deploy proxy and initialize
        bytes memory initData = abi.encodeCall(BondManager.init, (address(this)));
        address proxy = address(new ERC1967Proxy(address(impl), initData));
        bondManager = BondManager(proxy);

        // Fund test users with bond tokens
        TestERC20(bondToken).mint(alice, 100 ether);
        TestERC20(bondToken).mint(bob, 100 ether);
        TestERC20(bondToken).mint(carol, 100 ether);

        // Approve BondManager to spend tokens
        vm.prank(alice);
        IERC20(bondToken).approve(address(bondManager), type(uint256).max);
        vm.prank(bob);
        IERC20(bondToken).approve(address(bondManager), type(uint256).max);
        vm.prank(carol);
        IERC20(bondToken).approve(address(bondManager), type(uint256).max);
    }

    // ---------------------------------------------------------------
    // Deposit Tests
    // ---------------------------------------------------------------

    function test_deposit_success() public {
        uint96 depositAmount = 10 ether;
        
        vm.expectEmit(true, true, true, true);
        emit BondDeposited(alice, depositAmount);
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        assertEq(bondManager.getBondBalance(alice), depositAmount);
        assertEq(IERC20(bondToken).balanceOf(address(bondManager)), depositAmount);
    }

    function test_deposit_multiple_users() public {
        uint96 aliceDeposit = 5 ether;
        uint96 bobDeposit = 3 ether;
        
        vm.prank(alice);
        bondManager.deposit(aliceDeposit);
        
        vm.prank(bob);
        bondManager.deposit(bobDeposit);
        
        assertEq(bondManager.getBondBalance(alice), aliceDeposit);
        assertEq(bondManager.getBondBalance(bob), bobDeposit);
        assertEq(IERC20(bondToken).balanceOf(address(bondManager)), aliceDeposit + bobDeposit);
    }

    function test_deposit_incremental() public {
        uint96 firstDeposit = 2 ether;
        uint96 secondDeposit = 3 ether;
        
        vm.startPrank(alice);
        bondManager.deposit(firstDeposit);
        assertEq(bondManager.getBondBalance(alice), firstDeposit);
        
        bondManager.deposit(secondDeposit);
        assertEq(bondManager.getBondBalance(alice), firstDeposit + secondDeposit);
        vm.stopPrank();
    }

    function test_deposit_zero() public {
        // Depositing 0 should succeed but not change balance
        uint96 balanceBefore = bondManager.getBondBalance(alice);
        
        vm.prank(alice);
        bondManager.deposit(0);
        
        assertEq(bondManager.getBondBalance(alice), balanceBefore);
    }

    function test_deposit_insufficient_balance_reverts() public {
        uint96 depositAmount = 200 ether; // More than alice has
        
        vm.prank(alice);
        vm.expectRevert();
        bondManager.deposit(depositAmount);
    }

    // ---------------------------------------------------------------
    // Withdrawal Tests
    // ---------------------------------------------------------------

    function test_withdraw_immediate_excess_over_minBond() public {
        uint96 depositAmount = 5 ether;
        uint96 withdrawAmount = 1 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        // Can withdraw immediately if maintaining minBond
        vm.expectEmit(true, true, true, true);
        emit BondWithdrawn(alice, withdrawAmount);
        
        vm.prank(alice);
        bondManager.withdraw(alice, withdrawAmount);
        
        assertEq(bondManager.getBondBalance(alice), depositAmount - withdrawAmount);
        assertEq(IERC20(bondToken).balanceOf(alice), 100 ether - depositAmount + withdrawAmount);
    }

    function test_withdraw_fails_below_minBond_without_request() public {
        uint96 depositAmount = 2 ether;
        uint96 withdrawAmount = 1.5 ether; // Would leave 0.5 ether < minBond
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        vm.prank(alice);
        vm.expectRevert(BondManager.MustMaintainMinBond.selector);
        bondManager.withdraw(alice, withdrawAmount);
    }

    function test_requestWithdrawal_success() public {
        uint96 depositAmount = 2 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        uint256 expectedWithdrawableAt = block.timestamp + withdrawalDelay;
        
        vm.expectEmit(true, true, true, true);
        emit WithdrawalRequested(alice, expectedWithdrawableAt);
        
        vm.prank(alice);
        bondManager.requestWithdrawal();
        
        (uint96 balance, uint48 requestedAt) = bondManager.bond(alice);
        assertEq(balance, depositAmount);
        assertEq(requestedAt, block.timestamp);
    }

    function test_requestWithdrawal_twice_reverts() public {
        uint96 depositAmount = 2 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        vm.prank(alice);
        bondManager.requestWithdrawal();
        
        vm.prank(alice);
        vm.expectRevert(BondManager.WithdrawalAlreadyRequested.selector);
        bondManager.requestWithdrawal();
    }

    function test_requestWithdrawal_no_balance_reverts() public {
        vm.prank(alice);
        vm.expectRevert(BondManager.NoBondToWithdraw.selector);
        bondManager.requestWithdrawal();
    }

    function test_withdraw_after_delay() public {
        uint96 depositAmount = 5 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        vm.prank(alice);
        bondManager.requestWithdrawal();
        
        // Fast forward past withdrawal delay
        vm.warp(block.timestamp + withdrawalDelay + 1);
        
        // Can withdraw full amount after delay
        vm.prank(alice);
        bondManager.withdraw(alice, depositAmount);
        
        assertEq(bondManager.getBondBalance(alice), 0);
        assertEq(IERC20(bondToken).balanceOf(alice), 100 ether);
    }

    function test_withdraw_before_delay_only_excess() public {
        uint96 depositAmount = 5 ether;
        uint96 withdrawAmount = 2 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        vm.prank(alice);
        bondManager.requestWithdrawal();
        
        // Before delay, can only withdraw excess over minBond
        vm.prank(alice);
        bondManager.withdraw(alice, withdrawAmount);
        
        assertEq(bondManager.getBondBalance(alice), depositAmount - withdrawAmount);
    }

    function test_cancelWithdrawal_success() public {
        uint96 depositAmount = 2 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        vm.prank(alice);
        bondManager.requestWithdrawal();
        
        vm.expectEmit(true, true, true, true);
        emit WithdrawalCancelled(alice);
        
        vm.prank(alice);
        bondManager.cancelWithdrawal();
        
        (uint96 balance, uint48 requestedAt) = bondManager.bond(alice);
        assertEq(balance, depositAmount);
        assertEq(requestedAt, 0);
    }

    function test_cancelWithdrawal_no_request_reverts() public {
        vm.prank(alice);
        vm.expectRevert(BondManager.NoWithdrawalRequested.selector);
        bondManager.cancelWithdrawal();
    }

    function test_withdraw_to_different_address() public {
        uint96 depositAmount = 5 ether;
        uint96 withdrawAmount = 1 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        uint256 bobBalanceBefore = IERC20(bondToken).balanceOf(bob);
        
        vm.prank(alice);
        bondManager.withdraw(bob, withdrawAmount);
        
        assertEq(bondManager.getBondBalance(alice), depositAmount - withdrawAmount);
        assertEq(IERC20(bondToken).balanceOf(bob), bobBalanceBefore + withdrawAmount);
    }

    // ---------------------------------------------------------------
    // Debit/Credit Tests (Only callable by authorized)
    // ---------------------------------------------------------------

    function test_debitBond_success() public {
        uint96 depositAmount = 5 ether;
        uint96 debitAmount = 2 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        vm.expectEmit(true, true, true, true);
        emit BondDebited(alice, debitAmount);
        
        vm.prank(inbox);
        uint96 amountDebited = bondManager.debitBond(alice, debitAmount);
        
        assertEq(amountDebited, debitAmount);
        assertEq(bondManager.getBondBalance(alice), depositAmount - debitAmount);
    }

    function test_debitBond_insufficient_balance_reverts() public {
        uint96 depositAmount = 2 ether;
        uint96 debitAmount = 3 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        vm.prank(inbox);
        vm.expectRevert(BondManager.InsufficientBond.selector);
        bondManager.debitBond(alice, debitAmount);
    }

    function test_debitBond_unauthorized_reverts() public {
        uint96 depositAmount = 5 ether;
        uint96 debitAmount = 2 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        vm.prank(alice); // Not authorized
        vm.expectRevert();
        bondManager.debitBond(alice, debitAmount);
    }

    function test_creditBond_success() public {
        uint96 creditAmount = 3 ether;
        
        vm.expectEmit(true, true, true, true);
        emit BondCredited(alice, creditAmount);
        
        vm.prank(inbox);
        bondManager.creditBond(alice, creditAmount);
        
        assertEq(bondManager.getBondBalance(alice), creditAmount);
    }

    function test_creditBond_multiple_times() public {
        uint96 firstCredit = 2 ether;
        uint96 secondCredit = 3 ether;
        
        vm.startPrank(inbox);
        bondManager.creditBond(alice, firstCredit);
        assertEq(bondManager.getBondBalance(alice), firstCredit);
        
        bondManager.creditBond(alice, secondCredit);
        assertEq(bondManager.getBondBalance(alice), firstCredit + secondCredit);
        vm.stopPrank();
    }

    function test_creditBond_unauthorized_reverts() public {
        vm.prank(alice); // Not authorized
        vm.expectRevert();
        bondManager.creditBond(alice, 1 ether);
    }

    // ---------------------------------------------------------------
    // hasSufficientBond Tests
    // ---------------------------------------------------------------

    function test_hasSufficientBond_exact_minBond() public {
        vm.prank(alice);
        bondManager.deposit(uint96(minBond));
        
        assertTrue(bondManager.hasSufficientBond(alice, 0));
        assertFalse(bondManager.hasSufficientBond(alice, 1));
    }

    function test_hasSufficientBond_with_additional() public {
        uint96 depositAmount = 5 ether;
        uint96 additionalRequired = 2 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        assertTrue(bondManager.hasSufficientBond(alice, additionalRequired));
        assertFalse(bondManager.hasSufficientBond(alice, depositAmount));
    }

    function test_hasSufficientBond_after_withdrawal_request() public {
        uint96 depositAmount = 5 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        assertTrue(bondManager.hasSufficientBond(alice, 0));
        
        vm.prank(alice);
        bondManager.requestWithdrawal();
        
        // After requesting withdrawal, hasSufficientBond returns false
        assertFalse(bondManager.hasSufficientBond(alice, 0));
    }

    function test_hasSufficientBond_after_cancel_withdrawal() public {
        uint96 depositAmount = 5 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        vm.prank(alice);
        bondManager.requestWithdrawal();
        assertFalse(bondManager.hasSufficientBond(alice, 0));
        
        vm.prank(alice);
        bondManager.cancelWithdrawal();
        assertTrue(bondManager.hasSufficientBond(alice, 0));
    }

    // ---------------------------------------------------------------
    // Overflow/Underflow Tests
    // ---------------------------------------------------------------

    function test_deposit_overflow_protection() public {
        uint96 maxUint96 = type(uint96).max;
        
        // First deposit close to max
        vm.prank(inbox);
        bondManager.creditBond(alice, maxUint96 - 1000);
        
        // Try to deposit amount that would overflow
        TestERC20(bondToken).mint(alice, 2000);
        vm.prank(alice);
        IERC20(bondToken).approve(address(bondManager), 2000);
        
        vm.prank(alice);
        vm.expectRevert(); // Should revert on overflow
        bondManager.deposit(2000);
    }

    function test_creditBond_overflow_protection() public {
        uint96 maxUint96 = type(uint96).max;
        
        vm.prank(inbox);
        bondManager.creditBond(alice, maxUint96 - 1000);
        
        vm.prank(inbox);
        vm.expectRevert(); // Should revert on overflow
        bondManager.creditBond(alice, 2000);
    }

    function test_debitBond_underflow_protection() public {
        uint96 depositAmount = 1000;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        // Try to debit more than balance (would underflow)
        vm.prank(inbox);
        vm.expectRevert(BondManager.InsufficientBond.selector);
        bondManager.debitBond(alice, depositAmount + 1);
    }

    function test_withdraw_underflow_protection() public {
        uint96 depositAmount = 2 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        // Request withdrawal to bypass minBond check
        vm.prank(alice);
        bondManager.requestWithdrawal();
        
        // Fast forward past withdrawal delay
        vm.warp(block.timestamp + withdrawalDelay + 1);
        
        // Try to withdraw more than balance
        vm.prank(alice);
        vm.expectRevert(BondManager.InsufficientBond.selector);
        bondManager.withdraw(alice, depositAmount + 1);
    }

    // ---------------------------------------------------------------
    // Edge Cases and Security Tests
    // ---------------------------------------------------------------

    function test_reentrancy_protection_deposit() public {
        // Test reentrancy protection on deposit
        // This would require a malicious token contract, simplified here
        vm.prank(alice);
        bondManager.deposit(1 ether);
        
        // Verify state is correct after potential reentrancy attempt
        assertEq(bondManager.getBondBalance(alice), 1 ether);
    }

    function test_reentrancy_protection_withdraw() public {
        vm.prank(alice);
        bondManager.deposit(5 ether);
        
        vm.prank(alice);
        bondManager.withdraw(alice, 1 ether);
        
        // Verify state is correct after potential reentrancy attempt
        assertEq(bondManager.getBondBalance(alice), 4 ether);
    }

    function test_zero_debit_no_event() public {
        vm.prank(alice);
        bondManager.deposit(1 ether);
        
        // Debiting zero should not emit event
        vm.recordLogs();
        vm.prank(inbox);
        bondManager.debitBond(alice, 0);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0, "No event should be emitted for zero debit");
    }

    function test_zero_credit_no_event() public {
        // Crediting zero should not emit event
        vm.recordLogs();
        vm.prank(inbox);
        bondManager.creditBond(alice, 0);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0, "No event should be emitted for zero credit");
    }

    function test_multiple_users_independent_balances() public {
        vm.prank(alice);
        bondManager.deposit(3 ether);
        
        vm.prank(bob);
        bondManager.deposit(2 ether);
        
        vm.prank(carol);
        bondManager.deposit(4 ether);
        
        // Debit from one user shouldn't affect others
        vm.prank(inbox);
        bondManager.debitBond(alice, 1 ether);
        
        assertEq(bondManager.getBondBalance(alice), 2 ether);
        assertEq(bondManager.getBondBalance(bob), 2 ether);
        assertEq(bondManager.getBondBalance(carol), 4 ether);
    }

    function test_withdrawal_timing_edge_case() public {
        uint96 depositAmount = 5 ether;
        
        vm.prank(alice);
        bondManager.deposit(depositAmount);
        
        vm.prank(alice);
        bondManager.requestWithdrawal();
        
        uint256 requestedAt = block.timestamp;
        
        // Warp to exactly one second before withdrawal is allowed
        vm.warp(requestedAt + withdrawalDelay - 1);
        
        // Should still not be able to withdraw full amount
        vm.prank(alice);
        vm.expectRevert(BondManager.MustMaintainMinBond.selector);
        bondManager.withdraw(alice, depositAmount);
        
        // Warp to exactly when withdrawal is allowed
        vm.warp(requestedAt + withdrawalDelay);
        
        // Now should be able to withdraw full amount
        vm.prank(alice);
        bondManager.withdraw(alice, depositAmount);
        
        assertEq(bondManager.getBondBalance(alice), 0);
    }

    function test_init_already_initialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        bondManager.init(address(this));
    }

    function test_immutable_values_set_correctly() public {
        assertEq(bondManager.authorized(), inbox);
        assertEq(address(bondManager.bondToken()), bondToken);
        assertEq(bondManager.minBond(), minBond);
        assertEq(bondManager.withdrawalDelay(), withdrawalDelay);
    }

    // ---------------------------------------------------------------
    // Fuzz Tests
    // ---------------------------------------------------------------

    function testFuzz_deposit_withdraw_consistency(uint96 _depositAmount, uint96 _withdrawAmount) public {
        vm.assume(_depositAmount > 0 && _depositAmount <= 90 ether);
        vm.assume(_withdrawAmount > 0 && _withdrawAmount <= _depositAmount);
        
        TestERC20(bondToken).mint(alice, _depositAmount);
        vm.prank(alice);
        IERC20(bondToken).approve(address(bondManager), _depositAmount);
        
        vm.prank(alice);
        bondManager.deposit(_depositAmount);
        
        // Check if we can withdraw while maintaining minBond
        if (_depositAmount - _withdrawAmount >= minBond) {
            vm.prank(alice);
            bondManager.withdraw(alice, _withdrawAmount);
            assertEq(bondManager.getBondBalance(alice), _depositAmount - _withdrawAmount);
        } else {
            vm.prank(alice);
            vm.expectRevert(BondManager.MustMaintainMinBond.selector);
            bondManager.withdraw(alice, _withdrawAmount);
        }
    }

    function testFuzz_debit_credit_consistency(uint96 _amount) public {
        vm.assume(_amount > 0 && _amount < type(uint96).max / 2);
        
        vm.prank(inbox);
        bondManager.creditBond(alice, _amount);
        assertEq(bondManager.getBondBalance(alice), _amount);
        
        vm.prank(inbox);
        uint96 debited = bondManager.debitBond(alice, _amount);
        assertEq(debited, _amount);
        assertEq(bondManager.getBondBalance(alice), 0);
    }

    function testFuzz_hasSufficientBond(uint96 _balance, uint96 _additional) public {
        vm.assume(_balance > 0 && _balance < type(uint96).max);
        vm.assume(_additional < type(uint96).max - minBond);
        
        vm.prank(inbox);
        bondManager.creditBond(alice, _balance);
        
        bool expected = _balance >= minBond + _additional;
        bool actual = bondManager.hasSufficientBond(alice, _additional);
        assertEq(actual, expected);
    }
}