// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoL1.sol";
import "./TaikoL1TestBase.sol";

contract TaikoL1_CalldataForTxList is TaikoL1TestBase {
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
            maxSignalsToReceive: 16,
            forkHeights: ITaikoL1.ForkHeights({ ontake: 0, pacaya: 0 })
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
        uint64[] memory blockIds =
            _proposeBlocksWithDefaultParameters({ numBlocksToPropose: 1, txList: txList });
        for (uint256 i; i < blockIds.length; ++i) {
            ITaikoL1.BlockMetadataV3 memory meta = blockMetadatas[blockIds[i]];
            assertEq(meta.txListHash, expectedHash);
        }

        vm.prank(Alice);
        _proveBlocksWithCorrectTransitions(blockIds);
    }

    function test_block_rejection_due_to_missing_txlist_and_blobindex() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        // Define empty txList
        bytes memory txList = "";
        ITaikoL1.BlockParamsV3[] memory blockParams = new ITaikoL1.BlockParamsV3[](1);
        blockParams[0].blobIndex = 0; // Blob index not provided

        vm.prank(Alice);
        vm.expectRevert(ITaikoL1.BlobIndexZero.selector);
        taikoL1.proposeBlocksV3(address(0), address(0), blockParams, txList);
    }

    function test_propose_block_with_empty_txlist_and_valid_blobindex() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        // Define empty txList
        bytes memory txList = "";
        ITaikoL1.BlockParamsV3[] memory blockParams = new ITaikoL1.BlockParamsV3[](1);
        blockParams[0].blobIndex = 1; // Valid blob index

        vm.prank(Alice);
        ITaikoL1.BlockMetadataV3[] memory metas =
            taikoL1.proposeBlocksV3(address(0), address(0), blockParams, txList);

        ITaikoL1.BlockMetadataV3 memory meta = metas[0];
        assertTrue(meta.txListHash != 0, "txListHash should not be zero for valid blobIndex");

        vm.prank(Alice);
        uint64[] memory blockIds = new uint64[](metas.length);
        for (uint256 i; i < metas.length; ++i) {
            blockMetadatas[metas[i].blockId] = metas[i];
            blockIds[i] = metas[i].blockId;
        }
        _proveBlocksWithCorrectTransitions(blockIds);
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
        uint64[] memory blockIds1 = _proposeBlocksWithDefaultParameters(1, txList1);
        ITaikoL1.BlockMetadataV3 memory meta1 = blockMetadatas[blockIds1[0]];
        assertEq(meta1.txListHash, expectedHash1, "txListHash mismatch for block 1");

        vm.prank(Alice);
        uint64[] memory blockIds2 = _proposeBlocksWithDefaultParameters(1, txList2);
        ITaikoL1.BlockMetadataV3 memory meta2 = blockMetadatas[blockIds2[0]];
        assertEq(meta2.txListHash, expectedHash2, "txListHash mismatch for block 2");

        vm.prank(Alice);
        _proveBlocksWithCorrectTransitions(blockIds2);

        vm.prank(Alice);
        _proveBlocksWithCorrectTransitions(blockIds1);
    }

    function test_prove_block_with_mismatched_txlist() external {
        vm.warp(1_000_000);

        uint256 initialBondBalance = 100_000 ether;
        uint256 bondAmount = 1000 ether;

        setupBondTokenState(Alice, initialBondBalance, bondAmount);

        // Define a correct txList for proposal
        bytes memory txList = abi.encodePacked("correct txList");

        vm.prank(Alice);
        uint64[] memory blockIds = _proposeBlocksWithDefaultParameters(1, txList);

        // Define an incorrect txList for proof
        bytes32 incorrectHash = keccak256(abi.encodePacked("incorrect txList"));

        // Attempt to prove the block with the incorrect txList
        ITaikoL1.BlockMetadataV3 memory meta = blockMetadatas[blockIds[0]];
        meta.txListHash = incorrectHash;

        ITaikoL1.BlockMetadataV3[] memory metas = new ITaikoL1.BlockMetadataV3[](blockIds.length);
        ITaikoL1.TransitionV3[] memory transitions = new ITaikoL1.TransitionV3[](blockIds.length);

        for (uint256 i; i < blockIds.length; ++i) {
            metas[i] = blockMetadatas[blockIds[i]];
            metas[i].txListHash = incorrectHash;
            transitions[i].parentHash = correctBlockhash(blockIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(blockIds[i]);
            transitions[i].stateRoot = correctStateRoot(blockIds[i]);
        }

        vm.prank(Alice);
        vm.expectRevert(ITaikoL1.MetaHashMismatch.selector);
        taikoL1.proveBlocksV3(metas, transitions, "proof");
    }
}
