// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../Layer1Test.sol";

contract TaikoL1Test is Layer1Test {
    mapping(uint256 => ITaikoL1.BlockMetadataV3) internal blockMetadatas;
    ITaikoL1 internal taikoL1;
    TaikoToken internal bondToken;
    SignalService internal signalService;
    uint256 genesisBlockProposedAt;
    uint256 genesisBlockProposedIn;

    ITaikoL1.ConfigV3 internal config = ITaikoL1.ConfigV3({
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
        pacayaForkHeight: 0,
        provingWindow: 1 hours
    });

    modifier transactBy(address transactor) override {
        vm.deal(transactor, 100 ether);
        bondToken.transfer(transactor, 10_000 ether);
        vm.startPrank(transactor);
        bondToken.approve(address(taikoL1), type(uint256).max);

        _;
        vm.stopPrank();
    }

    function setUpOnEthereum() internal override {
        genesisBlockProposedAt = block.timestamp;
        genesisBlockProposedIn = block.number;

        taikoL1 = deployTaikoL1(correctBlockhash(0), config);
        bondToken = deployBondToken();
        signalService = deploySignalService(address(new SignalService()));
        signalService.authorize(address(taikoL1), true);

        mineOneBlockAndWrap(12 seconds);
    }

    modifier WhenLogAllBlocksAndTransitions(bool log) {
        if (log) _logAllBlocksAndTransitions();
        _;
    }

    modifier WhenMultipleBlocksAreProposedWithDefaultParameters(uint256 numBlocksToPropose) {
        _proposeBlocksWithDefaultParameters(numBlocksToPropose);
        _;
    }

    modifier WhenMultipleBlocksAreProvedWithWrongTransitions(
        uint64 startBlockId,
        uint64 endBlockId
    ) {
        uint64[] memory blockIds = new uint64[](endBlockId + 1 - startBlockId);
        for (uint64 i; i < blockIds.length; i++) {
            blockIds[i] = startBlockId + i;
        }
        _proveBlocksWithWrongTransitions(blockIds);
        _;
    }

    modifier WhenMultipleBlocksAreProvedWithCorrectTransitions(
        uint64 startBlockId,
        uint64 endBlockId
    ) {
        uint64[] memory blockIds = new uint64[](endBlockId + 1 - startBlockId);
        for (uint64 i; i < blockIds.length; i++) {
            blockIds[i] = startBlockId + i;
        }
        _proveBlocksWithCorrectTransitions(blockIds);
        _;
    }

    function test_taikol1_query_right_after_genesis_block() external {
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
    }

    function test_taikol1_query_blocks_not_exist_will_revert() external {
        vm.expectRevert(ITaikoL1.BlockNotFound.selector);
        taikoL1.getBlockV3(1);
    }

    function test_taikol1_max_block_proposal()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(9)
        WhenLogAllBlocksAndTransitions(true)
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
        WhenLogAllBlocksAndTransitions(true)
    {
        // - Proposing one block block will revert
        vm.expectRevert(ITaikoL1.TooManyBlocks.selector);
        _proposeBlocksWithDefaultParameters({ numBlocksToPropose: 1 });
    }

    function test_taikol1_prove_with_wrong_transitions_will_not_finalize_blocks()
        external
        transactBy(Alice)
        WhenMultipleBlocksAreProposedWithDefaultParameters(6)
        WhenMultipleBlocksAreProvedWithWrongTransitions(1, 6)
        WhenLogAllBlocksAndTransitions(true)
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
        WhenMultipleBlocksAreProvedWithCorrectTransitions(1, 1)
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
        WhenMultipleBlocksAreProvedWithCorrectTransitions(1, 9)
        WhenLogAllBlocksAndTransitions(true)
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
            assertEq(blk.nextTransitionId, 2);
            if (i % config.stateRootSyncInternal == 0 || i == stats2.lastVerifiedBlockId) {
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
        WhenMultipleBlocksAreProvedWithWrongTransitions(1, 9)
        WhenMultipleBlocksAreProvedWithCorrectTransitions(1, 9)
        WhenLogAllBlocksAndTransitions(true)
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
            if (i % config.stateRootSyncInternal == 0 || i == stats2.lastVerifiedBlockId) {
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
        WhenMultipleBlocksAreProvedWithCorrectTransitions(1, 9)
        WhenMultipleBlocksAreProposedWithDefaultParameters(8)
        WhenLogAllBlocksAndTransitions(true)
        WhenMultipleBlocksAreProvedWithCorrectTransitions(14, 15)
        WhenLogAllBlocksAndTransitions(true)
        WhenMultipleBlocksAreProvedWithCorrectTransitions(10, 10)
        WhenLogAllBlocksAndTransitions(true)
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

        // - Verify genesis block

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

    // internal helper functions -------------------------------------------------------------------

    function _proposeBlocksWithDefaultParameters(uint256 numBlocksToPropose) internal {
        ITaikoL1.BlockParamsV3[] memory blockParams =
            new ITaikoL1.BlockParamsV3[](numBlocksToPropose);

        ITaikoL1.BlockMetadataV3[] memory metas =
            taikoL1.proposeBlocksV3(address(0), address(0), blockParams);
        for (uint256 i; i < metas.length; ++i) {
            blockMetadatas[metas[i].blockId] = metas[i];
        }
    }

    function _proveBlocksWithCorrectTransitions(uint64[] memory blockIds) internal {
        ITaikoL1.BlockMetadataV3[] memory metas = new ITaikoL1.BlockMetadataV3[](blockIds.length);
        ITaikoL1.TransitionV3[] memory transitions = new ITaikoL1.TransitionV3[](blockIds.length);

        for (uint256 i; i < metas.length; ++i) {
            metas[i] = blockMetadatas[blockIds[i]];
            transitions[i].parentHash = correctBlockhash(blockIds[i] - 1);
            transitions[i].blockHash = correctBlockhash(blockIds[i]);
            transitions[i].stateRoot = correctStateRoot(blockIds[i]);
        }

        taikoL1.proveBlocksV3(metas, transitions, "");
    }

    function _proveBlocksWithWrongTransitions(uint64[] memory blockIds) internal {
        ITaikoL1.BlockMetadataV3[] memory metas = new ITaikoL1.BlockMetadataV3[](blockIds.length);
        ITaikoL1.TransitionV3[] memory transitions = new ITaikoL1.TransitionV3[](blockIds.length);

        for (uint256 i; i < metas.length; ++i) {
            metas[i] = blockMetadatas[blockIds[i]];
            transitions[i].parentHash = randBytes32();
            transitions[i].blockHash = randBytes32();
            transitions[i].stateRoot = randBytes32();
        }

        taikoL1.proveBlocksV3(metas, transitions, "");
    }

    function _logAllBlocksAndTransitions() internal {
        console2.log(unicode"├───────────────────────────────────────────────────────────────");
        ITaikoL1.Stats1 memory stats1 = taikoL1.getStats1();
        console2.log("Stats1 - lastSyncedBlockId:", stats1.lastSyncedBlockId);
        console2.log("Stats1 - lastSyncedAt:", stats1.lastSyncedAt);

        ITaikoL1.Stats2 memory stats2 = taikoL1.getStats2();
        console2.log("Stats2 - numBlocks:", stats2.numBlocks);
        console2.log("Stats2 - lastVerifiedBlockId:", stats2.lastVerifiedBlockId);
        console2.log("Stats2 - paused:", stats2.paused);
        console2.log("Stats2 - lastProposedIn:", stats2.lastProposedIn);
        console2.log("Stats2 - lastUnpausedAt:", stats2.lastUnpausedAt);

        uint64 firstBlockId = stats2.numBlocks > config.blockMaxProposals
            ? stats2.numBlocks - config.blockMaxProposals
            : 0;
        for (uint64 i = firstBlockId; i < stats2.numBlocks; ++i) {
            ITaikoL1.BlockV3 memory blk = taikoL1.getBlockV3(i);
            console2.log(unicode"├── block#", blk.blockId);
            console2.log(unicode"│   ├── metahash:", Strings.toHexString(uint256(blk.metaHash)));
            console2.log(unicode"│   ├── timestamp:", blk.timestamp);
            console2.log(unicode"│   ├── anchorBlockId:", blk.anchorBlockId);
            console2.log(unicode"│   ├── nextTransitionId:", blk.nextTransitionId);
            console2.log(unicode"│   ├── verifiedTransitionId:", blk.verifiedTransitionId);

            for (uint24 j = 1; j < blk.nextTransitionId; ++j) {
                ITaikoL1.TransitionV3 memory tran = taikoL1.getTransitionV3(blk.blockId, j);
                console2.log(unicode"│   ├── transition#", j);
                console2.log(
                    unicode"│   │   ├── parentHash:",
                    Strings.toHexString(uint256(tran.parentHash))
                );
                console2.log(
                    unicode"│   │   ├── blockHash:",
                    Strings.toHexString(uint256(tran.blockHash))
                );
                console2.log(
                    unicode"│   │   └── stateRoot:",
                    Strings.toHexString(uint256(tran.stateRoot))
                );
            }
        }
        console2.log("");
    }

    function correctBlockhash(uint256 blockId) internal pure returns (bytes32) {
        return bytes32(100_000 + blockId);
    }

    function correctStateRoot(uint256 blockId) internal pure returns (bytes32) {
        return bytes32(200_000 + blockId);
    }

    function mintEther(address to, uint256 amountEth) internal {
        vm.deal(to, amountEth);
        console2.log("Ether balance:", to, to.balance);
    }

    function mintTaikoToken(address to, uint256 amountTko) internal {
        bondToken.transfer(to, amountTko);

        vm.prank(to);
        bondToken.approve(address(taikoL1), amountTko);

        console2.log("Bond balance :", to, bondToken.balanceOf(to));
    }
}
