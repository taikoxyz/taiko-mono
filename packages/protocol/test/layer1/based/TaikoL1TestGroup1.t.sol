// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL1TestGroup1 is TaikoL1TestGroupBase {
    // Test summary:
    // 1. Alice proposes a block
    // 2. Alice proves the block within the proving window, using the correct parent hash.
    // 3. Alice's proof is used to verify the block.
    function test_taikoL1_group_1_case_1() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TestTierProvider(cp).getTier(LibTiers.TIER_OPTIMISTIC);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

        uint96 livenessBond = L1.getConfig().livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(meta.minTier, LibTiers.TIER_OPTIMISTIC);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(blk.livenessBond, livenessBond);

            proposedAt = blk.proposedAt;

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - livenessBond);
        }

        // Prove the block
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        console2.log("====== Taylor cannot prove the block in the proving window");
        mineAndWrap(10 seconds);
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
        mineAndWrap(10 seconds);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        uint256 provenAt;

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Alice);
            assertEq(ts.validityBond, tierOp.validityBond);
            assertEq(ts.timestamp, block.timestamp);

            provenAt = ts.timestamp;

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - tierOp.validityBond);
        }

        console2.log("====== Verify block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Alice);
            assertEq(ts.validityBond, tierOp.validityBond);
            assertEq(ts.timestamp, provenAt);

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. Taylor proposes the block outside the proving window.
    // 3. Taylor's proof is used to verify the block.
    function test_taikoL1_group_1_case_2() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TestTierProvider(cp).getTier(LibTiers.TIER_OPTIMISTIC);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

        uint96 livenessBond = L1.getConfig().livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(meta.minTier, LibTiers.TIER_OPTIMISTIC);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(blk.livenessBond, livenessBond);

            proposedAt = blk.proposedAt;

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - livenessBond);
        }

        // Prove the block
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        console2.log("====== Taylor proves the block");
        mineAndWrap(7 days);
        proveBlock(Taylor, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        uint256 provenAt;

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Taylor);
            assertEq(ts.validityBond, tierOp.validityBond);
            assertEq(ts.timestamp, block.timestamp);

            provenAt = ts.timestamp;

            assertEq(
                totalTkoBalance(tko, L1, Taylor),
                10_000 ether - tierOp.validityBond + livenessBond / 2
            );
        }

        console2.log("====== Verify block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Taylor);
            assertEq(ts.validityBond, tierOp.validityBond);
            assertEq(ts.timestamp, provenAt);

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - livenessBond);
            assertEq(totalTkoBalance(tko, L1, Taylor), 10_000 ether + livenessBond / 2);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. Alice proves the block within the proving window.
    // 3. Taylor proves the block outside the proving window.
    // 4. Taylor's proof is used to verify the block.
    function test_taikoL1_group_1_case_3() external {
        vm.warp(1_000_000);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TestTierProvider(cp).getTier(LibTiers.TIER_OPTIMISTIC);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

        // Prove the block
        bytes32 parentHash1 = bytes32(uint256(9));
        bytes32 parentHash2 = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(10 seconds);

        console2.log("====== Alice proves the block first");
        proveBlock(Alice, meta, parentHash1, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor proves the block later");
        mineAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash2, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Verify block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 3);
            assertEq(blk.verifiedTransitionId, 2);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 2);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Taylor);
            assertEq(ts.validityBond, tierOp.validityBond);

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - tierOp.validityBond);
            assertEq(totalTkoBalance(tko, L1, Taylor), 10_000 ether);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. Alice proves the block within the proving window.
    // 3. Taylor proves the block outside the proving window.
    // 4. Alice's proof is used to verify the block.
    function test_taikoL1_group_1_case_4() external {
        vm.warp(1_000_000);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TestTierProvider(cp).getTier(LibTiers.TIER_OPTIMISTIC);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

        // Prove the block
        bytes32 parentHash1 = GENESIS_BLOCK_HASH;
        bytes32 parentHash2 = bytes32(uint256(9));
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(10 seconds);

        console2.log("====== Alice proves the block first");
        proveBlock(Alice, meta, parentHash1, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor proves the block later");
        mineAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash2, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Verify block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 3);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Alice);
            assertEq(ts.validityBond, tierOp.validityBond);

            assertEq(totalTkoBalance(tko, L1, Taylor), 10_000 ether - tierOp.validityBond);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. William proves the block outside the proving window.
    // 3. Taylor also proves the block outside the proving window.
    // 4. Taylor's proof is used to verify the block.
    function test_taikoL1_group_1_case_5() external {
        vm.warp(1_000_000);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TestTierProvider(cp).getTier(LibTiers.TIER_OPTIMISTIC);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

        // Prove the block
        bytes32 parentHash1 = bytes32(uint256(9));
        bytes32 parentHash2 = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(7 days);

        console2.log("====== William proves the block first");
        proveBlock(William, meta, parentHash1, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor proves the block later");
        mineAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash2, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Verify block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 3);
            assertEq(blk.verifiedTransitionId, 2);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 2);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Taylor);
            assertEq(ts.validityBond, tierOp.validityBond);

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - L1.getConfig().livenessBond);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. Alice proves the block outside the proving window, using the correct parent hash.
    // 3. Alice's proof is used to verify the block.
    function test_taikoL1_group_1_case_6() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TestTierProvider(cp).getTier(LibTiers.TIER_OPTIMISTIC);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

        uint96 livenessBond = L1.getConfig().livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(meta.minTier, LibTiers.TIER_OPTIMISTIC);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(blk.livenessBond, livenessBond);

            proposedAt = blk.proposedAt;

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - livenessBond);
        }

        // Prove the block
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        console2.log("====== Alice proves the block outside the proving window");
        mineAndWrap(7 days);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        uint256 provenAt;

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Alice);
            assertEq(ts.validityBond, tierOp.validityBond);
            assertEq(ts.timestamp, block.timestamp);

            provenAt = ts.timestamp;

            assertEq(
                totalTkoBalance(tko, L1, Alice),
                10_000 ether - tierOp.validityBond - livenessBond / 2
            );
        }

        console2.log("====== Verify block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.prover, Alice);
            assertEq(ts.validityBond, tierOp.validityBond);
            assertEq(ts.timestamp, provenAt);

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - livenessBond / 2);
        }
    }

    // Test summary:
    // 1. Alice proposes a block, assigning herself as the prover.
    function test_taikoL1_group_1_case_7_no_hooks() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block with herself as the assigned prover");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

        uint96 livenessBond = L1.getConfig().livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(meta.minTier, LibTiers.TIER_OPTIMISTIC);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(blk.livenessBond, livenessBond);

            proposedAt = blk.proposedAt;

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - livenessBond);
        }
    }
}
