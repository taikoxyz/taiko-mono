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

        // Propose the block
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
        }

        // Prove the block
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        // Taylor cannot prove the block in the proving window
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
        }

        // Verify the block
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
        }
    }

    // About this test:
    // - Alice proposes a block with Bob as the assigned prover
    // - Bob proves the block within the proving window with the right parent hash
    // - Taylor contesnted bob
    // - William proves Bob is correct, Taylor is wrong
    // - William's proof is used to verify the block.
    function test_taikoL1_set1__provedBy_assignedProver_inProofWindow_contested_and_won()
        external
    {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 10_000 ether);
        giveEthAndTko(Bob, 10_000 ether, 10_000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 10_000 ether);
        giveEthAndTko(William, 10_000 ether, 10_000 ether);

        console2.log("====== Alice propose a block with bob as the assigned prover");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob);

        uint256 livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(meta.minTier, LibTiers.TIER_OPTIMISTIC);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(blk.assignedProver, Bob);
            assertTrue(blk.livenessBond != 0);

            livenessBond = blk.livenessBond;
            proposedAt = blk.proposedAt;
        }

        console2.log("====== Bob proves the block as the assigned prover");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(10 seconds);
        proveBlock(Bob, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        uint256 provenAt;
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, livenessBond);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, Bob);
            assertEq(ts.timestamp, block.timestamp); // not zero

            provenAt = ts.timestamp;
        }

        console2.log("====== Taylor contests Bob");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash, blockHash2, stateRoot2, meta.minTier, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, livenessBond);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contester, Taylor);
            assertTrue(ts.contestBond > 1); // not zero
            assertEq(ts.prover, Bob);
            assertEq(ts.timestamp, block.timestamp); // not zero

            provenAt = ts.timestamp;
        }

        console2.log("====== William proves Bob is right");
        mineAndWrap(10 seconds);
        proveBlock(William, meta, parentHash, blockHash, stateRoot, LibTiers.TIER_SGX, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, livenessBond);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_SGX);
            assertEq(ts.contester, address(0));
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, William);
            assertEq(ts.timestamp, block.timestamp); // not zero

            provenAt = ts.timestamp;
        }

        console2.log("====== Verify the block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.assignedProver, Bob);
            // assertEq(blk.livenessBond, livenessBond);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_SGX);
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, William);
            assertEq(ts.timestamp, provenAt); // not zero
        }
    }

    // About this test:
    // - Alice proposes a block with Bob as the assigned prover
    // - Taylor propose the block out of the proving window
    // - Taylor proof is used to verify the block.
    function test_taikoL1_set1__provedBy_otherProver_outOfProofWindow() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 10_000 ether);
        giveEthAndTko(Bob, 10_000 ether, 10_000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 10_000 ether);

        // Propose the block
        console2.log("====== Alice propose a block with bob as the assigned prover");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob);

        uint256 livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(meta.minTier, LibTiers.TIER_OPTIMISTIC);

            assertEq(blk.nextTransitionId, 1);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(blk.assignedProver, Bob);
            assertTrue(blk.livenessBond != 0);

            livenessBond = blk.livenessBond;
            proposedAt = blk.proposedAt;
        }

        // Prove the block
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(7 days);
        console2.log("====== Taylor (not the assigned prover) proves the block");
        proveBlock(Taylor, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        uint256 provenAt;
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, livenessBond);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, Taylor);
            assertEq(ts.timestamp, block.timestamp); // not zero

            provenAt = ts.timestamp;
        }

        // Verify the block
        console2.log("====== verify the block");
        mineAndWrap(7 days);
        verifyBlock(2);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.proposedAt, proposedAt);
            assertEq(blk.assignedProver, Bob);
            assertEq(blk.livenessBond, livenessBond);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_OPTIMISTIC);
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, Taylor);
            assertEq(ts.timestamp, provenAt); // not zero
        }
    }
}
