// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./InboxTestBase.sol";

contract InboxTest_ProposeAndProve is InboxTestBase {
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

    function test_inbox_query_right_after_genesis_batch() external view {
        // - All stats are correct and expected
        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        assertEq(stats1.lastSyncedBatchId, 0);
        assertEq(stats1.lastSyncedAt, 0);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.numBatches, 1);
        assertEq(stats2.lastVerifiedBatchId, 0);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, genesisBlockProposedIn);
        assertEq(stats2.lastUnpausedAt, 0);

        // - Verify genesis block
        ITaikoInbox.Batch memory batch = inbox.getBatch(0);
        assertEq(batch.batchId, 0);
        assertEq(batch.metaHash, bytes32(uint256(1)));
        assertEq(batch.lastBlockTimestamp, genesisBlockProposedAt);
        assertEq(batch.anchorBlockId, genesisBlockProposedIn);
        assertEq(batch.nextTransitionId, 2);
        assertEq(batch.verifiedTransitionId, 1);

        (uint64 batchId, uint64 blockId, ITaikoInbox.TransitionState memory ts) =
            inbox.getLastVerifiedTransition();
        assertEq(batchId, 0);
        assertEq(blockId, 0);
        assertEq(ts.blockHash, correctBlockhash(0));
        assertEq(ts.stateRoot, bytes32(uint256(0)));

        (batchId, blockId, ts) = inbox.getLastSyncedTransition();
        assertEq(batchId, 0);
        assertEq(blockId, 0);
        assertEq(ts.blockHash, correctBlockhash(0));
        assertEq(ts.stateRoot, bytes32(uint256(0)));
    }

    function test_inbox_query_batches_not_exist_will_revert() external {
        vm.expectRevert(ITaikoInbox.BatchNotFound.selector);
        inbox.getBatch(1);
    }

    function test_inbox_max_batch_proposal()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(10)
        WhenLogAllBatchesAndTransitions
    {
        // - All stats are correct and expected

        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        assertEq(stats1.lastSyncedBatchId, 0);
        assertEq(stats1.lastSyncedAt, 0);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.numBatches, 11);
        assertEq(stats2.lastVerifiedBatchId, 0);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        // - Verify genesis block
        ITaikoInbox.Batch memory batch = inbox.getBatch(0);
        assertEq(batch.batchId, 0);
        assertEq(batch.metaHash, bytes32(uint256(1)));
        assertEq(batch.lastBlockTimestamp, genesisBlockProposedAt);
        assertEq(batch.anchorBlockId, genesisBlockProposedIn);
        assertEq(batch.nextTransitionId, 2);
        assertEq(batch.verifiedTransitionId, 1);

        // Verify block data
        for (uint64 i = 1; i <= 10; ++i) {
            batch = inbox.getBatch(i);
            assertEq(batch.batchId, i);

            ITaikoInbox.BatchMetadata memory meta = _loadMetadata(i);
            assertEq(batch.metaHash, keccak256(abi.encode(meta)));

            assertEq(batch.lastBlockTimestamp, block.timestamp);
            assertEq(batch.anchorBlockId, block.number - 1);
            assertEq(batch.nextTransitionId, 1);
            assertEq(batch.verifiedTransitionId, 0);
        }

        // - Proposing one block block will revert
        vm.expectRevert(ITaikoInbox.TooManyBatches.selector);
        _proposeBatchesWithDefaultParameters({ numBatchesToPropose: 1 });
    }

    function test_inbox_exceed_max_batch_proposal_will_revert()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(10)
        WhenLogAllBatchesAndTransitions
    {
        // - Proposing one block block will revert
        vm.expectRevert(ITaikoInbox.TooManyBatches.selector);
        _proposeBatchesWithDefaultParameters({ numBatchesToPropose: 1 });
    }

    function test_inbox_prove_with_wrong_transitions_will_not_finalize_blocks()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(6)
        WhenMultipleBatchesAreProvedWithWrongTransitions(1, 7)
        WhenLogAllBatchesAndTransitions
    {
        // - All stats are correct and expected

        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        assertEq(stats1.lastSyncedBatchId, 0);
        assertEq(stats1.lastSyncedAt, 0);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.numBatches, 7);
        assertEq(stats2.lastVerifiedBatchId, 0);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        // - Verify genesis block
        ITaikoInbox.Batch memory batch = inbox.getBatch(0);
        assertEq(batch.batchId, 0);
        assertEq(batch.metaHash, bytes32(uint256(1)));
        assertEq(batch.lastBlockTimestamp, genesisBlockProposedAt);
        assertEq(batch.anchorBlockId, genesisBlockProposedIn);
        assertEq(batch.nextTransitionId, 2);
        assertEq(batch.verifiedTransitionId, 1);

        // Verify block data
        for (uint64 i = 1; i < 7; ++i) {
            batch = inbox.getBatch(i);
            assertEq(batch.batchId, i);
            ITaikoInbox.BatchMetadata memory meta = _loadMetadata(i);
            assertEq(batch.metaHash, keccak256(abi.encode(meta)));

            assertEq(batch.lastBlockTimestamp, block.timestamp);
            assertEq(batch.anchorBlockId, block.number - 1);
            assertEq(batch.nextTransitionId, 2);
            assertEq(batch.verifiedTransitionId, 0);
        }
    }

    function test_inbox_prove_batch_not_exist_will_revert() external transactBy(Alice) {
        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;
        vm.expectRevert(ITaikoInbox.BatchNotFound.selector);
        _proveBatchesWithCorrectTransitions(batchIds);
    }

    function test_inbox_prove_verified_batch_will_revert()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
        WhenMultipleBatchesAreProvedWithCorrectTransitions(1, 2)
    {
        uint64[] memory batchIds = new uint64[](1);
        batchIds[0] = 1;
        vm.expectRevert(ITaikoInbox.BatchNotFound.selector);
        _proveBatchesWithCorrectTransitions(batchIds);
    }

    function test_inbox_propose_1block_per_batch_and_prove_many_blocks_with_first_transition_being_correct(
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(9)
        WhenMultipleBatchesAreProvedWithCorrectTransitions(1, 10)
        WhenLogAllBatchesAndTransitions
    {
        // - All stats are correct and expected

        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        assertEq(stats1.lastSyncedBatchId, 5);
        assertEq(stats1.lastSyncedAt, block.timestamp);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.numBatches, 10);
        assertEq(stats2.lastVerifiedBatchId, 9);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        (uint64 batchId, uint64 blockId, ITaikoInbox.TransitionState memory ts) =
            inbox.getLastVerifiedTransition();
        assertEq(batchId, 9);
        assertEq(blockId, 9);
        assertEq(ts.blockHash, correctBlockhash(9));
        assertEq(ts.stateRoot, bytes32(uint256(0)));

        vm.expectRevert(ITaikoInbox.TransitionNotFound.selector);
        ts = inbox.getTransitionById(9, uint24(0));

        ts = inbox.getTransitionById(9, uint24(1));
        assertEq(ts.parentHash, correctBlockhash(8));
        assertEq(ts.blockHash, correctBlockhash(9));
        assertEq(ts.stateRoot, bytes32(uint256(0)));

        vm.expectRevert(ITaikoInbox.TransitionNotFound.selector);
        ts = inbox.getTransitionByParentHash(9, correctBlockhash(9));

        ts = inbox.getTransitionByParentHash(9, correctBlockhash(8));
        assertEq(ts.parentHash, correctBlockhash(8));
        assertEq(ts.blockHash, correctBlockhash(9));
        assertEq(ts.stateRoot, bytes32(uint256(0)));

        (batchId, blockId, ts) = inbox.getLastSyncedTransition();
        assertEq(batchId, 5);
        assertEq(blockId, 5);
        assertEq(ts.blockHash, correctBlockhash(5));
        assertEq(ts.stateRoot, correctStateRoot(5));

        // - Verify genesis block
        ITaikoInbox.Batch memory batch = inbox.getBatch(0);
        assertEq(batch.batchId, 0);
        assertEq(batch.metaHash, bytes32(uint256(1)));
        assertEq(batch.lastBlockTimestamp, genesisBlockProposedAt);
        assertEq(batch.anchorBlockId, genesisBlockProposedIn);
        assertEq(batch.nextTransitionId, 2);
        assertEq(batch.verifiedTransitionId, 1);

        // Verify block data
        for (uint64 i = 1; i < 10; ++i) {
            batch = inbox.getBatch(i);
            assertEq(batch.batchId, i);
            ITaikoInbox.BatchMetadata memory meta = _loadMetadata(i);
            assertEq(batch.metaHash, keccak256(abi.encode(meta)));

            assertEq(batch.lastBlockTimestamp, block.timestamp);
            assertEq(batch.anchorBlockId, block.number - 1);
            assertEq(batch.nextTransitionId, 2);
            if (i % pacayaConfig().stateRootSyncInternal == 0 || i == stats2.lastVerifiedBatchId) {
                assertEq(batch.verifiedTransitionId, 1);
            } else {
                assertEq(batch.verifiedTransitionId, 0);
            }
        }
    }

    function test_inbox_propose_7block_per_batch_and_prove_many_blocks_with_first_transition_being_correct(
    )
        external
        WhenEachBatchHasMultipleBlocks(7)
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(9)
        WhenMultipleBatchesAreProvedWithCorrectTransitions(1, 10)
        WhenLogAllBatchesAndTransitions
    {
        // - All stats are correct and expected

        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        assertEq(stats1.lastSyncedBatchId, 5);
        assertEq(stats1.lastSyncedAt, block.timestamp);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.numBatches, 10);
        assertEq(stats2.lastVerifiedBatchId, 9);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        (uint64 batchId, uint64 blockId, ITaikoInbox.TransitionState memory ts) =
            inbox.getLastVerifiedTransition();
        assertEq(batchId, 9);
        assertEq(blockId, 9 * 7);
        assertEq(ts.blockHash, correctBlockhash(9));
        assertEq(ts.stateRoot, bytes32(uint256(0)));

        (batchId, blockId, ts) = inbox.getLastSyncedTransition();
        assertEq(batchId, 5);
        assertEq(blockId, 5 * 7);
        assertEq(ts.blockHash, correctBlockhash(5));
        assertEq(ts.stateRoot, correctStateRoot(5));

        // - Verify genesis block
        ITaikoInbox.Batch memory batch = inbox.getBatch(0);
        assertEq(batch.batchId, 0);
        assertEq(batch.metaHash, bytes32(uint256(1)));
        assertEq(batch.lastBlockTimestamp, genesisBlockProposedAt);
        assertEq(batch.anchorBlockId, genesisBlockProposedIn);
        assertEq(batch.nextTransitionId, 2);
        assertEq(batch.verifiedTransitionId, 1);

        // Verify block data
        for (uint64 i = 1; i < 10; ++i) {
            batch = inbox.getBatch(i);
            assertEq(batch.batchId, i);
            ITaikoInbox.BatchMetadata memory meta = _loadMetadata(i);
            assertEq(batch.metaHash, keccak256(abi.encode(meta)));

            assertEq(batch.lastBlockTimestamp, block.timestamp);
            assertEq(batch.lastBlockId, i * 7);
            assertEq(batch.anchorBlockId, block.number - 1);
            assertEq(batch.nextTransitionId, 2);
            if (i % pacayaConfig().stateRootSyncInternal == 0 || i == stats2.lastVerifiedBatchId) {
                assertEq(batch.verifiedTransitionId, 1);
            } else {
                assertEq(batch.verifiedTransitionId, 0);
            }
        }
    }

    function test_inbox_propose_and_prove_many_blocks_with_second_transition_being_correct()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(9)
        WhenMultipleBatchesAreProvedWithWrongTransitions(1, 10)
        WhenMultipleBatchesAreProvedWithCorrectTransitions(1, 10)
        WhenLogAllBatchesAndTransitions
    {
        // - All stats are correct and expected

        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        assertEq(stats1.lastSyncedBatchId, 5);
        assertEq(stats1.lastSyncedAt, block.timestamp);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.numBatches, 10);
        assertEq(stats2.lastVerifiedBatchId, 9);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        // - Verify genesis block
        ITaikoInbox.Batch memory batch = inbox.getBatch(0);
        assertEq(batch.batchId, 0);
        assertEq(batch.metaHash, bytes32(uint256(1)));
        assertEq(batch.lastBlockTimestamp, genesisBlockProposedAt);
        assertEq(batch.anchorBlockId, genesisBlockProposedIn);
        assertEq(batch.nextTransitionId, 2);
        assertEq(batch.verifiedTransitionId, 1);

        // Verify block data
        for (uint64 i = 1; i < 10; ++i) {
            batch = inbox.getBatch(i);
            assertEq(batch.batchId, i);
            ITaikoInbox.BatchMetadata memory meta = _loadMetadata(i);
            assertEq(batch.metaHash, keccak256(abi.encode(meta)));
            assertEq(batch.lastBlockTimestamp, block.timestamp);
            assertEq(batch.anchorBlockId, block.number - 1);
            assertEq(batch.nextTransitionId, 3);
            if (i % pacayaConfig().stateRootSyncInternal == 0 || i == stats2.lastVerifiedBatchId) {
                assertEq(batch.verifiedTransitionId, 2);
            } else {
                assertEq(batch.verifiedTransitionId, 0);
            }
        }
    }

    function test_inbox_ring_buffer_will_be_reused()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(9)
        WhenMultipleBatchesAreProvedWithCorrectTransitions(1, 10)
        WhenMultipleBatchesAreProposedWithDefaultParameters(8)
        WhenLogAllBatchesAndTransitions
        WhenMultipleBatchesAreProvedWithCorrectTransitions(14, 16)
        WhenLogAllBatchesAndTransitions
        WhenMultipleBatchesAreProvedWithCorrectTransitions(10, 11)
        WhenLogAllBatchesAndTransitions
    {
        // - All stats are correct and expected

        ITaikoInbox.Stats1 memory stats1 = inbox.getStats1();
        assertEq(stats1.lastSyncedBatchId, 10);
        assertEq(stats1.lastSyncedAt, block.timestamp);

        ITaikoInbox.Stats2 memory stats2 = inbox.getStats2();
        assertEq(stats2.numBatches, 18);
        assertEq(stats2.lastVerifiedBatchId, 10);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        (uint64 batchId, uint64 blockId, ITaikoInbox.TransitionState memory ts) =
            inbox.getLastVerifiedTransition();
        assertEq(batchId, 10);
        assertEq(blockId, 10);
        assertEq(ts.blockHash, correctBlockhash(10));
        assertEq(ts.stateRoot, correctStateRoot(10));

        (batchId, blockId, ts) = inbox.getLastSyncedTransition();
        assertEq(batchId, 10);
        assertEq(blockId, 10);
        assertEq(ts.blockHash, correctBlockhash(10));
        assertEq(ts.stateRoot, correctStateRoot(10));

        // Verify block data
        for (uint64 i = 8; i < 15; ++i) {
            ITaikoInbox.Batch memory batch = inbox.getBatch(i);
            assertEq(batch.batchId, i);
            ITaikoInbox.BatchMetadata memory meta = _loadMetadata(i);
            assertEq(batch.metaHash, keccak256(abi.encode(meta)));

            assertEq(batch.lastBlockTimestamp, block.timestamp);
            assertEq(batch.anchorBlockId, block.number - 1);
            if (i == 8) {
                assertEq(batch.verifiedTransitionId, 0);
                assertEq(batch.nextTransitionId, 2);
            } else if (i == 9) {
                assertEq(batch.verifiedTransitionId, 1);
                assertEq(batch.nextTransitionId, 2);
            } else if (i == 10) {
                assertEq(batch.verifiedTransitionId, 1);
                assertEq(batch.nextTransitionId, 2);
            } else if (i == 11 || i == 12 || i == 13 || i == 16 || i == 17) {
                assertEq(batch.verifiedTransitionId, 0);
                assertEq(batch.nextTransitionId, 1);
            } else if (i == 14 || i == 15) {
                assertEq(batch.verifiedTransitionId, 0);
                assertEq(batch.nextTransitionId, 2);
            }
        }
    }

    function test_inbox_reprove_the_same_batch_with_same_transition_will_do_nothing()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
        WhenLogAllBatchesAndTransitions
    {
        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](1);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](1);

        metas[0] = _loadMetadata(1);

        transitions[0].parentHash = bytes32(uint256(0x100));
        transitions[0].blockHash = bytes32(uint256(0x101));
        transitions[0].stateRoot = bytes32(uint256(0x102));

        inbox.proveBatches(abi.encode(metas, transitions), "proof");
        _logAllBatchesAndTransitions();

        inbox.proveBatches(abi.encode(metas, transitions), "proof");

        assertTrue(!EssentialContract(address(inbox)).paused());
    }

    function test_inbox_reprove_by_transition_with_same_parent_hash_but_different_block_hash_or_state_root_will_pause_inbox(
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(1)
        WhenLogAllBatchesAndTransitions
    {
        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](1);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](1);

        metas[0] = _loadMetadata(1);

        transitions[0].parentHash = bytes32(uint256(0x100));
        transitions[0].blockHash = bytes32(uint256(0x101));
        transitions[0].stateRoot = bytes32(uint256(0x102));
        inbox.proveBatches(abi.encode(metas, transitions), "proof");
        _logAllBatchesAndTransitions();

        transitions[0].blockHash = bytes32(uint256(0x103));
        inbox.proveBatches(abi.encode(metas, transitions), "proof");
        _logAllBatchesAndTransitions();

        assertTrue(EssentialContract(address(inbox)).paused());
    }

    function test_inbox_reprove_by_transition_with_same_parent_hash_but_different_block_hash_will_pause_inbox(
    )
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(9)
        WhenMultipleBatchesAreProvedWithCorrectTransitions(1, 4)
        WhenMultipleBatchesAreProvedWithCorrectTransitions(5, 6)
        WhenLogAllBatchesAndTransitions
    {
        uint64 batchId = 5;

        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](1);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](1);

        metas[0] = _loadMetadata(batchId);
        transitions[0].parentHash = correctBlockhash(batchId - 1);
        transitions[0].blockHash = bytes32(uint256(120));
        transitions[0].stateRoot = correctStateRoot(batchId);

        // Let the five transition is a conflict one.
        inbox.proveBatches(abi.encode(metas, transitions), "proof");

        // Verify the tagged conflict transition.
        ITaikoInbox.TransitionState memory ts = inbox.getTransitionById(batchId, uint24(1));
        assertEq(ts.blockHash, bytes32(uint256(0)));
        // Verify the inbox is paused.
        assertTrue(EssentialContract(address(inbox)).paused());

        vm.startPrank(deployer);
        EssentialContract(address(inbox)).unpause();
        vm.stopPrank();

        // Correct the blockhash.
        transitions[0].blockHash = correctBlockhash(batchId);
        inbox.proveBatches(abi.encode(metas, transitions), "proof");

        // Verify the inbox is not paused.
        assertFalse(EssentialContract(address(inbox)).paused());
    }

    function test_proposeBatch_reverts_for_invalid_proposer_and_operator()
        external
        transactBy(Alice)
    {
        ITaikoInbox.BatchParams memory params;
        params.proposer = Alice;

        vm.expectRevert(ITaikoInbox.CustomProposerNotAllowed.selector);
        inbox.proposeBatch(abi.encode(params), "txList");

        vm.startPrank(deployer);
        address operator = Bob;
        resolver.registerAddress(block.chainid, "inbox_operator", operator);
        vm.stopPrank();
    }

    function test_inbox_measure_gas_used()
        external
        transactBy(Alice)
        WhenMultipleBatchesAreProposedWithDefaultParameters(9)
        WhenMultipleBatchesAreProvedWithCorrectTransitions(1, 10)
        WhenLogAllBatchesAndTransitions
    {
        uint64 count = 10;

        vm.startSnapshotGas("proposeBatch");

        uint64[] memory batchIds = _proposeBatchesWithDefaultParameters(count);

        uint256 gasProposeBatches = vm.stopSnapshotGas("proposeBatch");
        console2.log("Gas per batch - proposing:", gasProposeBatches / count);

        ITaikoInbox.BatchMetadata[] memory metas = new ITaikoInbox.BatchMetadata[](count);
        ITaikoInbox.Transition[] memory transitions = new ITaikoInbox.Transition[](count);

        for (uint256 i; i < batchIds.length; ++i) {
            metas[i] = _loadMetadata(batchIds[i]);

            transitions[i].parentHash = correctBlockhash(batchIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(batchIds[i]);
            transitions[i].stateRoot = correctStateRoot(batchIds[i]);
        }

        vm.startSnapshotGas("proveBatches");
        inbox.proveBatches(abi.encode(metas, transitions), "proof");
        uint256 gasProveBatches = vm.stopSnapshotGas("proveBatches");
        console2.log("Gas per batch - proving:", gasProveBatches / count);
        console2.log("Gas per batch - total:", (gasProposeBatches + gasProveBatches) / count);

        _logAllBatchesAndTransitions();

        string memory str = string(
            abi.encodePacked(
                "See `test_inbox_measure_gas_used` in InboxTest_ProposeAndProve.t.sol\n",
                "\nGas per proposeBatches: ",
                Strings.toString(gasProposeBatches / count),
                "\nGas per proveBatches: ",
                Strings.toString(gasProveBatches / count),
                "\nTotal: ",
                Strings.toString((gasProposeBatches + gasProveBatches) / count)
            )
        );

        vm.writeFile("./deployments/test_inbox_measure_gas_used.txt", str);
    }
}
