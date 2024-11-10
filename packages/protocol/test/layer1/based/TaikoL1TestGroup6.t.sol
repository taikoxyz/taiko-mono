// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestTaikoL1Base.sol";

contract TestTaikoL1_Group6 is TestTaikoL1Base {
    // Test summary:
    // 1. Alice proposes a block,
    // 2. Alice proves the block within the proving window, using the correct parent hash.
    // 3. Taylor contests Alice's proof.
    // 4. Alice re-proves his proof, showing Taylor is incorrect.
    // 5. Alice's proof is validated and used to verify the block.
    function test_taikoL1_group_6_case_1() external {
        mineOneBlockAndWrap(1000 seconds);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);

        ITierProvider.Tier memory tier3 = tierProvider.getTier(0, 73);

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

        console2.log("====== Alice cannot proves himself is right");
        mineOneBlockAndWrap(10 seconds);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, 73, "");

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
            assertEq(ts.prover, Alice);
            assertEq(ts.timestamp, block.timestamp); // not zero

            assertEq(getBondTokenBalance(Taylor), 10_000 ether - minTier.contestBond);
            assertEq(
                getBondTokenBalance(Alice),
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

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash);
            assertEq(ts.stateRoot, stateRoot);
            assertEq(ts.tier, 73);
            assertEq(ts.prover, Alice);

            assertEq(getBondTokenBalance(Taylor), 10_000 ether - minTier.contestBond);
            assertEq(getBondTokenBalance(Alice), 10_000 ether + minTier.contestBond * 7 / 8);
        }
    }
}
