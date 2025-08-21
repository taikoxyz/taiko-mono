// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_BondMechanics is InboxTestBase {
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
            forkHeights: forkHeights
        });
    }

    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_inbox_bonds_debit_and_credit_proved_by_proposer_in_proving_window() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondBalance = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondBalance);

        ITaikoInbox.Config memory config = pacayaConfig();

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
        assertEq(inbox.bondBalanceOf(Alice), bondBalance - config.livenessBondBase);

        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batchIds);

        assertEq(inbox.bondBalanceOf(Alice), bondBalance);
    }

    function test_inbox_bonds_debit_and_credit_proved_by_non_proposer_in_proving_window()
        external
    {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondBalance = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondBalance);

        ITaikoInbox.Config memory config = pacayaConfig();

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
        assertEq(inbox.bondBalanceOf(Alice), bondBalance - config.livenessBondBase);

        vm.prank(Bob);
        _proveBatchesWithCorrectTransitions(batchIds);

        assertEq(inbox.bondBalanceOf(Alice), bondBalance);
        assertEq(inbox.bondBalanceOf(Bob), 0);
    }

    function test_inbox_bonds_half_returned_to_proposer_out_of_proving_window() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondBalance = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondBalance);

        ITaikoInbox.Config memory config = pacayaConfig();

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
        assertEq(inbox.bondBalanceOf(Alice), bondBalance - config.livenessBondBase);

        vm.warp(block.timestamp + pacayaConfig().provingWindow + 1);
        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batchIds);

        assertEq(inbox.bondBalanceOf(Alice), bondBalance - config.livenessBondBase / 2);
    }

    function test_inbox_bonds_half_returned_to_non_proposer_out_of_proving_window() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondBalance = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondBalance);

        ITaikoInbox.Config memory config = pacayaConfig();

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
        assertEq(inbox.bondBalanceOf(Alice), bondBalance - config.livenessBondBase);

        vm.warp(block.timestamp + pacayaConfig().provingWindow + 1);
        vm.prank(Bob);
        _proveBatchesWithCorrectTransitions(batchIds);

        assertEq(inbox.bondBalanceOf(Alice), bondBalance - config.livenessBondBase);
        assertEq(inbox.bondBalanceOf(Bob), config.livenessBondBase / 2);
    }

    function test_inbox_bonds_multiple_blocks_per_batch() external transactBy(Alice) {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](2);

        (ITaikoInbox.BatchMetadata memory meta,) = inbox.proposeBatch(abi.encode(params), "txList");

        ITaikoInbox.Batch memory batch = inbox.getBatch(meta.batchId);

        ITaikoInbox.Config memory config = pacayaConfig();
        assertEq(batch.livenessBond, config.livenessBondBase);
    }
}
