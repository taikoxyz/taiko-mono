// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";

contract InboxTest_Params is InboxTestBase {
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

    function test_validateParams_defaults_when_anchorBlockId_is_zero() external transactBy(Alice) {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);

        inbox.proposeBatch(abi.encode(params), "txList");
    }

    function test_validateParams_reverts_when_anchorBlockId_too_small()
        external
        transactBy(Alice)
    {
        ITaikoInbox.Config memory config = inbox.pacayaConfig();

        // Advance the block number to create the appropriate test scenario
        vm.roll(config.maxAnchorHeightOffset + 2);

        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        // Calculate an invalid anchorBlockId (too small)
        params.anchorBlockId = uint64(block.number - config.maxAnchorHeightOffset - 1);

        vm.expectRevert(ITaikoInbox.AnchorBlockIdTooSmall.selector);
        inbox.proposeBatch(abi.encode(params), "txList");
    }

    function test_validateParams_reverts_when_anchorBlockId_too_large()
        external
        transactBy(Alice)
    {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        // Calculate an invalid anchorBlockId (too large)
        params.anchorBlockId = uint64(block.number);

        vm.expectRevert(ITaikoInbox.AnchorBlockIdTooLarge.selector);
        inbox.proposeBatch(abi.encode(params), "txList");
    }

    function test_validateParams_reverts_when_anchorBlockId_smaller_than_parent()
        external
        transactBy(Alice)
    {
        vm.roll(10);
        _proposeBatchesWithDefaultParameters(1);
        ITaikoInbox.Batch memory parent = inbox.getBatch(1);

        ITaikoInbox.BlockParams[] memory blocks = new ITaikoInbox.BlockParams[](1);
        blocks[0] = ITaikoInbox.BlockParams({
            numTransactions: 0,
            timeShift: 0,
            signalSlots: new bytes32[](0)
        });

        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.anchorBlockId = parent.anchorBlockId - 1;

        vm.expectRevert(ITaikoInbox.AnchorBlockIdSmallerThanParent.selector);
        inbox.proposeBatch(abi.encode(params), "txList");
    }

    function test_validateParams_when_anchorBlockId_is_not_zero() external transactBy(Alice) {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.anchorBlockId = uint64(block.number - 1);

        inbox.proposeBatch(abi.encode(params), "txList");
    }

    function test_validateParams_reverts_when_timestamp_too_large() external transactBy(Alice) {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.lastBlockTimestamp = uint64(block.timestamp + 1);

        vm.expectRevert(ITaikoInbox.TimestampTooLarge.selector);
        inbox.proposeBatch(abi.encode(params), "txList");
    }

    function test_validateParams_reverts_when_first_block_time_shift_not_zero()
        external
        transactBy(Alice)
    {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.lastBlockTimestamp = uint64(block.timestamp);
        inbox.proposeBatch(abi.encode(params), "txList");

        params.lastBlockTimestamp = uint64(block.timestamp - 1);
        vm.expectRevert(ITaikoInbox.TimestampSmallerThanParent.selector);
        inbox.proposeBatch(abi.encode(params), "txList");

        params.blocks[0].timeShift = 1;
        params.lastBlockTimestamp = uint64(block.timestamp);
        vm.expectRevert(ITaikoInbox.FirstBlockTimeShiftNotZero.selector);
        inbox.proposeBatch(abi.encode(params), "txList");
    }

    function test_validateParams_reverts_when_timestamp_smaller_than_parent()
        external
        transactBy(Alice)
    {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](2);
        params.lastBlockTimestamp = uint64(block.timestamp);
        inbox.proposeBatch(abi.encode(params), "txList");

        params.lastBlockTimestamp = uint64(block.timestamp - 1);
        vm.expectRevert(ITaikoInbox.TimestampSmallerThanParent.selector);
        inbox.proposeBatch(abi.encode(params), "txList");

        params.blocks[1].timeShift = 1;
        params.lastBlockTimestamp = uint64(block.timestamp);
        vm.expectRevert(ITaikoInbox.TimestampSmallerThanParent.selector);
        inbox.proposeBatch(abi.encode(params), "txList");
    }
}
