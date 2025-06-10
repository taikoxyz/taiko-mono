// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_BondToken is InboxTestBase {
    function pacayaConfig() internal pure override returns (ITaikoInbox.Config memory) {
        ITaikoInbox.ForkHeights memory forkHeights;

        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 15,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 125e18, // 125 Taiko token per batch
            livenessBondPerBlock: 0, // deprecated
            stateRootSyncInternal: 5,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            provingWindow: 1 hours,
            cooldownWindow: 0 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: forkHeights,
            // Surge: to prevent compilation errors
            maxVerificationDelay: 0
        });
    }

    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_inbox_deposit_withdraw() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 transferAmount = 1234 ether;
        bondToken.transfer(Alice, transferAmount);
        assertEq(bondToken.balanceOf(Alice), transferAmount);

        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;

        vm.prank(Alice);
        bondToken.approve(address(inbox), depositAmount);

        vm.prank(Alice);
        inbox.depositBond(depositAmount);
        assertEq(inbox.bondBalanceOf(Alice), depositAmount);

        vm.prank(Alice);
        inbox.withdrawBond(withdrawAmount);
        assertEq(inbox.bondBalanceOf(Alice), depositAmount - withdrawAmount);
    }

    function test_inbox_withdraw_more_than_bond_balance() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 transferAmount = 10 ether;
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 2 ether;

        bondToken.transfer(Alice, transferAmount);

        vm.prank(Alice);
        bondToken.approve(address(inbox), depositAmount);

        vm.prank(Alice);
        inbox.depositBond(depositAmount);

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.InsufficientBond.selector);
        inbox.withdrawBond(withdrawAmount);
    }

    function test_inbox_insufficient_approval() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 transferAmount = 10 ether;
        uint256 insufficientApproval = 5 ether;
        uint256 depositAmount = 10 ether;

        bondToken.transfer(Alice, transferAmount);

        vm.prank(Alice);
        bondToken.approve(address(inbox), insufficientApproval);

        vm.prank(Alice);
        vm.expectRevert("ERC20: insufficient allowance");
        inbox.depositBond(depositAmount);
    }

    function test_inbox_exceeding_token_balance() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 transferAmount = 10 ether;
        uint256 depositAmount = 12 ether;

        bondToken.transfer(Alice, transferAmount);

        vm.prank(Alice);
        bondToken.approve(address(inbox), depositAmount);

        vm.prank(Alice);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        inbox.depositBond(depositAmount);
    }

    function test_inbox_no_value_sent_on_deposit() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 transferAmount = 10 ether;
        uint256 depositAmount = 1 ether;

        bondToken.transfer(Alice, transferAmount);

        vm.prank(Alice);
        bondToken.approve(address(inbox), depositAmount);

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.MsgValueNotZero.selector);
        inbox.depositBond{ value: 1 }(depositAmount);
    }

    function test_inbox_deposit_and_withdraw_from_multiple_users() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);
        vm.deal(Bob, 50 ether);

        uint256 transferAmountAlice = 20 ether;
        uint256 transferAmountBob = 10 ether;

        // Transfer bond tokens to Alice and Bob
        bondToken.transfer(Alice, transferAmountAlice);
        assertEq(bondToken.balanceOf(Alice), transferAmountAlice);

        bondToken.transfer(Bob, transferAmountBob);
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
        inbox.depositBond(aliceFirstDeposit);
        assertEq(inbox.bondBalanceOf(Alice), aliceFirstDeposit);

        vm.prank(Bob);
        bondToken.approve(address(inbox), bobDeposit);

        vm.prank(Bob);
        inbox.depositBond(bobDeposit);
        assertEq(inbox.bondBalanceOf(Bob), bobDeposit);

        vm.prank(Alice);
        bondToken.approve(address(inbox), aliceSecondDeposit);

        vm.prank(Alice);
        inbox.depositBond(aliceSecondDeposit);
        assertEq(inbox.bondBalanceOf(Alice), aliceFirstDeposit + aliceSecondDeposit);

        vm.prank(Bob);
        inbox.withdrawBond(bobWithdraw);
        assertEq(inbox.bondBalanceOf(Bob), bobDeposit - bobWithdraw);

        vm.prank(Alice);
        inbox.withdrawBond(aliceFirstWithdraw);
        assertEq(
            inbox.bondBalanceOf(Alice), aliceFirstDeposit + aliceSecondDeposit - aliceFirstWithdraw
        );

        vm.prank(Alice);
        inbox.withdrawBond(aliceSecondWithdraw);
        assertEq(
            inbox.bondBalanceOf(Alice),
            aliceFirstDeposit + aliceSecondDeposit - aliceFirstWithdraw - aliceSecondWithdraw
        );

        assertEq(
            inbox.bondBalanceOf(Alice),
            aliceFirstDeposit + aliceSecondDeposit - aliceFirstWithdraw - aliceSecondWithdraw
        );
        assertEq(inbox.bondBalanceOf(Bob), bobDeposit - bobWithdraw);
    }
}
