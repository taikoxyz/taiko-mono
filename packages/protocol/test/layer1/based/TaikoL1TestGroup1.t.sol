// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoL1Test.sol";

contract TaikoL1TestGroup1 is TaikoL1Test {
    function getConfig() internal view override returns (TaikoData.Config memory) {
        return TaikoData.Config({
            chainId: taikoChainId,
            blockMaxProposals: 20,
            blockRingBufferSize: 25,
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18,
            stateRootSyncInternal: 2,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            ontakeForkHeight: 0 // or 1
         });
    }

    // Test summary:
    // 1. Alice proposes a block
    // 2. Alice proves the block within the proving window, using the correct parent hash.
    // 3. Alice's proof is used to verify the block.
    function test_taikoL1_group_1_case_1() external {
        mineOneBlockAndWrap(1000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(meta.minTier, minTierId);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(meta.livenessBond, livenessBond);
            assertEq(meta.proposer, Alice);
            assertEq(meta.timestamp, block.timestamp);
            assertEq(meta.anchorBlockId, block.number - 1);
            assertEq(meta.proposedAt, block.timestamp);
            assertEq(meta.proposedIn, block.number);

            proposedAt = blk.proposedAt;

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
        }

        // Prove the block
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        console2.log("====== Taylor cannot prove the block in the proving window");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(
            Taylor,
            meta,
            parentHash,
            blockHash,
            stateRoot,
            meta.minTier,
            LibProving.L1_NOT_ASSIGNED_PROVER.selector
        );

        console2.log("====== Alice proves the block");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        uint256 provenAt;

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, minTierId);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Alice);
            assertEq(ts.validityBond, minTier.validityBond);
            assertEq(ts.timestamp, block.timestamp);

            provenAt = ts.timestamp;

            assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);
        }

        console2.log("====== Verify block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.proposedAt, proposedAt);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, minTierId);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Alice);
            assertEq(ts.validityBond, minTier.validityBond);
            assertEq(ts.timestamp, provenAt);

            assertEq(getBondTokenBalance(Alice), 10_000 ether);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. Taylor proposes the block outside the proving window.
    // 3. Taylor's proof is used to verify the block.
    function test_taikoL1_group_1_case_2() external {
        mineOneBlockAndWrap(1000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        uint96 livenessBond = taikoL1.getConfig().livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(meta.minTier, minTierId);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(meta.livenessBond, livenessBond);
            assertEq(meta.proposer, Alice);
            assertEq(meta.timestamp, block.timestamp);
            assertEq(meta.anchorBlockId, block.number - 1);
            assertEq(meta.proposedAt, block.timestamp);
            assertEq(meta.proposedIn, block.number);

            proposedAt = blk.proposedAt;

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
        }

        // Prove the block
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        console2.log("====== Taylor proves the block");
        mineOneBlockAndWrap(7 days);
        proveBlock(Taylor, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        uint256 provenAt;

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, minTierId);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Taylor);
            assertEq(ts.validityBond, minTier.validityBond);
            assertEq(ts.timestamp, block.timestamp);

            provenAt = ts.timestamp;

            assertEq(
                getBondTokenBalance(Taylor),
                10_000 ether - minTier.validityBond + livenessBond * 7 / 8
            );
        }

        console2.log("====== Verify block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.proposedAt, proposedAt);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, minTierId);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Taylor);
            assertEq(ts.validityBond, minTier.validityBond);
            assertEq(ts.timestamp, provenAt);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
            assertEq(getBondTokenBalance(Taylor), 10_000 ether + livenessBond * 7 / 8);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. Alice proves the block within the proving window.
    // 3. Taylor proves the block outside the proving window.
    // 4. Taylor's proof is used to verify the block.
    function test_taikoL1_group_1_case_3() external {
        mineOneBlockAndWrap(1000);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        // Prove the block
        bytes32 parentHash1 = bytes32(uint256(9));
        bytes32 parentHash2 = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(10 seconds);

        console2.log("====== Alice proves the block first");
        proveBlock(Alice, meta, parentHash1, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor proves the block later");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash2, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Verify block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 3);
            assertEq(blk.verifiedTransitionId, 2);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 2);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Taylor);
            assertEq(ts.validityBond, minTier.validityBond);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);
            assertEq(getBondTokenBalance(Taylor), 10_000 ether);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. Alice proves the block within the proving window.
    // 3. Taylor proves the block outside the proving window.
    // 4. Alice's proof is used to verify the block.
    function test_taikoL1_group_1_case_4() external {
        mineOneBlockAndWrap(1000);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        // Prove the block
        bytes32 parentHash1 = GENESIS_BLOCK_HASH;
        bytes32 parentHash2 = bytes32(uint256(9));
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(10 seconds);

        console2.log("====== Alice proves the block first");
        proveBlock(Alice, meta, parentHash1, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor proves the block later");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash2, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Verify block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 3);
            assertEq(blk.verifiedTransitionId, 1);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Alice);
            assertEq(ts.validityBond, minTier.validityBond);

            assertEq(getBondTokenBalance(Taylor), 10_000 ether - minTier.validityBond);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. William proves the block outside the proving window.
    // 3. Taylor also proves the block outside the proving window.
    // 4. Taylor's proof is used to verify the block.
    function test_taikoL1_group_1_case_5() external {
        mineOneBlockAndWrap(1000);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        // Prove the block
        bytes32 parentHash1 = bytes32(uint256(9));
        bytes32 parentHash2 = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(7 days);

        console2.log("====== William proves the block first");
        proveBlock(William, meta, parentHash1, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor proves the block later");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash2, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Verify block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 3);
            assertEq(blk.verifiedTransitionId, 2);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 2);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Taylor);
            assertEq(ts.validityBond, minTier.validityBond);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - taikoL1.getConfig().livenessBond);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. Alice proves the block outside the proving window, using the correct parent hash.
    // 3. Alice's proof is used to verify the block.
    function test_taikoL1_group_1_case_6() external {
        mineOneBlockAndWrap(1000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        uint96 livenessBond = taikoL1.getConfig().livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(meta.minTier, minTierId);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(meta.livenessBond, livenessBond);
            assertEq(meta.proposer, Alice);
            assertEq(meta.timestamp, block.timestamp);
            assertEq(meta.anchorBlockId, block.number - 1);
            assertEq(meta.proposedAt, block.timestamp);
            assertEq(meta.proposedIn, block.number);

            proposedAt = blk.proposedAt;

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
        }

        // Prove the block
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        console2.log("====== Alice proves the block outside the proving window");
        mineOneBlockAndWrap(7 days);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        uint256 provenAt;

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, minTierId);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Alice);
            assertEq(ts.validityBond, minTier.validityBond);
            assertEq(ts.timestamp, block.timestamp);

            provenAt = ts.timestamp;

            assertEq(
                getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond - livenessBond / 8
            );
        }

        console2.log("====== Verify block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.proposedAt, proposedAt);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, minTierId);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Alice);
            assertEq(ts.validityBond, minTier.validityBond);
            assertEq(ts.timestamp, provenAt);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond / 8);
        }
    }

    // Test summary:
    // 1. Alice proposes a block, assigning herself as the prover.
    function test_taikoL1_group_1_case_7_no_hooks() external {
        mineOneBlockAndWrap(1000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block with herself as the assigned prover");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        uint96 livenessBond = taikoL1.getConfig().livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(meta.minTier, minTierId);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(meta.livenessBond, livenessBond);
            assertEq(meta.proposer, Alice);
            assertEq(meta.timestamp, block.timestamp);
            assertEq(meta.anchorBlockId, block.number - 1);
            assertEq(meta.proposedAt, block.timestamp);
            assertEq(meta.proposedIn, block.number);

            proposedAt = blk.proposedAt;

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
        }
    }
}
