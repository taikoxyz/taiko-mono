// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_CalldataForTxList is InboxTestBase {
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
        inbox.proposeBatch(abi.encode(params), "");
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
        (ITaikoInbox.BatchMetadata memory meta,) = inbox.proposeBatch(abi.encode(params), "");
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

        bytes memory txList1 = abi.encodePacked("txList1");
        bytes memory txList2 = abi.encodePacked("txList2");

        vm.prank(Alice);
        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(1, txList1);

        vm.prank(Alice);
        batchIds = _proposeBatchesWithDefaultParameters(1, txList2);

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
            metas[i] = _loadMetadata(batchIds[i]);
            metas[i].infoHash = keccak256(abi.encodePacked("incorrect info hash"));
            transitions[i].parentHash = correctBlockhash(batchIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(batchIds[i]);
            transitions[i].stateRoot = correctStateRoot(batchIds[i]);
        }

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.MetaHashMismatch.selector);
        inbox.proveBatches(abi.encode(metas, transitions), "proof");
    }
}
