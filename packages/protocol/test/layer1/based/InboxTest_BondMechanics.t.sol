// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_BondMechanics is InboxTestBase {
    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_inbox_bonds_debit_and_credit_proved_by_proposer_in_proving_window() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondBalance = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondBalance);

        ITaikoInbox.Config memory config = v4GetConfig();

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
        assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond);

        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batchIds);

        assertEq(inbox.v4BondBalanceOf(Alice), bondBalance);
    }

    function test_inbox_bonds_debit_and_credit_proved_by_non_proposer_in_proving_window()
        external
    {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondBalance = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondBalance);

        ITaikoInbox.Config memory config = v4GetConfig();

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
        assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond);

        vm.prank(Bob);
        _proveBatchesWithCorrectTransitions(batchIds);

        assertEq(inbox.v4BondBalanceOf(Alice), bondBalance);
        assertEq(inbox.v4BondBalanceOf(Bob), 0);
    }

    function test_inbox_bonds_half_returned_to_proposer_out_of_proving_window() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondBalance = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondBalance);

        ITaikoInbox.Config memory config = v4GetConfig();

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
        assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond);

        vm.warp(block.timestamp + config.provingWindow + 1);
        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batchIds);

        assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond / 2);
    }

    function test_inbox_bonds_half_returned_to_non_proposer_out_of_proving_window() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondBalance = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondBalance);

        ITaikoInbox.Config memory config = v4GetConfig();

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
        assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond);

        vm.warp(block.timestamp + config.provingWindow + 1);
        vm.prank(Bob);
        _proveBatchesWithCorrectTransitions(batchIds);

        assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond);
        assertEq(inbox.v4BondBalanceOf(Bob), config.livenessBond / 2);
    }

    function test_inbox_bonds_multiple_blocks_per_batch() external transactBy(Alice) {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](2);

        (, ITaikoInbox.BatchMetadata memory meta) =
            inbox.v4ProposeBatch(abi.encode(params), "txList", "");

        ITaikoInbox.Batch memory batch = inbox.v4GetBatch(meta.batchId);

        ITaikoInbox.Config memory config = v4GetConfig();
        assertEq(batch.livenessBond, config.livenessBond);
    }
}
