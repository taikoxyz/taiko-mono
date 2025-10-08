// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ═══════════════════════════════════════════════════════════════════════
// DEPRECATED: This file is deprecated as of 2025-10-08.
// Please use the Shasta Inbox implementation instead.
// See: test/layer1/shasta/inbox/suite2/ for current tests
// ═══════════════════════════════════════════════════════════════════════

import "src/layer1/based/ITaikoInbox.sol";
import "test/layer1/Layer1Test.sol";
import "./InboxTestBase.sol";

contract InboxTest_ForkBoundaries is InboxTestBase {
    // Initial configuration with no fork restrictions (all set to 0)
    function v4GetConfigNoForks() internal pure returns (ITaikoInbox.Config memory) {
        ITaikoInbox.ForkHeights memory forkHeights = ITaikoInbox.ForkHeights({
            ontake: 0,
            pacaya: 0,
            shasta: 0, // No fork restrictions initially, to simulate reaching shasta
            unzen: 0,
            etna: 0,
            fuji: 0
        });

        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 100,
            batchRingBufferSize: 150,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 0,
            stateRootSyncInternal: 5,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000,
                maxGasIssuancePerBlock: 600_000_000
            }),
            provingWindow: 1 hours,
            cooldownWindow: 0 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: forkHeights
        });
    }

    // Upgraded configuration with shasta activated at block 101
    function v4GetConfigWithShasta() internal pure returns (ITaikoInbox.Config memory) {
        ITaikoInbox.ForkHeights memory forkHeights = ITaikoInbox.ForkHeights({
            ontake: 0,
            pacaya: 0,
            shasta: 101, // Shasta activates at block 101
            unzen: 134, // Unzen activates at block 134
            etna: 0,
            fuji: 0
        });

        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 100,
            batchRingBufferSize: 150,
            maxBatchesToVerify: 5,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 0,
            stateRootSyncInternal: 5,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000,
                maxGasIssuancePerBlock: 600_000_000
            }),
            provingWindow: 1 hours,
            cooldownWindow: 0 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: forkHeights
        });
    }

    function v4GetConfig() internal pure override returns (ITaikoInbox.Config memory) {
        return v4GetConfigNoForks();
    }

    function setUpOnEthereum() internal override {
        __blocksPerBatch = 5;

        genesisBlockProposedAt = block.timestamp;
        genesisBlockProposedIn = block.number;

        signalService = deploySignalService(address(new SignalService(address(resolver))));

        address verifierAddr = address(new Verifier_ToggleStub());
        resolver.registerAddress(block.chainid, "proof_verifier", verifierAddr);

        inbox = deployInbox(
            correctBlockhash(0), verifierAddr, address(0), address(signalService), v4GetConfig()
        );

        signalService.authorize(address(inbox), true);
        mineOneBlockAndWrap(12 seconds);
    }

    // Test batch proposal that would cross fork boundary (should fail)
    function test_firstBlockId_is_not_equal_to_fork_height_activation_fails() external {
        //vm.warp(1_000_000);

        // Step 1: Advance to block 99 with no fork restrictions (Shasta is activated at height 101)
        console2.log("=== Step 1: Advancing to block 99 with no fork restrictions ===");
        _advanceToBlockHeight(99);

        // Step 2: "Upgrade" the contract to activate shasta at block 101
        console2.log("=== Step 2: Upgrading contract to activate shasta at block 101 ===");
        _upgradeConfigAndActivateShastaFork();

        // Step 3: Try to propose a batch but firstBlockId is not equal to fork activation height
        console2.log("=== Step 3: Testing fork boundary - but ForkNotActivated ===");

        // Try to propose a batch with multiple blocks that would cross shasta fork boundary
        // This would span blocks 101-110, where block 101 should be the firstBlockId of a new batch
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](10); // 10 blocks: 101, 102, 103, 104, 105,
            // 106, 107, 108, 109, 110

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.ForkNotActivated.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    // Test batch proposal that would cross fork boundary (should fail)
    function test_firstBlockId_is_equal_to_fork_height_activation() external {
        // Step 1: Advance to block 100 with no fork restrictions (Shasta is activated at height
        // 101)
        console2.log("=== Step 1: Advancing to block 100 with no fork restrictions ===");
        _advanceToBlockHeight(100);

        // Step 2: "Upgrade" the contract to activate shasta at block 101
        console2.log("=== Step 2: Upgrading contract to activate shasta at block 101 ===");
        _upgradeConfigAndActivateShastaFork();

        // Step 3: Try to propose a batch that would cross the shasta fork boundary
        console2.log("=== Step 3: Testing fork boundary - but ForkNotActivated ===");

        // Try to propose a batch with multiple blocks that would cross shasta fork boundary
        // This would span blocks 101-110, where block 101 should be the firstBlockId of a new batch
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](10); // 10 blocks: 101, 102, 103, 104, 105,
            // 106, 107, 108, 109, 110

        vm.prank(Alice);
        //vm.expectRevert(ITaikoInbox.ForkNotActivated.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    // Test batch proposal that would cross fork boundary (should fail)
    function test_lastBlockId_is_higher_or_equal_to_fork_height_activation_fails() external {
        vm.warp(1_000_000);

        // Step 1: Advance to block 99 with no fork restrictions (Shasta is activated at height 101)
        console2.log("=== Step 1: Advancing to block 100 with no fork restrictions ===");
        _advanceToBlockHeight(100);

        // Step 2: "Upgrade" the contract to activate shasta at block 101
        console2.log("=== Step 2: Upgrading contract to activate shasta at block 101 ===");
        _upgradeConfigAndActivateShastaFork();

        // Step 3: Try to propose a batch but firstBlockId is not equal to fork activation height
        console2.log("=== Step 3: Testing fork boundary ===");

        console2.log("=== Step 4: Advancing to block 130, so 4 before unzen activation ===");
        _advanceToBlockHeight(130);

        console2.log(
            "=== Step 5: Try advancing 4 blocks, but lastBockId in batch is overindexing the activation height (equals to it, which is not allowed, firstBlockId has to be equal) ==="
        );
        // Try to propose a batch with multiple blocks that would cross shasta fork boundary
        // This would span blocks 101-110, where block 101 should be the firstBlockId of a new batch
        ITaikoInbox.BatchParams memory params;
        params.blocks = new ITaikoInbox.BlockParams[](4); // 4 blocks: 131, 132, 133, 134

        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.BeyondCurrentFork.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");

        console2.log("=== Step 6: Try advancing 3 blocks, that succeeds ===");
        params.blocks = new ITaikoInbox.BlockParams[](3); // 3 blocks: 131, 132, 133
        vm.prank(Alice);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");

        console2.log(
            "=== Reminder: Now we are at activation fork height, so proposing of blocks should be allowed ONLY IN CASE if with FORK_ROUTER we upgraded the contracts (new fork, MainnetInbox __getConfig() updated with the blockheight, etc.) ==="
        );
        params.blocks = new ITaikoInbox.BlockParams[](1); // 1 block: 134, not works because we
            // would need to upgrade the contracts to have different checks
        vm.prank(Alice);
        vm.expectRevert(ITaikoInbox.BeyondCurrentFork.selector);
        inbox.v4ProposeBatch(abi.encode(params), "txList", "");
    }

    // Helper function to "upgrade" the contract with shasta fork activation
    function _upgradeConfigAndActivateShastaFork() internal {
        ConfigurableInbox(address(inbox)).setConfig(v4GetConfigWithShasta());
        console2.log("Contract config updated, so shasta fork is activated, and live at block 101");
    }

    // Helper function to advance to specific block height
    function _advanceToBlockHeight(uint64 targetBlockHeight) internal {
        ITaikoInbox.Stats2 memory stats = inbox.v4GetStats2();

        uint64 currentBlockHeight = 0;
        if (stats.numBatches > 0) {
            ITaikoInbox.Batch memory lastBatch = inbox.v4GetBatch(stats.numBatches - 1);
            currentBlockHeight = lastBatch.lastBlockId;
        }

        if (targetBlockHeight <= currentBlockHeight) {
            return; // Already at or past target
        }

        uint64 blocksNeeded = targetBlockHeight - currentBlockHeight;

        // Propose batches with 5 blocks each to reach the target height
        while (blocksNeeded > 0) {
            uint64 blocksInThisBatch = blocksNeeded >= 5 ? 5 : blocksNeeded;

            ITaikoInbox.BatchParams memory params;
            params.blocks = new ITaikoInbox.BlockParams[](blocksInThisBatch);

            vm.prank(Alice);
            inbox.v4ProposeBatch(abi.encode(params), abi.encodePacked("advance_batch"), "");

            blocksNeeded -= blocksInThisBatch;
        }

        // Verify we reached the target
        stats = inbox.v4GetStats2();
        ITaikoInbox.Batch memory finalBatch = inbox.v4GetBatch(stats.numBatches - 1);
        console2.log("Advanced to block height:", finalBatch.lastBlockId);
    }
}
