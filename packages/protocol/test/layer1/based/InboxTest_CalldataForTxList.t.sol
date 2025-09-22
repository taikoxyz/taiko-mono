// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_CalldataForTxList is InboxTestBase {
    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_calldata_used_for_txlist_da() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        // Define the txList in calldata
        bytes memory txList = abi.encodePacked("txList");
        vm.prank(Alice);
        uint64[] memory batchIds =
            _proposeBatchesWithDefaultParameters({ numBatchesToPropose: 1, txList: txList });

        for (uint256 i; i < batchIds.length; ++i) {
            (ITaikoInbox.BatchMetadata memory meta, ITaikoInbox.BatchInfo memory info) =
                _loadMetadataAndInfo(batchIds[i]);
            assertEq(meta.infoHash, keccak256(abi.encode(info)));
            assertEq(info.txsHash, keccak256(txList));
        }

        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batchIds);
    }

    function test_batch_rejection_due_to_missing_txlist_and_blobindex() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.BlobNotSpecified.selector);
        // With empty txList
        inbox.v4ProposeBatch(abi.encode(params), "", "");
    }

    function test_propose_batch_with_empty_txlist_and_valid_blobindex() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.blobParams.numBlobs = 1;

        vm.prank(Alice);

        // With empty txList
        (ITaikoInbox.BatchInfo memory info, ITaikoInbox.BatchMetadata memory meta) =
            inbox.v4ProposeBatch(abi.encode(params), "", "");
        assertTrue(info.txsHash != 0, "txsHash should not be zero for valid blobIndex");

        _saveMetadataAndInfo(meta, info);

        vm.prank(Alice);
        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = meta.batchId;

        _proveBatchesWithCorrectTransitions(batchIds);
    }

    function test_multiple_blocks_with_different_txlist() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        bytes memory txList1 = abi.encodePacked("txList1");
        bytes memory txList2 = abi.encodePacked("txList2");
        bytes32 expectedHash1 = keccak256(txList1);
        bytes32 expectedHash2 = keccak256(txList2);

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1, txList1);

        (, ITaikoInbox.BatchInfo memory info) = _loadMetadataAndInfo(batchIds[0]);

        assertEq(info.txsHash, expectedHash1, "txsHash mismatch for block 1");

        vm.prank(Alice);
        batchIds = _proposeBatchesWithDefaultParameters(1, txList2);

        (, info) = _loadMetadataAndInfo(batchIds[0]);
        assertEq(info.txsHash, expectedHash2, "txsHash mismatch for block 2");

        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batchIds);
    }

    function test_prove_batch_with_mismatched_info_hash() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        vm.prank(Alice);
        bytes memory txList = abi.encodePacked("txList");
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1, txList);

        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](batchIds.length);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](batchIds.length);

        for (uint256 i; i < batchIds.length; ++i) {
            (metas[i],) = _loadMetadataAndInfo(batchIds[i]);
            metas[i].infoHash = keccak256(abi.encodePacked("incorrect info hash"));
            transitions[i].parentHash = correctBlockhash(batchIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(batchIds[i]);
            transitions[i].stateRoot = correctStateRoot(batchIds[i]);
        }

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.MetaHashMismatch.selector);
        inbox.v4ProveBatches(abi.encode(metas, transitions), "proof");
    }

    function test_calldata_used_with_prover_auth() external {
        vm.warp(1_000_000);

        // Setup initial balances
        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        address prover = vm.addr(PROVER_PRIVATE_KEY);

        // Setup bond for both Alice and prover
        setupBondTokenState(Alice, initialBondBalance, bondAmount);
        setupBondTokenState(prover, initialBondBalance, bondAmount);

        // Check initial bond balances
        uint256 aliceInitialBond = inbox.v4BondBalanceOf(Alice);
        uint256 proverInitialBond = inbox.v4BondBalanceOf(prover);

        console2.log("Alice initial bond balance:", aliceInitialBond);
        console2.log("Prover initial bond balance:", proverInitialBond);

        // Define the txList in calldata
        bytes memory txList = abi.encodePacked("txList");

        vm.prank(Alice);
        uint64[] memory batchIds =
            _proposeBatchesWithProverAuth(Alice, 1, prover, PROVER_PRIVATE_KEY, txList);

        for (uint256 i; i < batchIds.length; ++i) {
            (ITaikoInbox.BatchMetadata memory meta, ITaikoInbox.BatchInfo memory info) =
                _loadMetadataAndInfo(batchIds[i]);

            assertEq(meta.infoHash, keccak256(abi.encode(info)), "Info hash mismatch");
            assertEq(info.txsHash, keccak256(txList), "TxList hash mismatch");
            assertEq(meta.prover, prover, "Prover address mismatch");
        }

        // Check updated bond balances
        uint256 aliceUpdatedBond = inbox.v4BondBalanceOf(Alice);
        uint256 proverUpdatedBond = inbox.v4BondBalanceOf(prover);

        console2.log("Alice updated bond balance:", aliceUpdatedBond);
        console2.log("Prover updated bond balance:", proverUpdatedBond);

        // Alice should have paid 5 ether fee
        assertEq(
            aliceUpdatedBond,
            aliceInitialBond - 5 ether,
            "Alice's bond wasn't properly debited for fee"
        );

        // Prover should have paid the liveness bond and received the fee
        ITaikoInbox.Config memory config = v4GetConfig();
        uint256 livenessDebit = config.livenessBond;
        uint256 feeCredit = 5 ether;

        assertEq(
            proverUpdatedBond,
            proverInitialBond - livenessDebit + feeCredit,
            "Prover's bond wasn't properly adjusted"
        );

        // Prove the batch
        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batchIds);
    }

    function test_multiple_batches_with_different_provers() external {
        vm.warp(1_000_000);

        // Setup for two different provers
        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        uint256 PROVER1_KEY = 0x12345678;
        uint256 PROVER2_KEY = 0x87654321;

        address prover1 = vm.addr(PROVER1_KEY);
        address prover2 = vm.addr(PROVER2_KEY);

        // Setup bonds for all parties
        setupBondTokenState(Alice, initialBondBalance, bondAmount);
        setupBondTokenState(prover1, initialBondBalance, bondAmount);
        setupBondTokenState(prover2, initialBondBalance, bondAmount);

        // Define two different txLists
        bytes memory txList1 = abi.encodePacked("txList1");
        bytes memory txList2 = abi.encodePacked("txList2");

        // Propose first batch with prover1
        vm.prank(Alice);
        uint64[] memory batch1Ids =
            _proposeBatchesWithProverAuth(Alice, 1, prover1, PROVER1_KEY, txList1);

        (ITaikoInbox.BatchMetadata memory meta1, ITaikoInbox.BatchInfo memory info1) =
            _loadMetadataAndInfo(batch1Ids[0]);

        assertEq(meta1.prover, prover1, "Batch 1 prover mismatch");
        assertEq(info1.txsHash, keccak256(txList1), "Batch 1 txList hash mismatch");

        // Propose second batch with prover2
        vm.prank(Alice);
        uint64[] memory batch2Ids =
            _proposeBatchesWithProverAuth(Alice, 1, prover2, PROVER2_KEY, txList2);

        (ITaikoInbox.BatchMetadata memory meta2, ITaikoInbox.BatchInfo memory info2) =
            _loadMetadataAndInfo(batch2Ids[0]);

        assertEq(meta2.prover, prover2, "Batch 2 prover mismatch");
        assertEq(info2.txsHash, keccak256(txList2), "Batch 2 txList hash mismatch");

        // Verify both batches can be proved
        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batch1Ids);

        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batch2Ids);
    }
}
