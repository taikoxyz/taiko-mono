// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ═══════════════════════════════════════════════════════════════════════
// DEPRECATED: This file is deprecated as of 2025-10-08.
// Please use the Shasta Inbox implementation instead.
// See: test/layer1/shasta/inbox/suite2/ for current tests
// ═══════════════════════════════════════════════════════════════════════

import "src/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_EtherAsBond is InboxTestBase {
    function v4GetConfig() internal pure override returns (ITaikoInbox.Config memory config_) {
        config_ = super.v4GetConfig();
        config_.livenessBond = 1 ether;
    }

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();

        // Use Ether as bond token
        bondToken = TaikoToken(address(0));
    }

    function test_inbox_deposit_withdraw() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;

        vm.prank(Alice);
        inbox.v4DepositBond{ value: depositAmount }(depositAmount);
        assertEq(inbox.v4BondBalanceOf(Alice), depositAmount);

        vm.prank(Alice);
        inbox.v4WithdrawBond(withdrawAmount);
        assertEq(inbox.v4BondBalanceOf(Alice), depositAmount - withdrawAmount);
    }

    function test_inbox_withdraw_more_than_bond_balance() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 2 ether;

        vm.prank(Alice);
        inbox.v4DepositBond{ value: depositAmount }(depositAmount);

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.InsufficientBond.selector);
        inbox.v4WithdrawBond(withdrawAmount);
    }

    // TODO: this test fail on Github but pass locally!
    // function test_inbox_exceeding_ether_balance() external {
    //     vm.warp(1_000_000);
    //     vm.deal(Alice, 0.5 ether);

    //     uint256 depositAmount = 1 ether;

    //     vm.prank(Alice);
    //     vm.expectRevert();
    //     inbox.DepositBond{ value: depositAmount }(depositAmount);
    // }

    function test_inbox_overpayment_of_ether() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 depositAmount = 1 ether;

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.EtherNotPaidAsBond.selector);
        inbox.v4DepositBond{ value: depositAmount + 1 }(depositAmount);
    }

    function test_inbox_eth_not_paid_as_bond_on_deposit() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 depositAmount = 1 ether;

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.EtherNotPaidAsBond.selector);
        inbox.v4DepositBond{ value: 0 }(depositAmount);
    }

    function test_inbox_bond_balance_after_multiple_operations() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);
        vm.deal(Bob, 50 ether);

        uint256 aliceFirstDeposit = 2 ether;
        uint256 aliceSecondDeposit = 3 ether;
        uint256 aliceFirstWithdraw = 1 ether;
        uint256 aliceSecondWithdraw = 1.5 ether;

        uint256 bobDeposit = 5 ether;
        uint256 bobWithdraw = 2 ether;

        vm.prank(Alice);
        inbox.v4DepositBond{ value: aliceFirstDeposit }(aliceFirstDeposit);
        assertEq(inbox.v4BondBalanceOf(Alice), aliceFirstDeposit);

        vm.prank(Bob);
        inbox.v4DepositBond{ value: bobDeposit }(bobDeposit);
        assertEq(inbox.v4BondBalanceOf(Bob), bobDeposit);

        vm.prank(Alice);
        inbox.v4DepositBond{ value: aliceSecondDeposit }(aliceSecondDeposit);
        assertEq(inbox.v4BondBalanceOf(Alice), aliceFirstDeposit + aliceSecondDeposit);

        vm.prank(Bob);
        inbox.v4WithdrawBond(bobWithdraw);
        assertEq(inbox.v4BondBalanceOf(Bob), bobDeposit - bobWithdraw);

        vm.prank(Alice);
        inbox.v4WithdrawBond(aliceFirstWithdraw);
        assertEq(
            inbox.v4BondBalanceOf(Alice),
            aliceFirstDeposit + aliceSecondDeposit - aliceFirstWithdraw
        );

        vm.prank(Alice);
        inbox.v4WithdrawBond(aliceSecondWithdraw);
        assertEq(
            inbox.v4BondBalanceOf(Alice),
            aliceFirstDeposit + aliceSecondDeposit - aliceFirstWithdraw - aliceSecondWithdraw
        );

        assertEq(
            inbox.v4BondBalanceOf(Alice),
            aliceFirstDeposit + aliceSecondDeposit - aliceFirstWithdraw - aliceSecondWithdraw
        );
        assertEq(inbox.v4BondBalanceOf(Bob), bobDeposit - bobWithdraw);
    }
}
