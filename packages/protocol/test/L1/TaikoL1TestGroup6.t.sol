// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL1TestGroup6 is TaikoL1TestGroupBase {
    // Test summary:
    // 1. Alice proposes a block,
    // 2. Alice proves the block within the proving window, using the correct parent hash.
    // 3. Taylor contests Alice's proof.
    // 4. Alice re-proves his proof, showing Taylor is incorrect.
    // 5. Alice's proof is validated and used to verify the block.
    function test_taikoL1_group_6_case_1() external {
        vm.warp(1_000_000);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);
        ITierProvider.Tier memory tierOp = TestTierProvider(cp).getTier(LibTiers.TIER_OPTIMISTIC);
        ITierProvider.Tier memory tierSgx = TestTierProvider(cp).getTier(LibTiers.TIER_TEE);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

        console2.log("====== Alice proves the block as the assigned prover");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineAndWrap(10 seconds);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor contests Alice");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash, blockHash2, stateRoot2, meta.minTier, "");

        console2.log("====== Alice cannot proves himself is right");
        mineAndWrap(10 seconds);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, LibTiers.TIER_TEE, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.Block memory blk = L1.getBlock(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);
            assertEq(blk.livenessBond, 0);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_TEE);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, tierSgx.validityBond);
            assertEq(ts.prover, Alice);
            assertEq(ts.timestamp, block.timestamp); // not zero

            assertEq(totalTkoBalance(tko, L1, Taylor), 10_000 ether - tierOp.contestBond);
            assertEq(
                totalTkoBalance(tko, L1, Alice),
                10_000 ether - tierSgx.validityBond + tierOp.contestBond * 7 / 8
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
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, LibTiers.TIER_TEE);
            assertEq(ts.prover, Alice);

            assertEq(totalTkoBalance(tko, L1, Taylor), 10_000 ether - tierOp.contestBond);
            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether + tierOp.contestBond * 7 / 8);
        }
    }
}
