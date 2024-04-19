// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL1TestGroup5 is TaikoL1TestGroupBase {
    // Test summary:
    // 1. Alice proposes a block, assigning Bob as the prover.
    // 2. Guardian prover directly proves the block.
    // 3. Guardian prover re-proves the same transition and fails.
    // 4. Guardian prover proves the block again with a different transition.
    // 5. William contests the guardian prover using a lower-tier proof and fails.
    function test_taikoL1_group_5_case_1() external {
        vm.warp(1_000_000);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Bob, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block with bob as the assigned prover");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob, "");

        console2.log("====== Guardian prover proves");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(10 seconds);
        proveBlock(William, meta, parentHash, blockHash, stateRoot, LibTiers.TIER_GUARDIAN, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_GUARDIAN);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1);
            assertEq(ts.validityBond, 0);
            assertEq(ts.prover, address(gp));
            assertEq(ts.timestamp, block.timestamp);

            assertEq(tko.balanceOf(Bob), 10_000 ether);
            assertEq(tko.balanceOf(William), 10_000 ether);
        }

        console2.log("====== Guardian re-approve with the same transition");
        mineAndWrap(10 seconds);
        proveBlock(
            William,
            meta,
            parentHash,
            blockHash,
            stateRoot,
            LibTiers.TIER_GUARDIAN,
            TaikoErrors.L1_ALREADY_PROVED.selector
        );

        console2.log("====== Guardian re-approve with a different transition");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineAndWrap(10 seconds);
        proveBlock(William, meta, parentHash, blockHash2, stateRoot2, LibTiers.TIER_GUARDIAN, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, LibTiers.TIER_GUARDIAN);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1);
            assertEq(ts.validityBond, 0);
            assertEq(ts.prover, address(gp));
            assertEq(ts.timestamp, block.timestamp);

            assertEq(tko.balanceOf(Bob), 10_000 ether);
            assertEq(tko.balanceOf(William), 10_000 ether);
        }

        console2.log("====== William contests with a lower tier proof");
        mineAndWrap(10 seconds);
        proveBlock(
            William,
            meta,
            parentHash,
            blockHash,
            stateRoot,
            LibTiers.TIER_SGX,
            TaikoErrors.L1_INVALID_TIER.selector
        );

        console2.log("====== Verify the block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, LibTiers.TIER_GUARDIAN);
            assertEq(ts.contestBond, 1);
            assertEq(ts.prover, address(gp));

            assertEq(tko.balanceOf(Bob), 10_000 ether);
            assertEq(tko.balanceOf(William), 10_000 ether);
        }
    }

    // Test summary:
    // 1. Alice proposes a block, Bob is the prover.
    // 2. Bob proves the block.
    // 3. Guardian prover re-proves the same transition and fails.
    // 4. Guardian prover proves the block with a different transition.
    // 5. William contests the guardian prover using a lower-tier proof and fails.
    function test_taikoL1_group_5_case_2() external {
        vm.warp(1_000_000);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Bob, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TierProviderV1(cp).getTier(LibTiers.TIER_OPTIMISTIC);

        console2.log("====== Alice propose a block with bob as the assigned prover");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob, "");

        console2.log("====== Bob proves the block");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(10 seconds);
        proveBlock(Bob, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Guardian re-approve with the same transition");
        mineAndWrap(10 seconds);
        proveBlock(
            William,
            meta,
            parentHash,
            blockHash,
            stateRoot,
            LibTiers.TIER_GUARDIAN,
            TaikoErrors.L1_ALREADY_PROVED.selector
        );

        console2.log("====== Guardian re-approve with a different transition");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineAndWrap(10 seconds);
        proveBlock(William, meta, parentHash, blockHash2, stateRoot2, LibTiers.TIER_GUARDIAN, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, LibTiers.TIER_GUARDIAN);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1);
            assertEq(ts.validityBond, 0);
            assertEq(ts.prover, address(gp));
            assertEq(ts.timestamp, block.timestamp);

            assertEq(tko.balanceOf(Bob), 10_000 ether - tierOp.validityBond);
            assertEq(tko.balanceOf(William), 10_000 ether);
        }

        console2.log("====== Verify the block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, LibTiers.TIER_GUARDIAN);
            assertEq(ts.contestBond, 1);
            assertEq(ts.prover, address(gp));

            assertEq(tko.balanceOf(Bob), 10_000 ether - tierOp.validityBond);
            assertEq(tko.balanceOf(William), 10_000 ether);
        }
    }

    // Test summary:
    // 1. Alice proposes a block, assigning Bob as the prover.
    // 2. David proves the block outside the proving window.
    // 3. Guardian prover re-proves the same transition and fails.
    // 4. Guardian prover proves the block with a different transition.
    // 5. William contests the guardian prover using a lower-tier proof and fails.
    function test_taikoL1_group_5_case_3() external {
        vm.warp(1_000_000);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Bob, 10_000 ether, 1000 ether);
        giveEthAndTko(David, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TierProviderV1(cp).getTier(LibTiers.TIER_OPTIMISTIC);

        console2.log("====== Alice propose a block with bob as the assigned prover");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob, "");

        uint96 livenessBond = L1.getConfig().livenessBond;

        console2.log("====== David proves the block");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(7 days);
        proveBlock(David, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Guardian re-approve with the same transition");
        mineAndWrap(10 seconds);
        proveBlock(
            William,
            meta,
            parentHash,
            blockHash,
            stateRoot,
            LibTiers.TIER_GUARDIAN,
            TaikoErrors.L1_ALREADY_PROVED.selector
        );

        console2.log("====== Guardian re-approve with a different transition");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineAndWrap(10 seconds);
        proveBlock(William, meta, parentHash, blockHash2, stateRoot2, LibTiers.TIER_GUARDIAN, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, LibTiers.TIER_GUARDIAN);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1);
            assertEq(ts.validityBond, 0);
            assertEq(ts.prover, address(gp));
            assertEq(ts.timestamp, block.timestamp);

            assertEq(tko.balanceOf(Bob), 10_000 ether - livenessBond);
            assertEq(tko.balanceOf(David), 10_000 ether - tierOp.validityBond);
            assertEq(tko.balanceOf(William), 10_000 ether);
        }

        console2.log("====== Verify the block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, LibTiers.TIER_GUARDIAN);
            assertEq(ts.contestBond, 1);
            assertEq(ts.prover, address(gp));

            assertEq(tko.balanceOf(Bob), 10_000 ether - livenessBond);
            assertEq(tko.balanceOf(David), 10_000 ether - tierOp.validityBond);
            assertEq(tko.balanceOf(William), 10_000 ether);
        }
    }

    // Test summary:
    // 1. Alice proposes a block, assigning Bob as the prover.
    // 2. Guardian prover directly proves the block out of proving window
    function test_taikoL1_group_5_case_4() external {
        vm.warp(1_000_000);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Bob, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block with bob as the assigned prover");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob, "");

        console2.log("====== Guardian prover proves");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(7 days);
        proveBlock(William, meta, parentHash, blockHash, stateRoot, LibTiers.TIER_GUARDIAN, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_GUARDIAN);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1);
            assertEq(ts.validityBond, 0);
            assertEq(ts.prover, address(gp));
            assertEq(ts.timestamp, block.timestamp);

            assertEq(tko.balanceOf(Bob), 10_000 ether - L1.getConfig().livenessBond);
            assertEq(tko.balanceOf(William), 10_000 ether);
        }
    }
}
