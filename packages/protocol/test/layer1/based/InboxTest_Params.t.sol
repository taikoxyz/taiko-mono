// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";

contract InboxTest_Params is InboxTestBase {
    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_validateParams_defaults_when_anchorBlockId_is_not_set()
        external
        transactBy(Alice)
    {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);

        // It should revert, because no anchorBlockId is set
        vm.expectRevert(ITaikoInbox.NoAnchorBlockIdWithinThisBatch.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    function test_validateParams_reverts_when_anchorBlockId_too_small()
        external
        transactBy(Alice)
    {
        ITaikoInbox.Config memory config = inbox.v4GetConfig();

        // Advance the block number to create the appropriate test scenario
        vm.roll(config.maxAnchorHeightOffset + 2);

        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        // Calculate an invalid anchorBlockId (too small)
        params.blocks[0].anchorBlockId = uint64(block.number - config.maxAnchorHeightOffset - 1);

        vm.expectRevert(ITaikoInbox.AnchorBlockIdTooLarge.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    function test_validateParams_reverts_when_anchorBlockId_too_large()
        external
        transactBy(Alice)
    {
        ITaikoInbox.Config memory config = inbox.v4GetConfig();
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        // Calculate an invalid anchorBlockId (too large)
        params.blocks[0].anchorBlockId = uint64(block.number);
        // roll into the future to make blockhash(uint64(block.number)) available
        vm.roll(block.number + config.maxAnchorHeightOffset + 1);

        vm.expectRevert(ITaikoInbox.AnchorBlockIdTooLarge.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    function test_validateParams_reverts_when_anchorBlockId_smaller_than_parent()
        external
        transactBy(Alice)
    {
        vm.roll(10);
        _proposeBatchesWithDefaultParameters(1);
        ITaikoInbox.Batch memory parent = inbox.v4GetBatch(1);

        ITaikoInbox.BlockParams[] memory blocks = new ITaikoInbox.BlockParams[](1);
        blocks[0] = ITaikoInbox.BlockParams({
            numTransactions: 0,
            timeShift: 0,
            signalSlots: new bytes32[](0),
            anchorBlockId: 0
        });

        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.blocks[0].anchorBlockId = parent.anchorBlockId - 1;

        vm.expectRevert(ITaikoInbox.AnchorBlockIdSmallerThanParent.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    function test_validateParams_reverts_when_timestamp_too_large() external transactBy(Alice) {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.lastBlockTimestamp = uint64(block.timestamp + 1);

        vm.expectRevert(ITaikoInbox.TimestampTooLarge.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    function test_validateParams_reverts_when_first_block_time_shift_not_zero()
        external
        transactBy(Alice)
    {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.lastBlockTimestamp = uint64(block.timestamp);
        params.blocks[0].anchorBlockId = uint64(block.number);
        vm.roll(block.number + 1);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");

        params.lastBlockTimestamp = uint64(block.timestamp - 1);
        vm.expectRevert(ITaikoInbox.TimestampSmallerThanParent.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");

        params.blocks[0].timeShift = 1;
        params.lastBlockTimestamp = uint64(block.timestamp);
        vm.expectRevert(ITaikoInbox.FirstBlockTimeShiftNotZero.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    function test_validateParams_reverts_when_timestamp_smaller_than_parent()
        external
        transactBy(Alice)
    {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](2);
        params.lastBlockTimestamp = uint64(block.timestamp);
        params.blocks[0].anchorBlockId = uint64(block.number);
        vm.roll(block.number + 1);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");

        params.lastBlockTimestamp = uint64(block.timestamp - 1);
        vm.expectRevert(ITaikoInbox.TimestampSmallerThanParent.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");

        params.blocks[1].timeShift = 1;
        params.lastBlockTimestamp = uint64(block.timestamp);
        vm.expectRevert(ITaikoInbox.TimestampSmallerThanParent.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }
}
