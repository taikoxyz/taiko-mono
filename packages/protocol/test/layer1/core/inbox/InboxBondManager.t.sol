// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { IBondManager } from "src/layer1/core/iface/IBondManager.sol";
import { LibBonds } from "src/layer1/core/libs/LibBonds.sol";

contract InboxBondManagerTest is InboxTestBase {
    function test_depositTo_creditsRecipient() public {
        uint64 amount = 5_000_000_000; // 5 tokens in gwei
        address depositor = Emma;
        address recipient = Alice;

        bondToken.mint(depositor, _toTokenAmount(amount));

        uint256 inboxBalanceBefore = bondToken.balanceOf(address(inbox));

        vm.startPrank(depositor);
        bondToken.approve(address(inbox), type(uint256).max);
        inbox.depositTo(recipient, amount);
        vm.stopPrank();

        assertEq(inbox.getBond(recipient).balance, amount, "recipient bond balance");
        assertEq(
            bondToken.balanceOf(address(inbox)),
            inboxBalanceBefore + _toTokenAmount(amount),
            "inbox token balance"
        );
    }

    function test_depositTo_RevertWhen_RecipientZero() public {
        uint64 amount = 1_000_000_000;

        bondToken.mint(Emma, _toTokenAmount(amount));

        vm.startPrank(Emma);
        bondToken.approve(address(inbox), type(uint256).max);
        vm.expectRevert(LibBonds.InvalidAddress.selector);
        inbox.depositTo(address(0), amount);
        vm.stopPrank();
    }

    function test_withdraw_RevertWhen_ToZero() public {
        vm.expectRevert(LibBonds.InvalidAddress.selector);
        vm.prank(proposer);
        inbox.withdraw(address(0), 1);
    }

    function test_withdraw_RevertWhen_DropsBelowMinBond() public {
        uint64 amount = LIVENESS_BOND_GWEI + 1;

        vm.startPrank(proposer);
        vm.expectRevert(LibBonds.MustMaintainMinBond.selector);
        inbox.withdraw(proposer, amount);
        vm.stopPrank();
    }

    function test_withdraw_AllowsAfterDelay() public {
        address account = David;
        uint64 balance = inbox.getBond(account).balance;

        uint256 inboxBalanceBefore = bondToken.balanceOf(address(inbox));
        uint256 accountBalanceBefore = bondToken.balanceOf(account);

        vm.startPrank(account);
        inbox.requestWithdrawal();
        uint48 requestedAt = inbox.getBond(account).withdrawalRequestedAt;
        assertGt(requestedAt, 0, "withdrawal requested");
        vm.warp(block.timestamp + config.withdrawalDelay + 1);
        inbox.withdraw(account, balance);
        vm.stopPrank();

        assertEq(inbox.getBond(account).balance, 0, "bond balance cleared");
        assertEq(
            inbox.getBond(account).withdrawalRequestedAt, 0, "withdrawal request cleared"
        );
        assertEq(
            bondToken.balanceOf(account),
            accountBalanceBefore + _toTokenAmount(balance),
            "account token balance"
        );
        assertEq(
            bondToken.balanceOf(address(inbox)),
            inboxBalanceBefore - _toTokenAmount(balance),
            "inbox token balance"
        );
    }

    function test_withdraw_PartialDoesNotClearWithdrawal() public {
        address account = David;
        uint64 balance = inbox.getBond(account).balance;
        uint64 amount = balance / 2;

        vm.startPrank(account);
        inbox.requestWithdrawal();
        uint48 requestedAt = inbox.getBond(account).withdrawalRequestedAt;
        assertGt(requestedAt, 0, "withdrawal requested");
        vm.warp(block.timestamp + config.withdrawalDelay + 1);
        inbox.withdraw(account, amount);
        vm.stopPrank();

        IBondManager.Bond memory bond = inbox.getBond(account);
        assertEq(bond.withdrawalRequestedAt, requestedAt, "withdrawal still pending");
        assertEq(bond.balance, balance - amount, "bond balance reduced");
    }

    function test_requestWithdrawal_RevertWhen_NoBond() public {
        vm.expectRevert(LibBonds.NoBondToWithdraw.selector);
        vm.prank(Emma);
        inbox.requestWithdrawal();
    }

    function test_requestWithdrawal_RevertWhen_AlreadyRequested() public {
        vm.prank(proposer);
        inbox.requestWithdrawal();

        vm.expectRevert(LibBonds.WithdrawalAlreadyRequested.selector);
        vm.prank(proposer);
        inbox.requestWithdrawal();
    }

    function test_cancelWithdrawal_RevertWhen_NoneRequested() public {
        vm.expectRevert(LibBonds.NoWithdrawalRequested.selector);
        vm.prank(proposer);
        inbox.cancelWithdrawal();
    }

    function test_requestWithdrawal_TogglesBondAvailability() public {
        vm.prank(proposer);
        inbox.requestWithdrawal();
        assertGt(inbox.getBond(proposer).withdrawalRequestedAt, 0, "bond disabled after request");

        vm.prank(proposer);
        inbox.cancelWithdrawal();
        assertEq(inbox.getBond(proposer).withdrawalRequestedAt, 0, "bond re-enabled after cancel");
    }

    function test_deposit_CancelsWithdrawal() public {
        uint64 amount = 1_000_000_000;

        vm.prank(proposer);
        inbox.requestWithdrawal();
        assertGt(inbox.getBond(proposer).withdrawalRequestedAt, 0, "withdrawal requested");
        uint64 balanceBefore = inbox.getBond(proposer).balance;

        bondToken.mint(proposer, _toTokenAmount(amount));

        vm.startPrank(proposer);
        bondToken.approve(address(inbox), type(uint256).max);
        inbox.deposit(amount);
        vm.stopPrank();

        IBondManager.Bond memory bond = inbox.getBond(proposer);
        assertEq(bond.withdrawalRequestedAt, 0, "withdrawal cleared");
        assertEq(bond.balance, balanceBefore + amount, "bond balance increased");
    }

    function test_depositTo_DoesNotCancelWithdrawal() public {
        uint64 amount = 1_000_000_000;

        vm.prank(proposer);
        inbox.requestWithdrawal();
        uint48 requestedAt = inbox.getBond(proposer).withdrawalRequestedAt;
        assertGt(requestedAt, 0, "withdrawal requested");
        uint64 balanceBefore = inbox.getBond(proposer).balance;

        bondToken.mint(Emma, _toTokenAmount(amount));

        vm.startPrank(Emma);
        bondToken.approve(address(inbox), type(uint256).max);
        inbox.depositTo(proposer, amount);
        vm.stopPrank();

        IBondManager.Bond memory bond = inbox.getBond(proposer);
        assertEq(bond.withdrawalRequestedAt, requestedAt, "withdrawal still pending");
        assertEq(bond.balance, balanceBefore + amount, "bond balance increased");
    }
}
