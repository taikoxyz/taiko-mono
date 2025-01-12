// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";

contract InBoxTest_Params is InboxTestBase {
    function getConfig() internal pure override returns (ITaikoInbox.Config memory) {
        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxBatchProposals: 10,
            batchRingBufferSize: 15,
            maxBatchesToVerify: 5,
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
            maxBlocksPerBatch: 256,
            forkHeights: ITaikoInbox.ForkHeights({ ontake: 0, pacaya: 0 })
        });
    }

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();
        bondToken = deployBondToken();
    }

    function test_validateParams_defaults_when_anchorBlockId_is_zero() external transactBy(Alice) {
        ITaikoInbox.BlockParams[] memory blocks = new ITaikoInbox.BlockParams[](1);
        blocks[0] = ITaikoInbox.BlockParams({ numTransactions: 0, timeThift: 0 });

        ITaikoInbox.BatchParams memory params = ITaikoInbox.BatchParams({
            anchorBlockId: 0, // Simulate missing anchor block ID
            timestamp: 0,
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            numBlobs: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0),
            blocks: blocks
        });

        ITaikoInbox.BatchMetadata memory meta =
            inbox.proposeBatch(address(0), address(0), params, "txList");

        // Assert that the default anchorBlockId was set correctly
        uint64 expectedAnchorBlockId = uint64(block.number - 1);
        assertEq(meta.anchorBlockId, expectedAnchorBlockId, "AnchorBlockId mismatch");
    }

    function test_validateParams_reverts_when_anchorBlockId_too_small()
        external
        transactBy(Alice)
    {
        ITaikoInbox.Config memory config = inbox.getConfigV3();

        // Advance the block number to create the appropriate test scenario
        vm.roll(config.maxAnchorHeightOffset + 2);

        // Calculate an invalid anchorBlockId (too small)
        uint64 anchorBlockId = uint64(block.number - config.maxAnchorHeightOffset - 1);

        ITaikoInbox.BlockParams[] memory blocks = new ITaikoInbox.BlockParams[](1);
        blocks[0] = ITaikoInbox.BlockParams({ numTransactions: 0, timeThift: 0 });
        ITaikoInbox.BatchParams memory params = ITaikoInbox.BatchParams({
            anchorBlockId: anchorBlockId,
            timestamp: 0,
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            numBlobs: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0),
            blocks: blocks
        });

        vm.expectRevert(ITaikoInbox.AnchorBlockIdTooSmall.selector);
        inbox.proposeBatch(address(0), address(0), params, "txList");
    }

    function test_validateParams_reverts_when_anchorBlockId_too_large()
        external
        transactBy(Alice)
    {
        // Calculate an invalid anchorBlockId (too large)
        uint64 anchorBlockId = uint64(block.number);

        ITaikoInbox.BlockParams[] memory blocks = new ITaikoInbox.BlockParams[](1);
        blocks[0] = ITaikoInbox.BlockParams({ numTransactions: 0, timeThift: 0 });

        ITaikoInbox.BatchParams memory params = ITaikoInbox.BatchParams({
            anchorBlockId: anchorBlockId,
            timestamp: 0,
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            numBlobs: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0),
            blocks: blocks
        });

        vm.expectRevert(ITaikoInbox.AnchorBlockIdTooLarge.selector);
        inbox.proposeBatch(address(0), address(0), params, "txList");
    }

    function test_validateParams_reverts_when_anchorBlockId_smaller_than_parent()
        external
        transactBy(Alice)
    {
        vm.roll(10);
        _proposeBatchesWithDefaultParameters(1);
        ITaikoInbox.Batch memory parent = inbox.getBatch(1);

        ITaikoInbox.BlockParams[] memory blocks = new ITaikoInbox.BlockParams[](1);
        blocks[0] = ITaikoInbox.BlockParams({ numTransactions: 0, timeThift: 0 });

        ITaikoInbox.BatchParams memory params = ITaikoInbox.BatchParams({
            anchorBlockId: parent.anchorBlockId - 1,
            timestamp: 0,
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            numBlobs: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0),
            blocks: blocks
        });

        vm.expectRevert(ITaikoInbox.AnchorBlockIdSmallerThanParent.selector);
        inbox.proposeBatch(address(0), address(0), params, "txList");
    }

    function test_validateParams_when_anchorBlockId_is_not_zero() external transactBy(Alice) {
        ITaikoInbox.BlockParams[] memory blocks = new ITaikoInbox.BlockParams[](1);
        blocks[0] = ITaikoInbox.BlockParams({ numTransactions: 0, timeThift: 0 });
        ITaikoInbox.BatchParams memory params = ITaikoInbox.BatchParams({
            anchorBlockId: uint64(block.number - 1),
            timestamp: 0,
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            numBlobs: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0),
            blocks: blocks
        });

        ITaikoInbox.BatchMetadata memory meta =
            inbox.proposeBatch(address(0), address(0), params, "txList");

        uint64 expectedAnchorBlockId = uint64(block.number - 1);
        assertEq(meta.anchorBlockId, expectedAnchorBlockId, "AnchorBlockId mismatch");
    }

    function test_validateParams_reverts_when_timestamp_too_large() external transactBy(Alice) {
        ITaikoInbox.BlockParams[] memory blocks = new ITaikoInbox.BlockParams[](1);
        blocks[0] = ITaikoInbox.BlockParams({ numTransactions: 0, timeThift: 0 });
        ITaikoInbox.BatchParams memory params = ITaikoInbox.BatchParams({
            anchorBlockId: 0,
            timestamp: uint64(block.timestamp + 1),
            parentMetaHash: 0,
            signalSlots: new bytes32[](0),
            numBlobs: 0,
            txListOffset: 0,
            txListSize: 0,
            anchorInput: bytes32(0),
            blocks: blocks
        });

        vm.expectRevert(ITaikoInbox.TimestampTooLarge.selector);
        inbox.proposeBatch(address(0), address(0), params, "txList");
    }
}
