// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import "src/layer1/based/TaikoInbox.sol";

/// @title InboxTest_LinkedProof
/// @notice Tests verification behavior with linked transitions and cooldown windows.
///
/// BUG BEING TESTED:
/// In _verifyBatches, when the loop breaks due to cooldown, `tid` has already been
/// assigned for the CURRENT batch, but it's then used to set `verifiedTransitionId`
/// for the PREVIOUS batch after the loop.
///
/// Scenario to expose the bug:
/// - Propose 2 batches (batch 1 and batch 2)
/// - Prove batch 1 with transition A->B
/// - Prove batch 2 with two transitions:
///   - First transition (tid=1): X->Y (not linkable)
///   - Second transition (tid=2): B->C (linkable)
/// - Wait for batch 1's cooldown to complete, but NOT batch 2's
/// - Trigger verification
/// - Expected (correct behavior): batch 1 verified with verifiedTransitionId=1
/// - Actual (buggy behavior): batch 1 verified with verifiedTransitionId=2 (WRONG!)
contract InboxTest_LinkedProof is InboxTestBase {
    function pacayaConfig() internal pure override returns (ITaikoInbox.Config memory) {
        ITaikoInbox.ForkHeights memory forkHeights;

        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 15,
            maxBatchesToVerify: 20,
            blockMaxGasLimit: 240_000_000,
            livenessBondBase: 125e18,
            livenessBondPerBlock: 0,
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
            cooldownWindow: 1 hours,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: forkHeights
        });
    }

    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function test_inbox_bug_wrong_tid_on_cooldown_break() external transactBy(Alice) {
        // This test exposes a bug in _verifyBatches:
        // When the loop breaks due to cooldown, `tid` has already been assigned for the
        // CURRENT batch, but after the loop it's used to set `verifiedTransitionId` for
        // the PREVIOUS (last verified) batch.
        //
        // Setup timeline:
        // 1. Propose batch 1
        // 2. Prove batch 1 with A->B (tid=1)
        // 3. Before A->B cooldown ends, propose batch 2
        // 4. Prove batch 2 with X->Y (tid=1), then B->C (tid=2)
        // 5. Wait for A->B cooldown to end, but X->Y and B->C still in cooldown
        // 6. Propose batch 3 to trigger verification
        //
        // Expected: batch 1 verified with verifiedTransitionId=1
        // Bug: batch 1 gets verifiedTransitionId=2 (from batch 2's linkable transition!)

        // Step 1: Propose batch 1
        _proposeBatchesWithDefaultParameters(1);

        // Step 2: Prove batch 1 with A->B (tid=1)
        {
            ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](1);
            ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](1);
            metas[0] = _loadMetadata(1);
            transitions[0].parentHash = correctBlockhash(0); // A (genesis)
            transitions[0].blockHash = correctBlockhash(1); // B
            transitions[0].stateRoot = correctStateRoot(1);
            inbox.proveBatches(abi.encode(metas, transitions), "proof");
        }

        // Record batch 1's transition createdAt time
        uint256 batch1ProveTime = block.timestamp;

        // Step 3: Before A->B cooldown ends, propose batch 2
        // Warp forward a bit but NOT past cooldown
        vm.warp(block.timestamp + pacayaConfig().cooldownWindow / 2);

        _proposeBatchesWithDefaultParameters(1); // batch 2

        // Step 4: Prove batch 2 with X->Y (tid=1), then B->C (tid=2)
        {
            ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](1);
            ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](1);
            metas[0] = _loadMetadata(2);
            transitions[0].parentHash = bytes32(uint256(0xDEAD)); // X (not linkable)
            transitions[0].blockHash = bytes32(uint256(0xBEEF)); // Y
            transitions[0].stateRoot = bytes32(uint256(0xCAFE));
            inbox.proveBatches(abi.encode(metas, transitions), "proof");
        }
        {
            ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](1);
            ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](1);
            metas[0] = _loadMetadata(2);
            transitions[0].parentHash = correctBlockhash(1); // B (linkable to batch 1)
            transitions[0].blockHash = correctBlockhash(2); // C
            transitions[0].stateRoot = correctStateRoot(2);
            inbox.proveBatches(abi.encode(metas, transitions), "proof");
        }

        // Verify batch 2 has 2 transitions (nextTransitionId = 3)
        ITaikoInbox.Batch memory batch2 = inbox.getBatch(2);
        assertEq(batch2.nextTransitionId, 3, "Batch 2 should have 2 transitions");

        // Verify nothing is verified yet
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 0, "Nothing verified yet");

        // Step 5: Wait for batch 1's A->B cooldown to end
        // But batch 2's transitions (created at cooldown/2) are still in cooldown
        // Batch 1's transition was created at batch1ProveTime
        // We need: now > batch1ProveTime + cooldown, but now < batch2ProveTime + cooldown
        vm.warp(batch1ProveTime + pacayaConfig().cooldownWindow + 1);

        // At this point:
        // - Batch 1's A->B: createdAt = batch1ProveTime, cooldown DONE
        // - Batch 2's X->Y and B->C: createdAt = batch1ProveTime + cooldown/2, cooldown NOT done

        // Step 6: Propose batch 3 to trigger verification
        _proposeBatchesWithDefaultParameters(1);

        _logAllBatchesAndTransitions();

        // Step 7: Check results
        stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1, "Only batch 1 should be verified");

        ITaikoInbox.Batch memory batch1 = inbox.getBatch(1);
        // BUG CHECK: batch 1's verifiedTransitionId should be 1, NOT 2!
        // The loop processes batch 1 (tid=1), then batch 2 (finds linkable tid=2),
        // but batch 2's cooldown fails, so it breaks.
        // After break: batchId is decremented to 1
        // BUG: batch.verifiedTransitionId = tid writes tid=2 to batch 1!
        assertEq(batch1.verifiedTransitionId, 1, "Batch 1 should have verifiedTransitionId=1, NOT 2!");

        batch2 = inbox.getBatch(2);
        assertEq(batch2.verifiedTransitionId, 0, "Batch 2 should not be verified yet");
    }

    function test_inbox_linked_proof_verified_after_cooldown() external transactBy(Alice) {
        // This test verifies that batch 2 CAN be verified once its cooldown passes
        // using the linkable transition (B->C)

        // Step 1: Propose 2 batches
        _proposeBatchesWithDefaultParameters(2);

        // Step 2: Prove batch 1 with transition A->B
        {
            ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](1);
            ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](1);

            metas[0] = _loadMetadata(1);
            transitions[0].parentHash = correctBlockhash(0);
            transitions[0].blockHash = correctBlockhash(1);
            transitions[0].stateRoot = correctStateRoot(1);

            inbox.proveBatches(abi.encode(metas, transitions), "proof");
        }

        // Step 3: Wait for batch 1's cooldown
        vm.warp(block.timestamp + pacayaConfig().cooldownWindow + 1);

        // Step 4: Prove batch 2 with two transitions (both in new cooldown window)
        // First: X->Y (not linkable)
        {
            ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](1);
            ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](1);

            metas[0] = _loadMetadata(2);
            transitions[0].parentHash = bytes32(uint256(0xDEAD));
            transitions[0].blockHash = bytes32(uint256(0xBEEF));
            transitions[0].stateRoot = bytes32(uint256(0xCAFE));

            inbox.proveBatches(abi.encode(metas, transitions), "proof");
        }

        // Second: B->C (linkable)
        {
            ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](1);
            ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](1);

            metas[0] = _loadMetadata(2);
            transitions[0].parentHash = correctBlockhash(1);
            transitions[0].blockHash = correctBlockhash(2);
            transitions[0].stateRoot = correctStateRoot(2);

            inbox.proveBatches(abi.encode(metas, transitions), "proof");
        }

        // Trigger verification - only batch 1 should verify (batch 2 in cooldown)
        TaikoInbox(address(inbox)).verifyBatches(1);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);

        // Step 5: Wait for batch 2's cooldown to complete
        vm.warp(block.timestamp + pacayaConfig().cooldownWindow + 1);

        // Step 6: Trigger verification again
        TaikoInbox(address(inbox)).verifyBatches(1);

        _logAllBatchesAndTransitions();

        // Now batch 2 should be verified using the linkable transition (tid=2)
        stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 2, "Batch 2 should now be verified");

        ITaikoInbox.Batch memory batch2 = inbox.getBatch(2);
        assertEq(
            batch2.verifiedTransitionId, 2, "Batch 2 should be verified with tid=2 (the linkable transition B->C)"
        );
    }
}
