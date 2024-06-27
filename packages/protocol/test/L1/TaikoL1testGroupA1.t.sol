// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL1TestGroupA1 is TaikoL1TestGroupBase {
    function test_taikoL1_group_a_1_case_1() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose 5 block");
        bytes32 parentHash = GENESIS_BLOCK_HASH;

        uint256 forkHeight = L1.getConfig().forkHeight;

        uint256 i = 1;
        for (; i < forkHeight; ++i) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");

            // Prove the block
            bytes32 blockHash = bytes32(uint256(10_000 + i));
            bytes32 stateRoot = bytes32(uint256(20_000 + i));

            mineAndWrap(10 seconds);
            proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

            printBlockAndTrans(meta.id);

            parentHash = blockHash;
        }

        for (; i < forkHeight + 5; ++i) {
            TaikoData.BlockMetadata2 memory meta2 = proposeBlock2(Alice, "");

            // Prove the block
            bytes32 blockHash = bytes32(uint256(10_000 + i));
            bytes32 stateRoot = bytes32(uint256(20_000 + i));

            mineAndWrap(10 seconds);
            // proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

            printBlockAndTrans(meta2.id);

            parentHash = blockHash;
        }

        console2.log("====== Verify up to 10 block");
        mineAndWrap(7 days);
        // verifyBlock(10);
        // {
        //     (, TaikoData.SlotB memory b) = L1.getStateVariables();
        //     assertEq(b.lastVerifiedBlockId, 8);

        //     assertEq(tko.balanceOf(Alice), 10_000 ether);
        // }
    }
}
