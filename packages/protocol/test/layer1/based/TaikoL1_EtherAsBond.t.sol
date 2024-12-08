// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoL1.sol";
import "./TaikoL1TestBase.sol";

contract TaikoL1Test_EtherAsBond is TaikoL1TestBase {
    function getConfig() internal pure override returns (ITaikoL1.ConfigV3 memory) {
        return ITaikoL1.ConfigV3({
            chainId: LibNetwork.TAIKO_MAINNET,
            blockMaxProposals: 10,
            blockRingBufferSize: 15,
            maxBlocksToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18, // 125 Taiko token
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
            emitTxListInCalldata: true,
            pacayaForkHeight: 0
        });
    }

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();

        // Use Ether as bond token
        bondToken = TaikoToken(address(0));
    }

    function test_taikoL1_deposit_withdraw() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;

        vm.prank(Alice);
        taikoL1.depositBond{ value: depositAmount }(depositAmount);
        assertEq(taikoL1.bondBalanceOf(Alice), depositAmount);

        vm.prank(Alice);
        taikoL1.withdrawBond(withdrawAmount);
        assertEq(taikoL1.bondBalanceOf(Alice), depositAmount - withdrawAmount);
    }

    function test_taikoL1_withdraw_more_than_bond_balance() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 2 ether;

        vm.prank(Alice);
        taikoL1.depositBond{ value: depositAmount }(depositAmount);

        vm.prank(Alice);
        vm.expectRevert(ITaikoL1.InsufficientBond.selector);
        taikoL1.withdrawBond(withdrawAmount);
    }

    function test_taikoL1_exceeding_balance() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 0.5 ether);

        uint256 depositAmount = 1 ether;

        vm.prank(Alice);
        vm.expectRevert();
        taikoL1.depositBond{ value: depositAmount }(depositAmount);
    }

    function test_taikoL1_overpayment_of_ether() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 depositAmount = 1 ether;

        vm.prank(Alice);
        vm.expectRevert(ITaikoL1.EtherNotPaidAsBond.selector);
        taikoL1.depositBond{ value: depositAmount + 1 }(depositAmount);
    }

    function test_taikoL1_eth_not_paid_as_bond_on_deposit() external {
        vm.warp(1_000_000);
        vm.deal(Alice, 1000 ether);

        uint256 depositAmount = 1 ether;

        vm.prank(Alice);
        vm.expectRevert(ITaikoL1.EtherNotPaidAsBond.selector);
        taikoL1.depositBond{ value: 0 }(depositAmount);
    }

    function test_taikoL1_bond_balance_after_multiple_operations() external {
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
        taikoL1.depositBond{ value: aliceFirstDeposit }(aliceFirstDeposit);
        assertEq(taikoL1.bondBalanceOf(Alice), aliceFirstDeposit);

        vm.prank(Bob);
        taikoL1.depositBond{ value: bobDeposit }(bobDeposit);
        assertEq(taikoL1.bondBalanceOf(Bob), bobDeposit);

        vm.prank(Alice);
        taikoL1.depositBond{ value: aliceSecondDeposit }(aliceSecondDeposit);
        assertEq(taikoL1.bondBalanceOf(Alice), aliceFirstDeposit + aliceSecondDeposit);

        vm.prank(Bob);
        taikoL1.withdrawBond(bobWithdraw);
        assertEq(taikoL1.bondBalanceOf(Bob), bobDeposit - bobWithdraw);

        vm.prank(Alice);
        taikoL1.withdrawBond(aliceFirstWithdraw);
        assertEq(
            taikoL1.bondBalanceOf(Alice),
            aliceFirstDeposit + aliceSecondDeposit - aliceFirstWithdraw
        );

        vm.prank(Alice);
        taikoL1.withdrawBond(aliceSecondWithdraw);
        assertEq(
            taikoL1.bondBalanceOf(Alice),
            aliceFirstDeposit + aliceSecondDeposit - aliceFirstWithdraw - aliceSecondWithdraw
        );

        assertEq(
            taikoL1.bondBalanceOf(Alice),
            aliceFirstDeposit + aliceSecondDeposit - aliceFirstWithdraw - aliceSecondWithdraw
        );
        assertEq(taikoL1.bondBalanceOf(Bob), bobDeposit - bobWithdraw);
    }
}
