// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestSetBase.sol";

contract TaikoL1TestSet1 is TaikoL1TestSetBase {
    // About this test:
    // - Alice proposes a block with Bob as the assigned prover
    // - Bob proves the block within the proving window with the right parent hash
    // - Bob's proof is used to verify the block.
    function test_taikoL1_set1__provedBy_assignedProver_inProofWindow() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 10_000 ether);
        giveEthAndTko(Bob, 10_000 ether, 10_000 ether);

        // Propose the block
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob);

        uint256 livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(meta.id);
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
            assertTrue(ts.tier != 0);
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, Bob);
            assertEq(ts.timestamp, block.timestamp); // not zero

            provenAt = ts.timestamp;
        }

        // Verify the block
        mine(1);
        vm.warp(block.timestamp + 7 days);
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
            assertTrue(ts.tier != 0);
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, Bob);
            assertEq(ts.timestamp, provenAt); // not zero
        }
    }

    // About this test:
    // - Alice proposes a block with Bob as the assigned prover
    // - David propose the block out of the proving window
    // - David proof is used to verify the block.
    function test_taikoL1_set1__provedBy_otherProver_outOfProofWindow() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 10_000 ether);
        giveEthAndTko(Bob, 10_000 ether, 10_000 ether);
        giveEthAndTko(David, 10_000 ether, 10_000 ether);

        // Propose the block
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob);

        uint256 livenessBond;
        uint256 proposedAt;
        {
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(meta.id);
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

        mine(1);
        vm.warp(block.timestamp + 7 days);
        proveBlock(David, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

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
            assertTrue(ts.tier != 0);
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, David);
            assertEq(ts.timestamp, block.timestamp); // not zero

            provenAt = ts.timestamp;
        }

        // Verify the block
        mine(1);
        vm.warp(block.timestamp + 7 days);
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
            assertTrue(ts.tier != 0);
            assertEq(ts.contestBond, 1); // not zero
            assertEq(ts.prover, David);
            assertEq(ts.timestamp, provenAt); // not zero
        }
    }
}
