// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL1TestGroup4 is TaikoL1TestGroupBase {
    // Test summary:
    // 1. Alice proposes a block, Alice is the prover.
    // 2. Alice proves the block within the proving window, using the correct parent hash.
    // 3. Taylor contests then proves Alice is wrong  in the same transaction with a higher-tier
    // proof.
    // 4. Taylor's proof is used to verify the block.
    function test_taikoL1_group_4_case_1() external {
        vm.warp(1_000_000);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TestTierProvider(cp).getTier(LibTiers.TIER_OPTIMISTIC);
        ITierProvider.Tier memory tierSgx = TestTierProvider(cp).getTier(LibTiers.TIER_SGX);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

        console2.log("====== Alice proves the block as the assigned prover");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(10 seconds);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor contests Alice with a higher tier proof");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash, blockHash2, stateRoot2, LibTiers.TIER_SGX, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, LibTiers.TIER_SGX);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, tierSgx.validityBond);
            assertEq(ts.prover, Taylor);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - tierOp.validityBond);
            assertEq(
                tko.balanceOf(Taylor),
                10_000 ether - tierSgx.validityBond + tierOp.validityBond * 7 / 8
            );
        }

        console2.log("====== Verify the block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            // assertEq(blk.livenessBond, livenessBond);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, LibTiers.TIER_SGX);
            assertEq(ts.prover, Taylor);

            assertEq(totalTkoBalance(tko, L1, Taylor), 10_000 ether + tierOp.validityBond * 7 / 8);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. David proves the block outside the proving window, using the correct parent hash.
    // 3. Taylor contests then proves David is wrong in the same transaction with a higher-tier
    // proof.
    // 4. Taylor's proof is used to verify the block.
    function test_taikoL1_group_4_case_2() external {
        vm.warp(1_000_000);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        giveEthAndTko(David, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TestTierProvider(cp).getTier(LibTiers.TIER_OPTIMISTIC);
        ITierProvider.Tier memory tierSgx = TestTierProvider(cp).getTier(LibTiers.TIER_SGX);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

        uint96 livenessBond = L1.getConfig().livenessBond;

        console2.log("====== Alice proves the block as the assigned prover");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(7 days);
        proveBlock(David, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor contests David with a higher tier proof");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash, blockHash2, stateRoot2, LibTiers.TIER_SGX, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, LibTiers.TIER_SGX);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, tierSgx.validityBond);
            assertEq(ts.prover, Taylor);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - livenessBond);
            assertEq(tko.balanceOf(David), 10_000 ether - tierOp.validityBond + livenessBond / 2);
            assertEq(
                tko.balanceOf(Taylor),
                10_000 ether - tierSgx.validityBond + tierOp.validityBond * 7 / 8
            );
        }

        console2.log("====== Verify the block");
        mineAndWrap(7 days);
        verifyBlock(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, LibTiers.TIER_SGX);
            assertEq(ts.prover, Taylor);

            assertEq(totalTkoBalance(tko, L1, Taylor), 10_000 ether + tierOp.validityBond * 7 / 8);
        }
    }
}
