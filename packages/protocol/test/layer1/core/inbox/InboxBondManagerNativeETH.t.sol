// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { IBondManager } from "src/layer1/core/iface/IBondManager.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBonds } from "src/layer1/core/libs/LibBonds.sol";

contract InboxBondManagerNativeETHTest is InboxTestBase {
    /// @dev Override to use address(0) for native ETH bonds
    function _buildConfig() internal view override returns (IInbox.Config memory) {
        return IInbox.Config({
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            proverWhitelist: address(proverWhitelistContract),
            signalService: address(signalService),
            bondToken: address(0), // Native ETH
            minBond: MIN_BOND_GWEI,
            livenessBond: LIVENESS_BOND_GWEI,
            withdrawalDelay: WITHDRAWAL_DELAY,
            provingWindow: 2 hours,
            maxProofSubmissionDelay: 3 minutes,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 384,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            minCheckpointDelay: 60_000,
            permissionlessInclusionMultiplier: 5
        });
    }

    /// @dev Override to seed ETH bonds instead of ERC20
    function _seedBondBalances() internal override {
        uint64 initialBond = MIN_BOND_GWEI + LIVENESS_BOND_GWEI;

        vm.deal(proposer, 100 ether);
        vm.deal(prover, 100 ether);
        vm.deal(David, 100 ether);

        vm.prank(proposer);
        inbox.deposit{ value: _toTokenAmount(initialBond) }(initialBond);

        vm.prank(prover);
        inbox.deposit{ value: _toTokenAmount(initialBond) }(initialBond);

        vm.prank(David);
        inbox.deposit{ value: _toTokenAmount(initialBond) }(initialBond);
    }

    function test_depositTo_creditsRecipient() public {
        uint64 amount = 5_000_000_000; // 5 ETH in gwei
        address depositor = Emma;
        address recipient = Alice;

        vm.deal(depositor, 100 ether);

        uint256 inboxBalanceBefore = address(inbox).balance;

        vm.prank(depositor);
        inbox.depositTo{ value: _toTokenAmount(amount) }(recipient, amount);

        assertEq(inbox.getBond(recipient).balance, amount, "recipient bond balance");
        assertEq(
            address(inbox).balance,
            inboxBalanceBefore + _toTokenAmount(amount),
            "inbox ETH balance"
        );
    }

    function test_depositTo_RevertWhen_InvalidETHAmount() public {
        uint64 amount = 1_000_000_000;

        vm.deal(Emma, 100 ether);

        vm.prank(Emma);
        vm.expectRevert(LibBonds.InvalidETHAmount.selector);
        inbox.depositTo{ value: _toTokenAmount(amount) + 1 }(Alice, amount); // Send wrong amount
    }

    function test_depositTo_RevertWhen_NoETHSent() public {
        uint64 amount = 1_000_000_000;

        vm.deal(Emma, 100 ether);

        vm.prank(Emma);
        vm.expectRevert(LibBonds.InvalidETHAmount.selector);
        inbox.depositTo{ value: 0 }(Alice, amount); // Send no ETH
    }

    function test_depositTo_RevertWhen_RecipientZero() public {
        uint64 amount = 1_000_000_000;

        vm.deal(Emma, 100 ether);

        vm.prank(Emma);
        vm.expectRevert(LibBonds.InvalidAddress.selector);
        inbox.depositTo{ value: _toTokenAmount(amount) }(address(0), amount);
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

        uint256 inboxBalanceBefore = address(inbox).balance;
        uint256 accountBalanceBefore = account.balance;

        vm.startPrank(account);
        inbox.requestWithdrawal();
        uint48 requestedAt = inbox.getBond(account).withdrawalRequestedAt;
        assertGt(requestedAt, 0, "withdrawal requested");
        vm.warp(block.timestamp + config.withdrawalDelay + 1);
        inbox.withdraw(account, balance);
        vm.stopPrank();

        assertEq(inbox.getBond(account).balance, 0, "bond balance cleared");
        assertEq(inbox.getBond(account).withdrawalRequestedAt, 0, "withdrawal request cleared");
        assertEq(
            account.balance,
            accountBalanceBefore + _toTokenAmount(balance),
            "account ETH balance"
        );
        assertEq(
            address(inbox).balance,
            inboxBalanceBefore - _toTokenAmount(balance),
            "inbox ETH balance"
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

        vm.prank(proposer);
        inbox.deposit{ value: _toTokenAmount(amount) }(amount);

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

        vm.deal(Emma, 100 ether);

        vm.prank(Emma);
        inbox.depositTo{ value: _toTokenAmount(amount) }(proposer, amount);

        IBondManager.Bond memory bond = inbox.getBond(proposer);
        assertEq(bond.withdrawalRequestedAt, requestedAt, "withdrawal still pending");
        assertEq(bond.balance, balanceBefore + amount, "bond balance increased");
    }

    function test_getConfig_ShowsNativeETH() public view {
        IInbox.Config memory cfg = inbox.getConfig();
        assertEq(cfg.bondToken, address(0), "bond token is address(0) for native ETH");
    }
}
