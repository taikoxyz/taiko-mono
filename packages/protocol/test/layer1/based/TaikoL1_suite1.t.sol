// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./TaikoL1TestBase.sol";

contract TaikoL1Test_Suite1 is TaikoL1TestBase {
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
            emitTxListInCalldata: true,
            pacayaForkHeight: 0
        });
    }

    function setUpOnEthereum() internal override {
        super.setUpOnEthereum();
        bondToken = deployBondToken();
    }

    function test_taikol1_query_right_after_genesis_block() external view {
        // - All stats are correct and expected
        ITaikoL1.Stats1 memory stats1 = taikoL1.getStats1();
        assertEq(stats1.lastSyncedBlockId, 0);
        assertEq(stats1.lastSyncedAt, 0);

        ITaikoL1.Stats2 memory stats2 = taikoL1.getStats2();
        assertEq(stats2.numBlocks, 1);
        assertEq(stats2.lastVerifiedBlockId, 0);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, genesisBlockProposedIn);
        assertEq(stats2.lastUnpausedAt, 0);

        // - Verify genesis block
        ITaikoL1.BlockV3 memory blk = taikoL1.getBlockV3(0);
        assertEq(blk.blockId, 0);
        assertEq(blk.metaHash, bytes32(uint256(1)));
        assertEq(blk.timestamp, genesisBlockProposedAt);
        assertEq(blk.anchorBlockId, genesisBlockProposedIn);
        assertEq(blk.nextTransitionId, 2);
        assertEq(blk.verifiedTransitionId, 1);

        (uint64 blockId, ITaikoL1.TransitionV3 memory tran) = taikoL1.getLastVerifiedTransitionV3();
        assertEq(blockId, 0);
        assertEq(tran.blockHash, correctBlockhash(0));
        assertEq(tran.stateRoot, bytes32(uint256(0)));

        (blockId, tran) = taikoL1.getLastSyncedTransitionV3();
        assertEq(blockId, 0);
        assertEq(tran.blockHash, correctBlockhash(0));
        assertEq(tran.stateRoot, bytes32(uint256(0)));
    }

    function test_taikol1_query_blocks_not_exist_will_revert() external {
        vm.expectRevert(ITaikoL1.BlockNotFound.selector);
        taikoL1.getBlockV3(1);
    }

    function test_taikol1_max_block_proposal()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(9)
        WhenLogAllBlocksAndTransitions
    {
        // - All stats are correct and expected

        ITaikoL1.Stats1 memory stats1 = taikoL1.getStats1();
        assertEq(stats1.lastSyncedBlockId, 0);
        assertEq(stats1.lastSyncedAt, 0);

        ITaikoL1.Stats2 memory stats2 = taikoL1.getStats2();
        assertEq(stats2.numBlocks, 10);
        assertEq(stats2.lastVerifiedBlockId, 0);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        // - Verify genesis block
        ITaikoL1.BlockV3 memory blk = taikoL1.getBlockV3(0);
        assertEq(blk.blockId, 0);
        assertEq(blk.metaHash, bytes32(uint256(1)));
        assertEq(blk.timestamp, genesisBlockProposedAt);
        assertEq(blk.anchorBlockId, genesisBlockProposedIn);
        assertEq(blk.nextTransitionId, 2);
        assertEq(blk.verifiedTransitionId, 1);

        // Verify block data
        for (uint64 i = 1; i < 10; ++i) {
            blk = taikoL1.getBlockV3(i);
            assertEq(blk.blockId, i);
            assertEq(blk.metaHash, keccak256(abi.encode(blockMetadatas[i])));

            assertEq(blk.timestamp, block.timestamp);
            assertEq(blk.anchorBlockId, block.number - 1);
            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
        }

        // - Proposing one block block will revert
        vm.expectRevert(ITaikoL1.TooManyBlocks.selector);
        _proposeBlocksWithDefaultParameters({ numBlocksToPropose: 1 });
    }

    function test_taikol1_exceed_max_block_proposal_will_revert()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(9)
        WhenLogAllBlocksAndTransitions
    {
        // - Proposing one block block will revert
        vm.expectRevert(ITaikoL1.TooManyBlocks.selector);
        _proposeBlocksWithDefaultParameters({ numBlocksToPropose: 1 });
    }

    function test_taikol1_prove_with_wrong_transitions_will_not_finalize_blocks()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(6)
        WhenMultipleBlocksAreProvedWithWrongTransitions(1, 7)
        WhenLogAllBlocksAndTransitions
    {
        // - All stats are correct and expected

        ITaikoL1.Stats1 memory stats1 = taikoL1.getStats1();
        assertEq(stats1.lastSyncedBlockId, 0);
        assertEq(stats1.lastSyncedAt, 0);

        ITaikoL1.Stats2 memory stats2 = taikoL1.getStats2();
        assertEq(stats2.numBlocks, 7);
        assertEq(stats2.lastVerifiedBlockId, 0);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        // - Verify genesis block
        ITaikoL1.BlockV3 memory blk = taikoL1.getBlockV3(0);
        assertEq(blk.blockId, 0);
        assertEq(blk.metaHash, bytes32(uint256(1)));
        assertEq(blk.timestamp, genesisBlockProposedAt);
        assertEq(blk.anchorBlockId, genesisBlockProposedIn);
        assertEq(blk.nextTransitionId, 2);
        assertEq(blk.verifiedTransitionId, 1);

        // Verify block data
        for (uint64 i = 1; i < 7; ++i) {
            blk = taikoL1.getBlockV3(i);
            assertEq(blk.blockId, i);
            assertEq(blk.metaHash, keccak256(abi.encode(blockMetadatas[i])));

            assertEq(blk.timestamp, block.timestamp);
            assertEq(blk.anchorBlockId, block.number - 1);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
        }
    }

    function test_taikol1_prove_block_not_exist_will_revert() external transactBy(Alice) {
        uint64[] memory blockIds = new uint64[](1);
        blockIds[0] = 1;
        vm.expectRevert(ITaikoL1.BlockNotFound.selector);
        _proveBlocksWithCorrectTransitions(blockIds);
    }

    function test_taikol1_prove_verified_block_will_revert()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(1)
        WhenMultipleBlocksAreProvedWithCorrectTransitions(1, 2)
    {
        uint64[] memory blockIds = new uint64[](1);
        blockIds[0] = 1;
        vm.expectRevert(ITaikoL1.BlockNotFound.selector);
        _proveBlocksWithCorrectTransitions(blockIds);
    }

    function test_taikol1_propose_and_prove_many_blocks_with_first_transition_being_correct()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(9)
        WhenMultipleBlocksAreProvedWithCorrectTransitions(1, 10)
        WhenLogAllBlocksAndTransitions
    {
        // - All stats are correct and expected

        ITaikoL1.Stats1 memory stats1 = taikoL1.getStats1();
        assertEq(stats1.lastSyncedBlockId, 5);
        assertEq(stats1.lastSyncedAt, block.timestamp);

        ITaikoL1.Stats2 memory stats2 = taikoL1.getStats2();
        assertEq(stats2.numBlocks, 10);
        assertEq(stats2.lastVerifiedBlockId, 9);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        (uint64 blockId, ITaikoL1.TransitionV3 memory tran) = taikoL1.getLastVerifiedTransitionV3();
        assertEq(blockId, 9);
        assertEq(tran.blockHash, correctBlockhash(9));
        assertEq(tran.stateRoot, bytes32(uint256(0)));

        (blockId, tran) = taikoL1.getLastSyncedTransitionV3();
        assertEq(blockId, 5);
        assertEq(tran.blockHash, correctBlockhash(5));
        assertEq(tran.stateRoot, correctStateRoot(5));

        // - Verify genesis block
        ITaikoL1.BlockV3 memory blk = taikoL1.getBlockV3(0);
        assertEq(blk.blockId, 0);
        assertEq(blk.metaHash, bytes32(uint256(1)));
        assertEq(blk.timestamp, genesisBlockProposedAt);
        assertEq(blk.anchorBlockId, genesisBlockProposedIn);
        assertEq(blk.nextTransitionId, 2);
        assertEq(blk.verifiedTransitionId, 1);

        // Verify block data
        for (uint64 i = 1; i < 10; ++i) {
            blk = taikoL1.getBlockV3(i);
            assertEq(blk.blockId, i);
            assertEq(blk.metaHash, keccak256(abi.encode(blockMetadatas[i])));

            assertEq(blk.timestamp, block.timestamp);
            assertEq(blk.anchorBlockId, block.number - 1);
            assertEq(blk.nextTransitionId, 2);
            if (i % getConfig().stateRootSyncInternal == 0 || i == stats2.lastVerifiedBlockId) {
                assertEq(blk.verifiedTransitionId, 1);
            } else {
                assertEq(blk.verifiedTransitionId, 0);
            }
        }
    }

    function test_taikol1_propose_and_prove_many_blocks_with_second_transition_being_correct()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(9)
        WhenMultipleBlocksAreProvedWithWrongTransitions(1, 10)
        WhenMultipleBlocksAreProvedWithCorrectTransitions(1, 10)
        WhenLogAllBlocksAndTransitions
    {
        // - All stats are correct and expected

        ITaikoL1.Stats1 memory stats1 = taikoL1.getStats1();
        assertEq(stats1.lastSyncedBlockId, 5);
        assertEq(stats1.lastSyncedAt, block.timestamp);

        ITaikoL1.Stats2 memory stats2 = taikoL1.getStats2();
        assertEq(stats2.numBlocks, 10);
        assertEq(stats2.lastVerifiedBlockId, 9);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        // - Verify genesis block
        ITaikoL1.BlockV3 memory blk = taikoL1.getBlockV3(0);
        assertEq(blk.blockId, 0);
        assertEq(blk.metaHash, bytes32(uint256(1)));
        assertEq(blk.timestamp, genesisBlockProposedAt);
        assertEq(blk.anchorBlockId, genesisBlockProposedIn);
        assertEq(blk.nextTransitionId, 2);
        assertEq(blk.verifiedTransitionId, 1);

        // Verify block data
        for (uint64 i = 1; i < 10; ++i) {
            blk = taikoL1.getBlockV3(i);
            assertEq(blk.blockId, i);
            assertEq(blk.metaHash, keccak256(abi.encode(blockMetadatas[i])));

            assertEq(blk.timestamp, block.timestamp);
            assertEq(blk.anchorBlockId, block.number - 1);
            assertEq(blk.nextTransitionId, 3);
            if (i % getConfig().stateRootSyncInternal == 0 || i == stats2.lastVerifiedBlockId) {
                assertEq(blk.verifiedTransitionId, 2);
            } else {
                assertEq(blk.verifiedTransitionId, 0);
            }
        }
    }

    function test_taikol1_ring_buffer_will_be_reused()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(9)
        WhenMultipleBlocksAreProvedWithCorrectTransitions(1, 10)
        WhenMultipleBlocksAreProposedWithDefaultParameters(8)
        WhenLogAllBlocksAndTransitions
        WhenMultipleBlocksAreProvedWithCorrectTransitions(14, 16)
        WhenLogAllBlocksAndTransitions
        WhenMultipleBlocksAreProvedWithCorrectTransitions(10, 11)
        WhenLogAllBlocksAndTransitions
    {
        // - All stats are correct and expected

        ITaikoL1.Stats1 memory stats1 = taikoL1.getStats1();
        assertEq(stats1.lastSyncedBlockId, 10);
        assertEq(stats1.lastSyncedAt, block.timestamp);

        ITaikoL1.Stats2 memory stats2 = taikoL1.getStats2();
        assertEq(stats2.numBlocks, 18);
        assertEq(stats2.lastVerifiedBlockId, 10);
        assertEq(stats2.paused, false);
        assertEq(stats2.lastProposedIn, block.number);
        assertEq(stats2.lastUnpausedAt, 0);

        (uint64 blockId, ITaikoL1.TransitionV3 memory tran) = taikoL1.getLastVerifiedTransitionV3();
        assertEq(blockId, 10);
        assertEq(tran.blockHash, correctBlockhash(10));
        assertEq(tran.stateRoot, correctStateRoot(10));

        (blockId, tran) = taikoL1.getLastSyncedTransitionV3();
        assertEq(blockId, 10);
        assertEq(tran.blockHash, correctBlockhash(10));
        assertEq(tran.stateRoot, correctStateRoot(10));

        // Verify block data
        for (uint64 i = 8; i < 15; ++i) {
            ITaikoL1.BlockV3 memory blk = taikoL1.getBlockV3(i);
            assertEq(blk.blockId, i);
            assertEq(blk.metaHash, keccak256(abi.encode(blockMetadatas[i])));

            assertEq(blk.timestamp, block.timestamp);
            assertEq(blk.anchorBlockId, block.number - 1);
            if (i == 8) {
                assertEq(blk.verifiedTransitionId, 0);
                assertEq(blk.nextTransitionId, 2);
            } else if (i == 9) {
                assertEq(blk.verifiedTransitionId, 1);
                assertEq(blk.nextTransitionId, 2);
            } else if (i == 10) {
                assertEq(blk.verifiedTransitionId, 1);
                assertEq(blk.nextTransitionId, 2);
            } else if (i == 11 || i == 12 || i == 13 || i == 16 || i == 17) {
                assertEq(blk.verifiedTransitionId, 0);
                assertEq(blk.nextTransitionId, 1);
            } else if (i == 14 || i == 15) {
                assertEq(blk.verifiedTransitionId, 0);
                assertEq(blk.nextTransitionId, 2);
            }
        }
    }

    function test_taikol1_reprove_the_same_block_is_ok()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(1)
        WhenLogAllBlocksAndTransitions
    {
        ITaikoL1.BlockMetadataV3[] memory metas = new ITaikoL1.BlockMetadataV3[](1);
        ITaikoL1.TransitionV3[] memory transitions = new ITaikoL1.TransitionV3[](1);

        metas[0] = blockMetadatas[1];

        transitions[0].parentHash = bytes32(uint256(0x100));
        transitions[0].blockHash = bytes32(uint256(0x101));
        transitions[0].stateRoot = bytes32(uint256(0x102));
        taikoL1.proveBlocksV3(metas, transitions, "proof");
        _logAllBlocksAndTransitions();

        transitions[0].parentHash = bytes32(uint256(0x100));
        transitions[0].blockHash = bytes32(uint256(0x111));
        transitions[0].stateRoot = bytes32(uint256(0x112));
        taikoL1.proveBlocksV3(metas, transitions, "proof");
        _logAllBlocksAndTransitions();

        transitions[0].parentHash = bytes32(uint256(0x200));
        transitions[0].blockHash = bytes32(uint256(0x201));
        transitions[0].stateRoot = bytes32(uint256(0x202));
        taikoL1.proveBlocksV3(metas, transitions, "proof");
        _logAllBlocksAndTransitions();

        transitions[0].parentHash = bytes32(uint256(0x200));
        transitions[0].blockHash = bytes32(uint256(0x211));
        transitions[0].stateRoot = bytes32(uint256(0x212));
        taikoL1.proveBlocksV3(metas, transitions, "proof");
        _logAllBlocksAndTransitions();
    }

    function test_taikol1_measure_gas_used()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(9)
        WhenMultipleBlocksAreProvedWithCorrectTransitions(1, 10)
        WhenLogAllBlocksAndTransitions
    {
        uint64 count = 1;

        vm.startSnapshotGas("proposeBlocksV3");
        ITaikoL1.BlockMetadataV3[] memory metas =
            taikoL1.proposeBlocksV3(address(0), address(0), new ITaikoL1.BlockParamsV3[](count), "");
        uint256 gasProposeBlocksV3 = vm.stopSnapshotGas("proposeBlocksV3");
        console2.log("Gas per block - proposing:", gasProposeBlocksV3 / count);

        ITaikoL1.TransitionV3[] memory transitions = new ITaikoL1.TransitionV3[](count);
        for (uint256 i; i < metas.length; ++i) {
            transitions[i].parentHash = correctBlockhash(metas[i].blockId - 1);
            transitions[i].blockHash = correctBlockhash(metas[i].blockId);
            transitions[i].stateRoot = correctStateRoot(metas[i].blockId);
        }

        vm.startSnapshotGas("proveBlocksV3");
        taikoL1.proveBlocksV3(metas, transitions, "proof");
        uint256 gasProveBlocksV3 = vm.stopSnapshotGas("proveBlocksV3");
        console2.log("Gas per block - proving:", gasProveBlocksV3 / count);
        console2.log("Gas per block - total:", (gasProposeBlocksV3 + gasProveBlocksV3) / count);

        _logAllBlocksAndTransitions();
    }
}
