// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL1TestGroupA1 is TaikoL1TestGroupBase {
    function test_taikoL1_group_a_1_case_1() external {
        vm.warp(1_000_000);
        mine(1);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose 5 block");
        bytes32 parentHash = GENESIS_BLOCK_HASH;

        uint64 forkHeight = L1.getConfig().forkHeight;

        uint64 i = 1;
        for (; i < forkHeight; ++i) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(i);
            assertTrue(blk.livenessBond > 0);
            assertEq(blk.assignedProver, address(0));
            assertEq(blk.anchorBlockId, block.number - 1);
            assertEq(blk.timestamp, block.timestamp);

            // Prove the block
            bytes32 blockHash = bytes32(uint256(10_000 + i));
            bytes32 stateRoot = bytes32(uint256(20_000 + i));

            mineAndWrap(10 seconds);

            proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
            parentHash = blockHash;

            printBlockAndTrans(meta.id);
            blk = L1.getBlock(i);
            assertEq(blk.livenessBond, 0);
            assertEq(blk.assignedProver, address(0));
        }

        for (; i <= forkHeight + 5; ++i) {
            TaikoData.BlockMetadata2 memory meta2 = proposeBlock2(Alice, "");
            printBlockAndTrans(meta2.id);
            TaikoData.Block memory blk = L1.getBlock(i);
            assertEq(blk.livenessBond, 0);
            assertEq(blk.assignedProver, address(0));
            assertEq(blk.anchorBlockId, block.number - 1);
            assertEq(blk.timestamp, block.timestamp);

            // Prove the block
            bytes32 blockHash = bytes32(uint256(10_000 + i));
            bytes32 stateRoot = bytes32(uint256(20_000 + i));

            mineAndWrap(10 seconds);

            proveBlock2(Alice, meta2, parentHash, blockHash, stateRoot, meta2.minTier, "");
            parentHash = blockHash;

            printBlockAndTrans(meta2.id);
            blk = L1.getBlock(i);
            assertEq(blk.livenessBond, 0);
            assertEq(blk.assignedProver, address(0));
        }

        console2.log("====== Verify many blocks");
        mineAndWrap(7 days);
        verifyBlock(forkHeight + 10);
        {
            (, TaikoData.SlotB memory b) = L1.getStateVariables();
            assertEq(b.lastVerifiedBlockId, forkHeight + 5);

            assertEq(tko.balanceOf(Alice), 10_000 ether);
        }
    }
}
