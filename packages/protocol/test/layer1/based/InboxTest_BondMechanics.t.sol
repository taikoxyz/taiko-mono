// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_BondMechanics is InboxTestBase {
    uint16 constant provingWindow = 1 hours;

    function getConfig() internal pure override returns (ITaikoInbox.ConfigV3 memory) {
        return ITaikoInbox.ConfigV3({
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
            provingWindow: provingWindow,
            maxSignalsToReceive: 16,
            forkHeights: ITaikoInbox.ForkHeights({ ontake: 0, pacaya: 0 })
        });
    }

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();
        bondToken = deployBondToken();
    }

    function test_inbox_bonds_debit_and_credit_on_proposal_and_proof() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        vm.prank(Alice);
        uint64[] memory blockIds = _proposeBlocksWithDefaultParameters({ numBlocksToPropose: 1 });
        assertEq(inbox.bondBalanceOf(Alice) < bondAmount, true);

        vm.prank(Alice);
        _proveBlocksWithCorrectTransitions(blockIds);

        assertEq(inbox.bondBalanceOf(Alice), bondAmount);
    }

    function test_only_proposer_can_prove_block_before_deadline() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);
        setupBondTokenState(Bob, initialBondBalance, bondAmount);

        vm.prank(Alice);
        uint64[] memory blockIds = _proposeBlocksWithDefaultParameters({ numBlocksToPropose: 1 });
        assertEq(inbox.bondBalanceOf(Alice) < bondAmount, true);

        vm.prank(Bob);
        vm.expectRevert(ITaikoInbox.ProverNotPermitted.selector);
        _proveBlocksWithCorrectTransitions(blockIds);

        assertEq(inbox.bondBalanceOf(Bob), bondAmount);
    }

    function test_inbox_bonds_debited_on_proposal_not_credited_back_if_proved_after_deadline()
        external
    {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        vm.prank(Alice);
        uint64[] memory blockIds = _proposeBlocksWithDefaultParameters({ numBlocksToPropose: 1 });

        uint256 aliceBondBalanceAfterProposal = inbox.bondBalanceOf(Alice);
        assertEq(aliceBondBalanceAfterProposal < bondAmount, true);

        // Simulate waiting for blocks after proving deadline
        uint256 secondsPerBlock = 12;
        uint256 blocksToWait = provingWindow / secondsPerBlock + 1;
        simulateBlockDelay(secondsPerBlock, blocksToWait);

        vm.prank(Alice);
        _proveBlocksWithCorrectTransitions(blockIds);

        uint256 aliceBondBalanceAfterProof = inbox.bondBalanceOf(Alice);
        assertEq(aliceBondBalanceAfterProof, aliceBondBalanceAfterProposal);
        assertEq(aliceBondBalanceAfterProof < bondAmount, true);
    }

    function test_inbox_bonds_debit_and_credit_on_proposal_and_proof_with_exact_proving_window()
        external
    {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        vm.prank(Alice);
        uint64[] memory blockIds = _proposeBlocksWithDefaultParameters({ numBlocksToPropose: 1 });

        uint256 aliceBondBalanceAfterProposal = inbox.bondBalanceOf(Alice);
        assertEq(aliceBondBalanceAfterProposal < bondAmount, true);

        // Simulate waiting for exactly the proving window
        uint256 secondsPerBlock = 12;
        uint256 blocksToWait = provingWindow / secondsPerBlock;
        simulateBlockDelay(secondsPerBlock, blocksToWait);

        vm.prank(Alice);
        _proveBlocksWithCorrectTransitions(blockIds);

        assertEq(inbox.bondBalanceOf(Alice), bondAmount);
    }
}
