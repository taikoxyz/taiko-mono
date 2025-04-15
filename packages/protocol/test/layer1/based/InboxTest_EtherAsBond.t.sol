// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_EtherAsBond is InboxTestBase {
    function v4GetConfig() internal pure override returns (ITaikoInbox.Config memory) {
        ITaikoInbox.ForkHeights memory forkHeights;

        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 15,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 1 ether,
            livenessBondPerBlock: 0.1 ether,
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
            forkHeights: forkHeights
        });
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
