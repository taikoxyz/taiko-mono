// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
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
        vm.warp(block.timestamp + config.withdrawalDelay + 1);
        inbox.withdraw(account, balance);
        vm.stopPrank();

        assertEq(inbox.getBond(account).balance, 0, "bond balance cleared");
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

    function test_requestWithdrawal_TogglesBondAvailability() public {
        vm.prank(proposer);
        inbox.requestWithdrawal();
        assertFalse(inbox.hasSufficientBond(proposer), "bond disabled after request");

        vm.prank(proposer);
        inbox.cancelWithdrawal();
        assertTrue(inbox.hasSufficientBond(proposer), "bond re-enabled after cancel");
    }
}
