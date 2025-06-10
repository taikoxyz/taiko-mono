// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";
import "./helpers/ProofTypeFixtures.sol";

contract InboxTest_FinalityGadget is InboxTestBase, ProofTypeFixtures {
    using LibProofType for LibProofType.ProofType;

    function pacayaConfig() internal pure override returns (ITaikoInbox.Config memory) {
        ITaikoInbox.ForkHeights memory forkHeights;

        return ITaikoInbox.Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            maxUnverifiedBatches: 10,
            batchRingBufferSize: 11,
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
            cooldownWindow: 7 days,
            maxSignalsToReceive: 16,
            maxBlocksPerBatch: 768,
            forkHeights: forkHeights,
            // Surge: to prevent compilation errors
            maxVerificationDelay: 0
        });
    }

    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    // --------------------------------------------------------------------------------------------
    // Happy cases
    // --------------------------------------------------------------------------------------------

    // ZK + TEE
    // --------

    function test_inbox_batch_is_finalised_immediately_with_ZK_TEE_proof(uint256 _zkTeeIndex)
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkTeeProofType = _getZkTeeProofType(_zkTeeIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Batch is not finalised yet
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 0);

        // Prove using ZK + TEE proof type
        _proveBatchesWithProofType(zkTeeProofType, batchIds);

        // The batch is now finalised
        stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
    }

    // ZK followed by TEE
    // --------------------

    function test_inbox_batch_is_finalised_when_ZK_proof_is_followed_by_matching_TEE_proof(
        uint256 _zkIndex,
        uint256 _teeIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkProofType = _getZkProofType(_zkIndex);
        LibProofType.ProofType teeProofType = _getTeeProofType(_teeIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using ZK proof type
        _proveBatchesWithProofType(zkProofType, batchIds);

        // The batch is not finalised yet
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 0);
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(zkProofType));

        // Prove using TEE proof type
        _proveBatchesWithProofType(teeProofType, batchIds);

        // The batch is now finalised
        stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, proof type is updated to ZK + TEE
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(zkProofType.combine(teeProofType)));
    }

    // TEE followed by ZK
    // --------------------

    function test_inbox_batch_is_finalised_when_TEE_proof_is_followed_by_matching_ZK_proof(
        uint256 _teeIndex,
        uint256 _zkIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType teeProofType = _getTeeProofType(_teeIndex);
        LibProofType.ProofType zkProofType = _getZkProofType(_zkIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using TEE proof type
        _proveBatchesWithProofType(teeProofType, batchIds);

        // The batch is not finalised yet
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 0);
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType));

        // Prove using ZK proof type
        _proveBatchesWithProofType(zkProofType, batchIds);

        // The batch is now finalised
        stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, proof type is updated to ZK + TEE
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType.combine(zkProofType)));
    }

    // Misc
    // ----

    function test_inbox_sender_of_the_matching_proof_becomes_bond_receiver(
        uint256 _zkIndex,
        uint256 _teeIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkProofType = _getZkProofType(_zkIndex);
        LibProofType.ProofType teeProofType = _getTeeProofType(_teeIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Alice proves the batch using ZK proof type
        _proveBatchesWithProofType(zkProofType, batchIds);

        // Bob proves the batch using matching TEE proof type
        vm.startPrank(Bob);
        _proveBatchesWithProofType(teeProofType, batchIds);
        vm.stopPrank();

        // The batch is now finalised
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, bond receiver is updated to Bob
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions[0].bondReceiver, Bob);
    }

    function test_inbox_skips_reproving_transition_when_both_existing_and_new_proof_types_are_ZK(
        uint256 _zkIndex1,
        uint256 _zkIndex2
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        vm.assume(_zkIndex1 != _zkIndex2);
        LibProofType.ProofType zkProofType1 = _getZkProofType(_zkIndex1);
        LibProofType.ProofType zkProofType2 = _getZkProofType(_zkIndex2);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using ZK proof type 1
        _proveBatchesWithProofType(zkProofType1, batchIds);

        // Proof type is set to ZK proof type 1
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(zkProofType1));

        // Prove using ZK proof type 2
        _proveBatchesWithProofType(zkProofType2, batchIds);

        // Proof type is still ZK proof type 1, signaling that proving was skipped
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(zkProofType1));
    }

    function test_inbox_skips_reproving_transition_when_both_existing_and_new_proof_types_are_TEE(
        uint256 _teeIndex1,
        uint256 _teeIndex2
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        vm.assume(_teeIndex1 != _teeIndex2);
        LibProofType.ProofType teeProofType1 = _getTeeProofType(_teeIndex1);
        LibProofType.ProofType teeProofType2 = _getTeeProofType(_teeIndex2);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using TEE proof type 1
        _proveBatchesWithProofType(teeProofType1, batchIds);

        // Proof type is set to TEE proof type 1
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType1));

        // Prove using TEE proof type 2
        _proveBatchesWithProofType(teeProofType2, batchIds);

        // Proof type is still TEE proof type 1, signaling that proving was skipped
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType1));
    }

    // --------------------------------------------------------------------------------------------
    // Conflicting transition cases
    // --------------------------------------------------------------------------------------------

    // Conflicts with existing ZK proven transition
    // ----------------------------------------------

    function test_inbox_push_conflicting_ZK_transition_for_existing_ZK_transition(
        uint256 _zkIndex1,
        uint256 _zkIndex2
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkProofType1 = _getZkProofType(_zkIndex1);
        LibProofType.ProofType zkProofType2 = _getZkProofType(_zkIndex2);

        vm.assume(_zkIndex1 != _zkIndex2);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using ZK proof type 1
        _proveBatchesWithProofType(zkProofType1, batchIds);

        // The transition has no conflicts yet
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(zkProofType1));
        assertEq(transitions.length, 1); // No conflicts
        assertEq(transitions[0].createdAt, block.timestamp);

        vm.warp(block.timestamp + 2);

        // Push a conflicting transition of ZK proof type 2
        _pushConflictingTransition(zkProofType2, batchIds);

        // The transition now has a conflicting transition of ZK proof type 2
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions.length, 2); // 1 conflict
        assertEq(transitions[1].blockHash, conflictingBlockHash(1));
        assertTrue(transitions[1].proofType.equals(zkProofType2));
    }

    function test_inbox_batch_is_finalised_when_conflicting_ZK_TEE_transition_is_pushed_for_existing_ZK_transition(
        uint256 _zkIndex,
        uint256 _zkTeeIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkProofType = _getZkProofType(_zkIndex);
        LibProofType.ProofType zkTeeProofType = _getZkTeeProofType(_zkTeeIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using ZK proof type
        _proveBatchesWithProofType(zkProofType, batchIds);

        // The transition has no conflicts yet
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(zkProofType));
        assertEq(transitions.length, 1); // No conflicts
        assertEq(transitions[0].createdAt, block.timestamp);

        vm.warp(block.timestamp + 2);

        // Push a conflicting transition of ZK + TEE proof type
        _pushConflictingTransition(zkTeeProofType, batchIds);

        // The transition now has a conflicting transition of ZK + TEE proof type
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions.length, 2); // 1 conflict
        assertEq(transitions[1].blockHash, conflictingBlockHash(1));
        assertTrue(transitions[1].proofType.equals(zkTeeProofType));

        // The batch is now finalised
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, finalising transition index is updated to 1
        ITaikoInbox.Batch memory batch = inbox.getBatch(1);
        assertEq(batch.finalisingTransitionIndex, 1);
    }

    function test_inbox_batch_is_finalised_when_conflicting_ZK_transition_gets_matching_TEE_transition(
        uint256 _zkIndex1,
        uint256 _zkIndex2,
        uint256 _teeIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkProofType1 = _getZkProofType(_zkIndex1);
        LibProofType.ProofType zkProofType2 = _getZkProofType(_zkIndex2);
        LibProofType.ProofType teeProofType = _getTeeProofType(_teeIndex);

        vm.assume(_zkIndex1 != _zkIndex2);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using ZK proof type 1
        _proveBatchesWithProofType(zkProofType1, batchIds);

        vm.warp(block.timestamp + 2);

        // Push a conflicting transition of ZK proof type 2
        _pushConflictingTransition(zkProofType2, batchIds);

        // The transition now has a conflicting transition of ZK proof type 2
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions.length, 2); // 1 conflict
        assertEq(transitions[1].blockHash, conflictingBlockHash(1));
        assertTrue(transitions[1].proofType.equals(zkProofType2));
        // But the batch is not finalised yet
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 0);

        // Push a matching transition of TEE proof type
        _pushConflictingTransition(teeProofType, batchIds);

        // The batch is now finalised
        stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, finalising transition's proof type is updated to ZK + TEE
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[1].proofType.equals(zkProofType2.combine(teeProofType)));
        // and, finalising transition index is updated to 1
        ITaikoInbox.Batch memory batch = inbox.getBatch(1);
        assertEq(batch.finalisingTransitionIndex, 1);
    }

    function test_inbox_sender_becomes_bond_receiver_when_conflicting_ZK_TEE_transition_is_pushed_for_existing_ZK_transition(
        uint256 _zkIndex,
        uint256 _zkTeeIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkProofType = _getZkProofType(_zkIndex);
        LibProofType.ProofType zkTeeProofType = _getZkTeeProofType(_zkTeeIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using ZK proof type
        _proveBatchesWithProofType(zkProofType, batchIds);

        // The transition has no conflicts yet
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(zkProofType));
        assertEq(transitions.length, 1); // No conflicts

        vm.warp(block.timestamp + 2);

        // Push a conflicting transition of ZK + TEE proof type
        vm.startPrank(Bob);
        _pushConflictingTransition(zkTeeProofType, batchIds);
        vm.stopPrank();

        // The transition now has a conflicting transition of ZK + TEE proof type
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions.length, 2); // 1 conflict
        assertEq(transitions[1].blockHash, conflictingBlockHash(1));
        assertTrue(transitions[1].proofType.equals(zkTeeProofType));
        // and, bond receiver is updated to Bob
        assertEq(transitions[1].bondReceiver, Bob);
    }

    // Conflicts with existing TEE proven transition
    // ----------------------------------------------

    function test_inbox_push_conflicting_TEE_transition_for_existing_TEE_transition(
        uint256 _teeIndex1,
        uint256 _teeIndex2
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType teeProofType1 = _getTeeProofType(_teeIndex1);
        LibProofType.ProofType teeProofType2 = _getTeeProofType(_teeIndex2);

        vm.assume(_teeIndex1 != _teeIndex2);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using TEE proof type 1
        _proveBatchesWithProofType(teeProofType1, batchIds);

        // The transition has no conflicts yet
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType1));
        assertEq(transitions.length, 1); // No conflicts

        vm.warp(block.timestamp + 2);

        // Push a conflicting transition of TEE proof type 2
        _pushConflictingTransition(teeProofType2, batchIds);

        // The transition now has a conflicting transition of TEE proof type 2
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions.length, 2); // 1 conflict
        assertEq(transitions[1].blockHash, conflictingBlockHash(1));
        assertTrue(transitions[1].proofType.equals(teeProofType2));
    }

    function test_inbox_push_conflicting_ZK_transition_for_existing_TEE_transition(
        uint256 _teeIndex,
        uint256 _zkIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType teeProofType = _getTeeProofType(_teeIndex);
        LibProofType.ProofType zkProofType = _getZkProofType(_zkIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using TEE proof type
        _proveBatchesWithProofType(teeProofType, batchIds);

        // The transition has no conflicts yet
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType));
        assertEq(transitions.length, 1); // No conflicts

        vm.warp(block.timestamp + 2);

        // Push a conflicting transition of ZK proof type
        _pushConflictingTransition(zkProofType, batchIds);

        // The transition now has a conflicting transition of ZK proof type
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions.length, 2); // 1 conflict
        assertEq(transitions[1].blockHash, conflictingBlockHash(1));
        assertTrue(transitions[1].proofType.equals(zkProofType));
    }

    function test_inbox_batch_is_finalised_when_conflicting_ZK_TEE_transition_is_pushed_for_existing_TEE_transition(
        uint256 _teeIndex,
        uint256 _zkTeeIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType teeProofType = _getTeeProofType(_teeIndex);
        LibProofType.ProofType zkTeeProofType = _getZkTeeProofType(_zkTeeIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using TEE proof type
        _proveBatchesWithProofType(teeProofType, batchIds);

        // The transition has no conflicts yet
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType));
        assertEq(transitions.length, 1); // No conflicts

        vm.warp(block.timestamp + 2);

        // Push a conflicting transition of ZK + TEE proof type
        _pushConflictingTransition(zkTeeProofType, batchIds);

        // The transition now has a conflicting transition of ZK + TEE proof type
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions.length, 2); // 1 conflict
        assertEq(transitions[1].blockHash, conflictingBlockHash(1));
        assertTrue(transitions[1].proofType.equals(zkTeeProofType));
        // and, batch is finalised
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, finalising transition index is updated to 1
        ITaikoInbox.Batch memory batch = inbox.getBatch(1);
        assertEq(batch.finalisingTransitionIndex, 1);
    }

    function test_inbox_batch_is_finalised_when_conflicting_TEE_transition_gets_matching_ZK_transition(
        uint256 _teeIndex1,
        uint256 _teeIndex2,
        uint256 _zkIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType teeProofType1 = _getTeeProofType(_teeIndex1);
        LibProofType.ProofType teeProofType2 = _getTeeProofType(_teeIndex2);
        LibProofType.ProofType zkProofType = _getZkProofType(_zkIndex);

        vm.assume(_teeIndex1 != _teeIndex2);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using TEE proof type 1
        _proveBatchesWithProofType(teeProofType1, batchIds);

        vm.warp(block.timestamp + 2);

        // Push a conflicting transition of TEE proof type 2
        _pushConflictingTransition(teeProofType2, batchIds);

        // The transition now has a conflicting transition of TEE proof type 2
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions.length, 2); // 1 conflict
        assertEq(transitions[1].blockHash, conflictingBlockHash(1));
        assertTrue(transitions[1].proofType.equals(teeProofType2));
        // but not finalised yet
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 0);

        // Push a matching transition of ZK proof type
        _pushConflictingTransition(zkProofType, batchIds);

        // The batch is now finalised
        stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, finalising transition's proof type is updated to ZK + TEE
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[1].proofType.equals(zkProofType.combine(teeProofType2)));
        // and, finalising transition index is updated to 1
        ITaikoInbox.Batch memory batch = inbox.getBatch(1);
        assertEq(batch.finalisingTransitionIndex, 1);
    }

    function test_inbox_sender_becomes_bond_receiver_when_conflicting_ZK_TEE_transition_is_pushed_for_existing_TEE_transition(
        uint256 _teeIndex,
        uint256 _zkTeeIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType teeProofType = _getTeeProofType(_teeIndex);
        LibProofType.ProofType zkTeeProofType = _getZkTeeProofType(_zkTeeIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using TEE proof type
        _proveBatchesWithProofType(teeProofType, batchIds);

        // The transition has no conflicts yet
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType));
        assertEq(transitions.length, 1); // No conflicts

        vm.warp(block.timestamp + 2);

        // Push a conflicting transition of ZK + TEE proof type
        vm.startPrank(Bob);
        _pushConflictingTransition(zkTeeProofType, batchIds);
        vm.stopPrank();

        // The transition now has a conflicting transition of ZK + TEE proof type
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions.length, 2); // 1 conflict
        assertEq(transitions[1].blockHash, conflictingBlockHash(1));
        assertTrue(transitions[1].proofType.equals(zkTeeProofType));
        // and, bond receiver is updated to Bob
        assertEq(transitions[1].bondReceiver, Bob);
        // and, finalising transition index is updated to 1
        ITaikoInbox.Batch memory batch = inbox.getBatch(1);
        assertEq(batch.finalisingTransitionIndex, 1);
    }

    // ----------------------------------------------------------
    // Cooldown Period
    // ----------------------------------------------------------

    function test_inbox_batch_is_finalised_when_existing_ZK_transition_has_no_conflicts_within_cooldown_period(
        uint256 _zkIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkProofType = _getZkProofType(_zkIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using ZK proof type
        _proveBatchesWithProofType(zkProofType, batchIds);

        // The batch has no conflicts yet
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(zkProofType));
        assertEq(transitions.length, 1); // No conflicts

        // Warp time to just before the cooldown period ends
        vm.warp(block.timestamp + pacayaConfig().cooldownWindow - 1);

        // Attempt to finalise
        inbox.verifyBatches(1);

        // The batch should still not be finalised
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 0);

        // Warp time to after the cooldown period ends
        vm.warp(block.timestamp + 2);

        // Attempt to finalise again
        inbox.verifyBatches(1);

        // The batch should now be finalised
        stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, proof type remains ZK as no conflicting transition was pushed
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(zkProofType));
        assertEq(transitions.length, 1); // No conflicts
    }

    function test_inbox_batch_is_finalised_when_existing_TEE_transition_has_no_conflicts_within_cooldown_period(
        uint256 _teeIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType teeProofType = _getTeeProofType(_teeIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using TEE proof type
        _proveBatchesWithProofType(teeProofType, batchIds);

        // The transition has no conflicts yet
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType));
        assertEq(transitions.length, 1); // No conflicts

        // Warp time to just before the cooldown period ends
        vm.warp(block.timestamp + pacayaConfig().cooldownWindow - 1);

        // Attempt to finalise
        inbox.verifyBatches(1);

        // The batch should still not be finalised
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 0);

        // Warp time to after the cooldown period ends
        vm.warp(block.timestamp + 2);

        // Attempt to finalise again
        inbox.verifyBatches(1);

        // The batch should now be finalised
        stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, proof type remains TEE as no conflicting transition was pushed
        transitions = inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType));
        assertEq(transitions.length, 1); // No conflicts
    }

    function test_inbox_dao_receives_liveness_bond_when_ZK_transition_is_finalised_via_cooldown_period(
        uint256 _zkIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkProofType = _getZkProofType(_zkIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using ZK proof type
        _proveBatchesWithProofType(zkProofType, batchIds);

        // Warp time to after the cooldown period ends
        vm.warp(block.timestamp + pacayaConfig().cooldownWindow + 1);

        // Attempt to finalise
        inbox.verifyBatches(1);

        // The batch should now be finalised
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, proof type remains ZK as no conflicting transition was pushed
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(zkProofType));
        assertEq(transitions.length, 1); // No conflicts
        // and, liveness bond is sent to DAO
        assertEq(
            inbox.bondBalanceOf(TaikoInbox(address(inbox)).dao()), pacayaConfig().livenessBondBase
        );
    }

    function test_inbox_dao_receives_liveness_bond_when_TEE_transition_is_finalised_via_cooldown_period(
        uint256 _teeIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType teeProofType = _getTeeProofType(_teeIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using TEE proof type
        _proveBatchesWithProofType(teeProofType, batchIds);

        // Warp time to after the cooldown period ends
        vm.warp(block.timestamp + pacayaConfig().cooldownWindow + 1);

        // Attempt to finalise
        inbox.verifyBatches(1);

        // The batch should now be finalised
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // and, proof type remains TEE as no conflicting transition was pushed
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertTrue(transitions[0].proofType.equals(teeProofType));
        assertEq(transitions.length, 1); // No conflicts
        // and, liveness bond is sent to DAO
        assertEq(
            inbox.bondBalanceOf(TaikoInbox(address(inbox)).dao()), pacayaConfig().livenessBondBase
        );
    }

    function test_inbox_batch_cannot_be_finalised_via_cooldown_period_if_there_are_conflicting_transitions(
        uint256 _zkIndex,
        uint256 _teeIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkProofType = _getZkProofType(_zkIndex);
        LibProofType.ProofType teeProofType = _getTeeProofType(_teeIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Prove using TEE proof type
        _proveBatchesWithProofType(teeProofType, batchIds);

        // Push a conflicting transition of ZK proof type
        _pushConflictingTransition(zkProofType, batchIds);

        // Warp time to after the cooldown period ends
        vm.warp(block.timestamp + pacayaConfig().cooldownWindow + 1);

        // Attempt to finalise
        inbox.verifyBatches(1);

        // The batch should still not be finalised
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 0);
    }

    // ----------------------------------------------------------
    // Verifier Upgradeability
    // ----------------------------------------------------------

    function test_inbox_proof_verifiers_of_conflicting_transitions_are_marked_for_upgrade(
        uint256 _zkTeeIndex,
        uint256 _teeIndex,
        uint256 _zkIndex
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
    {
        LibProofType.ProofType zkTeeProofType = _getZkTeeProofType(_zkTeeIndex);
        LibProofType.ProofType teeConflictingProofType = _getTeeProofType(_teeIndex);
        LibProofType.ProofType zkConflictingProofType = _getZkProofType(_zkIndex);

        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;

        // Push a conflicting transition of TEE proof type with salt 1
        _pushConflictingTransition(teeConflictingProofType, batchIds, 1);

        // Push a conflicting transition of ZK proof type with salt 2
        _pushConflictingTransition(zkConflictingProofType, batchIds, 2);

        // Push finalising transition of ZK + TEE proof type
        _proveBatchesWithProofType(zkTeeProofType, batchIds);

        // The batch is now finalised
        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.lastVerifiedBatchId, 1);
        // but, it contains 2 conflicting transitions
        ITaikoInbox.TransitionState[] memory transitions =
            inbox.getTransitionsByParentHash(1, correctBlockhash(0));
        assertEq(transitions.length, 3); // 2 conflicts
        assertTrue(transitions[0].proofType.equals(teeConflictingProofType));
        assertTrue(transitions[1].proofType.equals(zkConflictingProofType));
        // and, the finalising transition i.e is of ZK + TEE proof type
        assertTrue(transitions[2].proofType.equals(zkTeeProofType));
        // and, finalising transition index is updated to 2
        ITaikoInbox.Batch memory batch = inbox.getBatch(1);
        assertEq(batch.finalisingTransitionIndex, 2);
        // and, conflicting ZK + conflicting TEE verifier is upgradeable
        assertTrue(
            verifier.proofTypeToUpgrade().equals(
                zkConflictingProofType.combine(teeConflictingProofType)
            )
        );
    }

    // Local helpers
    // -------------

    function _getZkTeeProofType(uint256 _index) internal view returns (LibProofType.ProofType) {
        _index = bound(_index, 0, zkTeeProofTypes.length - 1);
        return zkTeeProofTypes[_index];
    }

    function _getTeeProofType(uint256 _index) internal view returns (LibProofType.ProofType) {
        _index = bound(_index, 0, teeProofTypes.length - 1);
        return teeProofTypes[_index];
    }

    function _getZkProofType(uint256 _index) internal view returns (LibProofType.ProofType) {
        _index = bound(_index, 0, zkProofTypes.length - 1);
        return zkProofTypes[_index];
    }
}
