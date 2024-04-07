// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestSetBase.sol";

contract TaikoL1TestSet1 is TaikoL1TestSetBase {
    // About this test:
    // - Alice proposes a block with Bob as the assigned prover
    // - Bob proves the block within the proving window with the right parent hash
    // - Bob's proof is used to verify the block.
    function test_taikoL1_set1__provedBy_assignedProver_inProofWindow_then_verified() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 10_000 ether);
        giveEthAndTko(Bob, 10_000 ether, 10_000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 10_000 ether);

        console2.log("====== Alice propose a block with bob as the assigned prover");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob);

        uint96 livenessBond = L1.getConfig().livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(meta.minTier, LibTiers.TIER_OPTIMISTIC);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, livenessBond);

            proposedAt = blk.proposedAt;

            assertEq(tko.balanceOf(Alice), 10_000 ether);
            assertEq(tko.balanceOf(Bob), 10_000 ether - livenessBond);
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
            TaikoErrors.L1_NOT_ASSIGNED_PROVER.selector
        );

        console2.log("====== Bob proves the block");
        mineAndWrap(10 seconds);
        proveBlock(Bob, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        ITierProvider.Tier memory tierOp = TierProviderV1(cp).getTier(LibTiers.TIER_OPTIMISTIC);
        uint256 provenAt;

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, Bob);
            assertEq(ts.validityBond, tierOp.validityBond + livenessBond);
            assertEq(ts.timestamp, block.timestamp);

            provenAt = ts.timestamp;

            assertEq(tko.balanceOf(Bob), 10_000 ether - livenessBond - tierOp.validityBond);
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
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, Bob);
            assertEq(ts.validityBond, tierOp.validityBond + livenessBond);
            assertEq(ts.timestamp, provenAt);

            assertEq(tko.balanceOf(Bob), 10_000 ether);
        }
    }

    // About this test:
    // - Alice proposes a block with Bob as the assigned prover
    // - Taylor propose the block out of the proving window
    // - Taylor proof is used to verify the block.
    function test_taikoL1_set1__provedBy_otherProver_outOfProofWindow_then_verified() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 10_000 ether);
        giveEthAndTko(Bob, 10_000 ether, 10_000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 10_000 ether);

        console2.log("====== Alice propose a block with bob as the assigned prover");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob);

        uint96 livenessBond = L1.getConfig().livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(meta.minTier, LibTiers.TIER_OPTIMISTIC);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, livenessBond);

            proposedAt = blk.proposedAt;

            assertEq(tko.balanceOf(Alice), 10_000 ether);
            assertEq(tko.balanceOf(Bob), 10_000 ether - livenessBond);
        }

        // Prove the block
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(7 days);

        console2.log("====== Bob cannot prove the block out of the proving window");
        proveBlock(
            Bob,
            meta,
            parentHash,
            blockHash,
            stateRoot,
            meta.minTier,
            TaikoErrors.L1_ASSIGNED_PROVER_NOT_ALLOWED.selector
        );

        console2.log("====== Taylor proves the block");
        mineAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        ITierProvider.Tier memory tierOp = TierProviderV1(cp).getTier(LibTiers.TIER_OPTIMISTIC);
        uint256 provenAt;

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, Taylor);
            assertEq(ts.validityBond, tierOp.validityBond);
            assertEq(ts.timestamp, block.timestamp);

            provenAt = ts.timestamp;

            assertEq(tko.balanceOf(Bob), 10_000 ether - livenessBond);
            assertEq(tko.balanceOf(Taylor), 10_000 ether - tierOp.validityBond);
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
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, Taylor);
            assertEq(ts.validityBond, tierOp.validityBond);
            assertEq(ts.timestamp, provenAt);

            assertEq(tko.balanceOf(Bob), 10_000 ether - livenessBond);
            assertEq(tko.balanceOf(Taylor), 10_000 ether);
        }
    }
}
