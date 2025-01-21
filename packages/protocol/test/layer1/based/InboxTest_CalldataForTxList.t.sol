// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_CalldataForTxList is InboxTestBase {
    function getConfig() internal pure override returns (ITaikoInbox.Config memory) {
        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 15,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 125e18, // 125 Taiko token per batch
            livenessBondPerBlock: 5e18, // 5 Taiko token per block
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
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: ITaikoInbox.ForkHeights({ ontake: 0, pacaya: 0 })
        });
    }

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();
        bondToken = deployBondToken();
    }

    function test_calldata_used_for_txlist_da() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        // Define the txList in calldata
        bytes memory txList = abi.encodePacked("txList");
        bytes32 expectedHash = keccak256(txList);

        vm.prank(Alice);
        uint64[] memory batchIds =
            _proposeBatchesWithDefaultParameters({ numBatchesToPropose: 1, txList: txList });

        for (uint256 i; i < batchIds.length; ++i) {
            ITaikoInbox.BatchMetadata memory meta = _loadMetadata(batchIds[i]);
            assertEq(meta.txListHash, expectedHash);
        }

        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batchIds);
    }

    function test_propose_batch_with_empty_txlist_and_valid_blobindex() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.numBlobs = 1;

        vm.prank(Alice);

        // With empty txList
        ITaikoInbox.BatchMetadata memory meta = inbox.proposeBatch(abi.encode(params), "");
        assertTrue(meta.txListHash != 0, "txListHash should not be zero for valid blobIndex");

        _saveMetadata(meta);

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

        bytes32[] memory hashes = new bytes32[](1);

        bytes memory txList1 = abi.encodePacked("txList1");
        hashes[0] = keccak256(txList1);
        bytes32 expectedHash1 = keccak256(abi.encode(hashes));

        bytes memory txList2 = abi.encodePacked("txList2");
        hashes[0] = keccak256(txList2);
        bytes32 expectedHash2 = keccak256(abi.encode(hashes));

        vm.prank(Alice);
        uint64[] memory batchIds1 = _proposeBatchesWithDefaultParameters(1, txList1);
        ITaikoInbox.BatchMetadata memory meta1 = _loadMetadata(batchIds1[0]);
        assertEq(meta1.txListHash, expectedHash1, "txListHash mismatch for block 1");

        vm.prank(Alice);
        uint64[] memory batchIds2 = _proposeBatchesWithDefaultParameters(1, txList2);
        ITaikoInbox.BatchMetadata memory meta2 = _loadMetadata(batchIds2[0]);
        assertEq(meta2.txListHash, expectedHash2, "txListHash mismatch for block 2");

        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batchIds2);

        vm.prank(Alice);
        _proveBatchesWithCorrectTransitions(batchIds1);
    }

    function test_prove_batch_with_mismatched_txlist() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        // Define a correct txList for proposal
        bytes memory txList = abi.encodePacked("correct txList");

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1, txList);

        // Define an incorrect txList for proof
        bytes32 incorrectHash = keccak256(abi.encodePacked("incorrect txList"));

        // Attempt to prove the block with the incorrect txList
        ITaikoInbox.BatchMetadata memory meta = _loadMetadata(batchIds[0]);
        meta.txListHash = incorrectHash;

        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](batchIds.length);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](batchIds.length);

        for (uint256 i; i < batchIds.length; ++i) {
            metas[i] = _loadMetadata(batchIds[i]);
            metas[i].txListHash = incorrectHash;
            transitions[i].parentHash = correctBlockhash(batchIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(batchIds[i]);
            transitions[i].stateRoot = correctStateRoot(batchIds[i]);
        }

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.MetaHashMismatch.selector);
        inbox.proveBatches(abi.encode(metas, transitions), "proof");
    }
}
