// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoL1Test.sol";

contract TaikoL1TestGroup2 is TaikoL1Test {
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
    // 1. Alice proposes a block, Alice as the prover.
    // 2. Alice proves the block within the proving window, with correct parent hash.
    // 3. Taylor contests Alice's proof.
    // 4. William proves Alice is correct and Taylor is wrong.
    // 5. William's proof is used to verify the block.
    function test_taikoL1_group_2_case_1() external {
        mineOneBlockAndWrap(1000 seconds);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tier3 = tierProvider().getTier(73);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== Alice proves the block as the assigned prover");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(10 seconds);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor contests Alice");
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
            assertEq(ts.prover, Alice);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);
            assertEq(getBondTokenBalance(Taylor), 10_000 ether - minTier.contestBond);
        }

        console2.log("====== William proves Alice is right");
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

            assertEq(getBondTokenBalance(Alice), 10_000 ether);
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
    // 2. Alice proves the block within the proving window, with correct parent hash.
    // 3. Taylor contests Alice's proof.
    // 4. William proves Taylor is correct and Alice is wrong.
    // 5. William's proof is used to verify the block.
    function test_taikoL1_group_2_case_2() external {
        mineOneBlockAndWrap(1000 seconds);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        giveEthAndTko(William, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tier3 = tierProvider().getTier(73);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== Alice proves the block as the assigned prover");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(10 seconds);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor contests Alice");
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
            assertEq(ts.prover, Alice);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);
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

            assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);

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

            assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);

            uint256 quarterReward = minTier.validityBond * 7 / 8 / 4;
            assertEq(getBondTokenBalance(Taylor), 10_000 ether + quarterReward * 3);
            assertEq(getBondTokenBalance(William), 10_000 ether + quarterReward);
        }
    }
}
