// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL1ForkA2 is TaikoL1 {
    function getConfig() public pure override returns (TaikoData.Config memory config) {
        config = TaikoL1.getConfig();
        config.maxBlocksToVerify = 0;
        config.blockMaxProposals = 10;
        config.blockRingBufferSize = 15;
        config.stateRootSyncInternal = 2;
        config.forkHeight = 0;
        // config.forkHeight = 1; // works the same
    }
}

contract TaikoL1TestGroupA2 is TaikoL1TestGroupBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return TaikoL1(
            payable(deployProxy({ name: "taiko", impl: address(new TaikoL1ForkA2()), data: "" }))
        );
    }

    // Test summary:
    // - Use the v2 immediately - forkHeight = 0 or 1
    // - propose and prove 5 blocks
    // - try to verify more than 5 blocks to verify all 5 blocks are verified.
    function test_taikoL1_group_a2_case_1() external {
        vm.warp(1_000_000);
        mine(1);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        proposeBlock(Alice, TaikoErrors.L1_FORK_ERROR.selector);

        TaikoData.BlockParams2 memory params;
        for (uint64 i = 1; i <= 5; ++i) {
            TaikoData.BlockMetadata2 memory meta2 = proposeBlock2(Alice, params, "");
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
        verifyBlock(10);
        {
            (, TaikoData.SlotB memory b) = L1.getStateVariables();
            assertEq(b.lastVerifiedBlockId, 5);

            assertEq(tko.balanceOf(Alice), 10_000 ether);
        }
    }
}
