// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoInbox.sol";
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
            assertEq(info.blobInfo.hashes.length, 0);
            assertEq(info.blobInfo.refHash, 0);
            assertEq(info.txsHash, keccak256(abi.encode(txList, 0, info.blobInfo.hashes)));
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
        bytes32 expectedHash1 = keccak256(abi.encode(txList1, 0, new bytes32[](0)));
        bytes32 expectedHash2 = keccak256(abi.encode(txList2, 0, new bytes32[](0)));

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
}
