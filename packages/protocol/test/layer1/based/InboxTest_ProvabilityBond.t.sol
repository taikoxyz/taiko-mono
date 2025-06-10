// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_ProvabilityBond is InboxTestBase {
    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function v4GetConfig() internal pure override returns (ITaikoInbox.Config memory config_) {
        config_ = super.v4GetConfig();
        config_.livenessBond = 100 ether;
        config_.provingWindow = 1 hours;
        config_.provabilityBond = 1000 ether;
        config_.extendedProvingWindow = 4 hours;
        config_.bondRewardPtcg = 50; // 50%
        config_.maxBatchesToVerify = 0;
    }

    function test_inbox_provability_bond_debit_and_credit_proved_by_proposer_in_proving_window()
        external
    {
        vm.warp(1_000_000);

        uint256 bondBalance = 100_000 ether;
        setupBondTokenState(Alice, bondBalance, bondBalance);
        setupBondTokenState(Bob, bondBalance, bondBalance);

        ITaikoInbox.Config memory config = v4GetConfig();

        LibProverAuth.ProverAuth memory auth;
        auth.prover = Bob;
        auth.feeToken = address(bondToken);
        auth.fee = 50 ether;
        auth.signature = "";

        ITaikoInbox.BatchParams memory batchParams;
        batchParams.proposer = Alice;
        batchParams.coinbase = Alice;
        batchParams.blocks = new ITaikoInbox.BlockParams[](1);
        bytes memory txList = "txList";
        bytes32 txListHash = keccak256(abi.encodePacked(txList));

        bytes32 digest = LibProverAuth.computeProverAuthDigest(
            config.chainId, keccak256(abi.encode(batchParams)), txListHash, auth
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(0x2), digest);
        auth.signature = abi.encodePacked(r, s, v);
        batchParams.proverAuth = abi.encode(auth);

        vm.prank(Alice);
        (ITaikoInbox.BatchInfo memory info, ITaikoInbox.BatchMetadata memory meta) =
            inbox.v4ProposeBatch(abi.encode(batchParams), txList, "");

        _saveMetadataAndInfo(meta, info);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = meta.batchId;

        // assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.provabilityBond);

        // vm.prank(Bob);
        _proveBatchesWithCorrectTransitions(batchIds);

        //  assertEq(
        //     inbox.v4BondBalanceOf(Alice), bondBalance
        // );
        // assertEq(
        //     inbox.v4BondBalanceOf(Bob), bondBalance - config.livenessBond -
        // config.provabilityBond
        // );
    }

    // function
    // test_inbox_provability_bond_debit_and_credit_proved_by_non_proposer_in_proving_window()
    //     external
    // {
    //     vm.warp(1_000_000);

    //     uint256 initialBondBalance = 100_000 ether;
    //     uint256 bondBalance = 1000 ether;

    //     setupBondTokenState(Alice, initialBondBalance, bondBalance);

    //     ITaikoInbox.Config memory config = v4GetConfig();

    //     vm.prank(Alice);
    //     uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
    //     assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond);

    //     vm.prank(Bob);
    //     _proveBatchesWithCorrectTransitions(batchIds);

    //     assertEq(inbox.v4BondBalanceOf(Alice), bondBalance);
    //     assertEq(inbox.v4BondBalanceOf(Bob), 0);
    // }

    // function test_inbox_provability_bond_half_returned_to_proposer_out_of_proving_window()
    //     external
    // {
    //     vm.warp(1_000_000);

    //     uint256 initialBondBalance = 100_000 ether;
    //     uint256 bondBalance = 1000 ether;

    //     setupBondTokenState(Alice, initialBondBalance, bondBalance);

    //     ITaikoInbox.Config memory config = v4GetConfig();

    //     vm.prank(Alice);
    //     uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
    //     assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond);

    //     vm.warp(block.timestamp + config.provingWindow + 1);
    //     vm.prank(Alice);
    //     _proveBatchesWithCorrectTransitions(batchIds);

    //     assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond / 2);
    // }

    // function test_inbox_provability_bond_half_returned_to_non_proposer_out_of_proving_window()
    //     external
    // {
    //     vm.warp(1_000_000);

    //     uint256 initialBondBalance = 100_000 ether;
    //     uint256 bondBalance = 1000 ether;

    //     setupBondTokenState(Alice, initialBondBalance, bondBalance);

    //     ITaikoInbox.Config memory config = v4GetConfig();

    //     vm.prank(Alice);
    //     uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1);
    //     assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond);

    //     vm.warp(block.timestamp + config.provingWindow + 1);
    //     vm.prank(Bob);
    //     _proveBatchesWithCorrectTransitions(batchIds);

    //     assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.livenessBond);
    //     assertEq(inbox.v4BondBalanceOf(Bob), config.livenessBond / 2);
    // }

    // function test_inbox_provability_bond_multiple_blocks_per_batch() external transactBy(Alice) {
    //     ITaikoInbox.BatchParams memory params;
    //     params.blocks = new ITaikoInbox.BlockParams[](2);

    //     (, ITaikoInbox.BatchMetadata memory meta) =
    //         inbox.v4ProposeBatch(abi.encode(params), "txList", "");

    //     ITaikoInbox.Batch memory batch = inbox.v4GetBatch(meta.batchId);

    //     ITaikoInbox.Config memory config = v4GetConfig();
    //     assertEq(batch.livenessBond, config.livenessBond);
    // }
}
