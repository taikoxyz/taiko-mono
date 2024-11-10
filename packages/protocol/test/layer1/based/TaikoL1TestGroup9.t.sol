// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestTaikoL1Base.sol";

// Testing block proving and verification for block#2, as stateRootSyncInternal is set to 2 in
// this test suite, we are testing that block#2 shall have state root always as zero.
contract TestTaikoL1_Group9 is TestTaikoL1Base {
    bytes32 internal constant FIRST_BLOCK_HASH = keccak256("FIRST_BLOCK_HASH");

    function proposeProveVerifyTheFirstBlock() internal {
        mineOneBlockAndWrap(1000 seconds);

        giveEthAndTko(David, 10_000 ether, 1000 ether);
        console2.log("====== David proposes, proves, and verifies the first block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(David, "");

        bytes32 stateRoot = bytes32(uint256(1));

        mineOneBlockAndWrap(10 seconds);
        proveBlock(David, meta, GENESIS_BLOCK_HASH, FIRST_BLOCK_HASH, stateRoot, 73, "");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
    }

    // Test summary:
    // 0. David proposes, proves, and verifies the first block.
    // 1. Alice proposes a block,
    // 2. Guardian prover directly proves the block.
    // 3. Guardian prover re-proves the same transition and fails.
    // 4. Guardian prover proves the block again with a different transition.
    // 5. William contests the guardian prover using a lower-tier proof and fails.
    function test_taikoL1_group_9_case_1() external {
        proposeProveVerifyTheFirstBlock();

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== Guardian prover proves");
        bytes32 parentHash = FIRST_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(10 seconds);
        proveBlock(William, meta, parentHash, blockHash, stateRoot, 74, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            // This block is not storing state root
            assertEq(ts.stateRoot, 0);
            assertEq(ts.tier, 74);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, 0);
            assertEq(ts.prover, William);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether);
            assertEq(getBondTokenBalance(William), 10_000 ether);
        }

        console2.log("====== Guardian re-approve with the same transition");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(
            William,
            meta,
            parentHash,
            blockHash,
            stateRoot,
            74,
            LibProving.L1_ALREADY_PROVED.selector
        );

        console2.log("====== Guardian re-approve with a different transition");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineOneBlockAndWrap(10 seconds);
        proveBlock(William, meta, parentHash, blockHash2, stateRoot2, 74, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            // This block is not storing state root
            assertEq(ts.stateRoot, 0);
            assertEq(ts.tier, 74);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, 0);
            assertEq(ts.prover, William);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether);
            assertEq(getBondTokenBalance(William), 10_000 ether);
        }

        console2.log("====== William contests with a lower tier proof");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(
            William, meta, parentHash, blockHash, stateRoot, 73, LibProving.L1_INVALID_TIER.selector
        );

        console2.log("====== Verify the block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            // This block is not storing state root
            assertEq(ts.stateRoot, 0);
            assertEq(ts.tier, 74);
            assertEq(ts.prover, William);

            assertEq(getBondTokenBalance(Alice), 10_000 ether);
            assertEq(getBondTokenBalance(William), 10_000 ether);
        }
    }

    // Test summary:
    // 0. David proposes, proves, and verifies the first block.
    // 1. Alice proposes a block, Alice is the prover.
    // 2. Alice proves the block.
    // 3. Guardian prover re-proves the same transition and fails.
    // 4. Guardian prover proves the block with a different transition.
    // 5. William contests the guardian prover using a lower-tier proof and fails.
    function test_taikoL1_group_9_case_2() external {
        proposeProveVerifyTheFirstBlock();

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== Alice proves the block");
        bytes32 parentHash = FIRST_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(10 seconds);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Guardian re-approve with the same transition");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(
            William,
            meta,
            parentHash,
            blockHash,
            stateRoot,
            74,
            LibProving.L1_ALREADY_PROVED.selector
        );

        console2.log("====== Guardian re-approve with a different transition");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineOneBlockAndWrap(10 seconds);

        assertEq(getBondTokenBalance(William), 10_000 ether);

        proveBlock(William, meta, parentHash, blockHash2, stateRoot2, 74, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            // This block is not storing state root
            assertEq(ts.stateRoot, 0);
            assertEq(ts.tier, 74);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, 0);
            assertEq(ts.prover, William);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);
            assertEq(getBondTokenBalance(William), 10_000 ether + minTier.validityBond * 7 / 8);
        }

        console2.log("====== Verify the block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            // This block is not storing state root
            assertEq(ts.stateRoot, 0);
            assertEq(ts.tier, 74);
            assertEq(ts.prover, William);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);
            assertEq(getBondTokenBalance(William), 10_000 ether + minTier.validityBond * 7 / 8);
        }
    }

    // Test summary:
    // 0. David proposes, proves, and verifies the first block.
    // 1. Alice proposes a block,
    // 2. Carol proves the block outside the proving window.
    // 3. Guardian prover re-proves the same transition and fails.
    // 4. Guardian prover proves the block with a different transition.
    // 5. William contests the guardian prover using a lower-tier proof and fails.
    function test_taikoL1_group_9_case_3() external {
        proposeProveVerifyTheFirstBlock();

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Carol, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== Carol proves the block");
        bytes32 parentHash = FIRST_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(7 days);
        proveBlock(Carol, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Guardian re-approve with the same transition");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(
            William,
            meta,
            parentHash,
            blockHash,
            stateRoot,
            74,
            LibProving.L1_ALREADY_PROVED.selector
        );

        console2.log("====== Guardian re-approve with a different transition");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineOneBlockAndWrap(10 seconds);
        proveBlock(William, meta, parentHash, blockHash2, stateRoot2, 74, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            // This block is not storing state root
            assertEq(ts.stateRoot, 0);
            assertEq(ts.tier, 74);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, 0);
            assertEq(ts.prover, William);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
            assertEq(
                getBondTokenBalance(Carol),
                10_000 ether - minTier.validityBond + livenessBond * 7 / 8
            );
            assertEq(getBondTokenBalance(William), 10_000 ether + minTier.validityBond * 7 / 8);
        }

        console2.log("====== Verify the block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            // This block is not storing state root
            assertEq(ts.stateRoot, 0);
            assertEq(ts.tier, 74);
            assertEq(ts.prover, William);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
            assertEq(
                getBondTokenBalance(Carol),
                10_000 ether - minTier.validityBond + livenessBond * 7 / 8
            );
            assertEq(getBondTokenBalance(William), 10_000 ether + minTier.validityBond * 7 / 8);
        }
    }

    // Test summary:
    // 0. David proposes, proves, and verifies the first block.
    // 1. Alice proposes a block,
    // 2. Guardian prover directly proves the block out of proving window
    function test_taikoL1_group_9_case_4() external {
        proposeProveVerifyTheFirstBlock();

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== Guardian prover proves");
        bytes32 parentHash = FIRST_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(7 days);
        proveBlock(William, meta, parentHash, blockHash, stateRoot, 74, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            // This block is not storing state root
            assertEq(ts.stateRoot, 0);
            assertEq(ts.tier, 74);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, 0);
            assertEq(ts.prover, William);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
            assertEq(getBondTokenBalance(William), 10_000 ether + livenessBond * 7 / 8);
        }
    }
}
