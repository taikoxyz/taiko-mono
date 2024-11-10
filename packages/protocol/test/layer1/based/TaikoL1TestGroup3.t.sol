// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestTaikoL1Base.sol";

contract TestTaikoL1_Group3 is TestTaikoL1Base {
    // Test summary:
    // 1. Alice proposes a block,
    // 2. James proves the block outside the proving window, using the correct parent hash.
    // 3. Taylor contests James' proof.
    // 4. William proves James is correct and Taylor is wrong.
    // 5. William's proof is used to verify the block.
    function test_taikoL1_group_3_case_1() external {
        mineOneBlockAndWrap(1000 seconds);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(James, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);

        ITierProvider.Tier memory tier3 = tierProvider.getTier(0, 73);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== James proves the block");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(7 days);
        proveBlock(James, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor contests James");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineOneBlockAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash, blockHash2, stateRoot2, meta.minTier, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, minTierId);
            assertEq(ts.contester, Taylor);
            assertEq(ts.contestBond, minTier.contestBond);
            assertEq(ts.validityBond, minTier.validityBond);
            assertEq(ts.prover, James);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
            assertEq(
                getBondTokenBalance(James),
                10_000 ether - minTier.validityBond + livenessBond * 7 / 8
            );
            assertEq(getBondTokenBalance(Taylor), 10_000 ether - minTier.contestBond);
        }

        console2.log("====== William proves James is right");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(William, meta, parentHash, blockHash, stateRoot, 73, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, 73);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, tier3.validityBond);
            assertEq(ts.prover, William);
            assertEq(ts.timestamp, block.timestamp); // not zero

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
            assertEq(getBondTokenBalance(Taylor), 10_000 ether - minTier.contestBond);
            assertEq(
                getBondTokenBalance(William),
                10_000 ether - tier3.validityBond + minTier.contestBond * 7 / 8
            );
        }

        console2.log("====== Verify the block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            // assertEq(blk.livenessBond, livenessBond);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, 73);
            assertEq(ts.prover, William);

            assertEq(getBondTokenBalance(William), 10_000 ether + minTier.contestBond * 7 / 8);
        }
    }

    // Test summary:
    // 1. Alice proposes a block, Alice as the prover.
    // 2. James proves the block outside the proving window, with correct parent hash.
    // 3. Taylor contests James' proof.
    // 4. William proves Taylor is correct and James is wrong.
    // 5. William's proof is used to verify the block.
    function test_taikoL1_group_3_case_2() external {
        mineOneBlockAndWrap(1000 seconds);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(James, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);

        ITierProvider.Tier memory tier3 = tierProvider.getTier(0, 73);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== James proves the block");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(7 days);
        proveBlock(James, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor contests James");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineOneBlockAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash, blockHash2, stateRoot2, meta.minTier, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, minTierId);
            assertEq(ts.contester, Taylor);
            assertEq(ts.contestBond, minTier.contestBond);
            assertEq(ts.validityBond, minTier.validityBond);
            assertEq(ts.prover, James);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
            assertEq(
                getBondTokenBalance(James),
                10_000 ether - minTier.validityBond + livenessBond * 7 / 8
            );
            assertEq(getBondTokenBalance(Taylor), 10_000 ether - minTier.contestBond);
        }

        console2.log("====== William proves Tayler is right");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(William, meta, parentHash, blockHash2, stateRoot2, 73, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, 73);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, tier3.validityBond);
            assertEq(ts.prover, William);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
            assertEq(
                getBondTokenBalance(James),
                10_000 ether - minTier.validityBond + livenessBond * 7 / 8
            );

            uint256 quarterReward = minTier.validityBond * 7 / 8 / 4;
            assertEq(getBondTokenBalance(Taylor), 10_000 ether + quarterReward * 3);
            assertEq(
                getBondTokenBalance(William), 10_000 ether - tier3.validityBond + quarterReward
            );
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
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, 73);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, tier3.validityBond);
            assertEq(ts.prover, William);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);

            uint256 quarterReward = minTier.validityBond * 7 / 8 / 4;
            assertEq(
                getBondTokenBalance(James),
                10_000 ether - minTier.validityBond + livenessBond * 7 / 8
            );
            assertEq(getBondTokenBalance(Taylor), 10_000 ether + quarterReward * 3);
            assertEq(getBondTokenBalance(William), 10_000 ether + quarterReward);
        }
    }
}
