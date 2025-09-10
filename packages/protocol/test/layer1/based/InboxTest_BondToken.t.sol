// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_BondToken is InboxTestBase {
    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_inbox_deposit_withdraw() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 transferAmount = 1234 ether;
        require(bondToken.transfer(Alice, transferAmount), "Transfer failed");
        assertEq(bondToken.balanceOf(Alice), transferAmount);

        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;

        vm.prank(Alice);
        bondToken.approve(address(inbox), depositAmount);

        vm.prank(Alice);
        inbox.v4DepositBond(depositAmount);
        assertEq(inbox.v4BondBalanceOf(Alice), depositAmount);

        vm.prank(Alice);
        inbox.v4WithdrawBond(withdrawAmount);
        assertEq(inbox.v4BondBalanceOf(Alice), depositAmount - withdrawAmount);
    }

    function test_inbox_withdraw_more_than_bond_balance() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 transferAmount = 10 ether;
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 2 ether;

        require(bondToken.transfer(Alice, transferAmount), "Transfer failed");

        vm.prank(Alice);
        bondToken.approve(address(inbox), depositAmount);

        vm.prank(Alice);
        inbox.v4DepositBond(depositAmount);

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.InsufficientBond.selector);
        inbox.v4WithdrawBond(withdrawAmount);
    }

    function test_inbox_insufficient_approval() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 transferAmount = 10 ether;
        uint256 insufficientApproval = 5 ether;
        uint256 depositAmount = 10 ether;

        require(bondToken.transfer(Alice, transferAmount), "Transfer failed");

        vm.prank(Alice);
        bondToken.approve(address(inbox), insufficientApproval);

        vm.prank(Alice);
        vm.expectRevert("ERC20: insufficient allowance");
        inbox.v4DepositBond(depositAmount);
    }

    function test_inbox_exceeding_token_balance() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 transferAmount = 10 ether;
        uint256 depositAmount = 12 ether;

        require(bondToken.transfer(Alice, transferAmount), "Transfer failed");

        vm.prank(Alice);
        bondToken.approve(address(inbox), depositAmount);

        vm.prank(Alice);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        inbox.v4DepositBond(depositAmount);
    }

    function test_inbox_no_value_sent_on_deposit() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 transferAmount = 10 ether;
        uint256 depositAmount = 1 ether;

        require(bondToken.transfer(Alice, transferAmount), "Transfer failed");

        vm.prank(Alice);
        bondToken.approve(address(inbox), depositAmount);

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.MsgValueNotZero.selector);
        inbox.v4DepositBond{ value: 1 }(depositAmount);
    }

    function test_inbox_deposit_and_withdraw_from_multiple_users() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);
        vm.deal(Bob, 50 ether);

        uint256 transferAmountAlice = 20 ether;
        uint256 transferAmountBob = 10 ether;

        // Transfer bond tokens to Alice and Bob
        require(bondToken.transfer(Alice, transferAmountAlice), "Transfer failed");
        assertEq(bondToken.balanceOf(Alice), transferAmountAlice);

        require(bondToken.transfer(Bob, transferAmountBob), "Transfer failed");
        assertEq(bondToken.balanceOf(Bob), transferAmountBob);

        uint256 aliceFirstDeposit = 2 ether;
        uint256 aliceSecondDeposit = 3 ether;
        uint256 aliceFirstWithdraw = 1 ether;
        uint256 aliceSecondWithdraw = 1.5 ether;

        uint256 bobDeposit = 5 ether;
        uint256 bobWithdraw = 2 ether;

        vm.prank(Alice);
        bondToken.approve(address(inbox), aliceFirstDeposit);

        vm.prank(Alice);
        inbox.v4DepositBond(aliceFirstDeposit);
        assertEq(inbox.v4BondBalanceOf(Alice), aliceFirstDeposit);

        vm.prank(Bob);
        bondToken.approve(address(inbox), bobDeposit);

        vm.prank(Bob);
        inbox.v4DepositBond(bobDeposit);
        assertEq(inbox.v4BondBalanceOf(Bob), bobDeposit);

        vm.prank(Alice);
        bondToken.approve(address(inbox), aliceSecondDeposit);

        vm.prank(Alice);
        inbox.v4DepositBond(aliceSecondDeposit);
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
