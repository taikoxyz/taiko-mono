// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ═══════════════════════════════════════════════════════════════════════
// DEPRECATED: This file is deprecated as of 2025-10-08.
// Please use the Shasta Inbox implementation instead.
// See: test/layer1/shasta/inbox/suite2/ for current tests
// ═══════════════════════════════════════════════════════════════════════

import "./InboxTestBase.sol";

contract InboxTest_Params is InboxTestBase {
    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_validateParams_defaults_when_anchorBlockId_is_zero() external transactBy(Alice) {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);

        (ITaikoInbox.BatchInfo memory info,) =
            inbox.v4ProposeBatch(abi.encode(params), "txList", "");

        // Assert that the default anchorBlockId was set correctly
        uint64 expectedAnchorBlockId = uint64(block.number - 1);
        assertEq(info.anchorBlockId, expectedAnchorBlockId, "AnchorBlockId mismatch");
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
        params.anchorBlockId = uint64(block.number - config.maxAnchorHeightOffset - 1);

        vm.expectRevert(ITaikoInbox.AnchorBlockIdTooSmall.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
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
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    function test_validateParams_reverts_when_anchorBlockId_smaller_than_parent()
        external
        transactBy(Alice)
    {
        vm.roll(10);
        _proposeBatchesWithDefaultParameters(1);
        ITaikoInbox.Batch memory parent = inbox.v4GetBatch(1);

        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.anchorBlockId = parent.anchorBlockId - 1;

        vm.expectRevert(ITaikoInbox.AnchorBlockIdSmallerThanParent.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    function test_validateParams_when_anchorBlockId_is_not_zero() external transactBy(Alice) {
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](1);
        params.anchorBlockId = uint64(block.number - 1);

        (ITaikoInbox.BatchInfo memory info,) =
            inbox.v4ProposeBatch(abi.encode(params), "txList", "");

        uint64 expectedAnchorBlockId = uint64(block.number - 1);
        assertEq(info.anchorBlockId, expectedAnchorBlockId, "AnchorBlockId mismatch");
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
