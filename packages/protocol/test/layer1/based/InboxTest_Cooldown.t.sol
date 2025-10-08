// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ═══════════════════════════════════════════════════════════════════════
// DEPRECATED: This file is deprecated as of 2025-10-08.
// Please use the Shasta Inbox implementation instead.
// See: test/layer1/shasta/inbox/suite2/ for current tests
// ═══════════════════════════════════════════════════════════════════════

import "./InboxTestBase.sol";

contract InboxTest_Cooldownis is InboxTestBase {
    function v4GetConfig() internal pure override returns (ITaikoInbox.Config memory config_) {
        config_ = super.v4GetConfig();
        config_.cooldownWindow = 1 hours;
    }

    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_inbox_batches_cannot_verify_inside_cooldown_window()
        external
        WhenEachBatchHasMultipleBlocks(7)
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(9)
        WhenMultipleBatchesAreProvedWithCorrectTransitions(1, 10)
        WhenLogAllBatchesAndTransitions
    {
        // - All stats are correct and expected
        ITaikoInbox.Stats1 memory stats1 = inbox.v4GetStats1();
        assertEq(stats1.lastSyncedBatchId, 0);
        assertEq(stats1.lastSyncedAt, 0);

        ITaikoInbox.Stats2 memory stats2 = inbox.v4GetStats2();
        assertEq(stats2.numBatches, 10);
        assertEq(stats2.lastVerifiedBatchId, 0);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        vm.warp(block.timestamp + v4GetConfig().cooldownWindow);
        _proveBatchesWithWrongTransitions(range(1, 10));

        stats2 = inbox.v4GetStats2();
        assertEq(stats2.numBatches, 10);
        assertEq(stats2.lastVerifiedBatchId, 9);
    }
}
