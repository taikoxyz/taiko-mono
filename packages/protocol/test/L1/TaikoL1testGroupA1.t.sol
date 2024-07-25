// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL1ForkA1 is TaikoL1 {
    function getConfig() public pure override returns (TaikoData.Config memory config) {
        config = TaikoL1.getConfig();
        config.maxBlocksToVerify = 0;
        config.blockMaxProposals = 20;
        config.blockRingBufferSize = 25;
        config.stateRootSyncInternal = 2;
        config.ontakeForkHeight = 10;
    }

    function setBlockMinTier(uint64 _blockId, uint8 _minTierId) external {
        require(_minTierId != 0, "invalid _minTierId");
        TaikoData.Config memory config = TaikoL1.getConfig();

        TaikoData.Block storage blk = state.blocks[_blockId % config.blockRingBufferSize];
        require(blk.blockId == _blockId, "L1_INVALID_BLOCK_ID");

        blk.minTierId = _minTierId;
    }
}

contract TaikoL1TestGroupA1 is TaikoL1TestGroupBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return TaikoL1(
            payable(deployProxy({ name: "taiko", impl: address(new TaikoL1ForkA1()), data: "" }))
        );
    }

    // Test summary:
    // - Use the v2 on block 10 - ontakeForkHeight = 10
    // - propose and prove block 1 to 9 using v1
    // - propose and prove block 10 to 15 using v2
    // - try to verify more than 15 blocks to verify all 15 blocks are verified.
    function test_taikoL1_group_a1_case_1() external {
        vm.warp(1_000_000);
        mine(1);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose 5 block");
        bytes32 parentHash = GENESIS_BLOCK_HASH;

        uint64 ontakeForkHeight = L1.getConfig().ontakeForkHeight;

        uint64 i = 1;
        for (; i < ontakeForkHeight; ++i) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, "");
            printBlockAndTrans(meta.id);
            TaikoData.Block memory blk = L1.getBlock(i);
            assertTrue(blk.livenessBond > 0);
            assertEq(blk.assignedProver, address(0));
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(blk.proposedIn, block.number);

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

        TaikoData.BlockParamsV2 memory params;
        for (; i <= ontakeForkHeight + 5; ++i) {
            TaikoData.BlockMetadataV2 memory metaV2 = proposeBlockV2(Alice, params, "");
            printBlockAndTrans(metaV2.id);
            TaikoData.Block memory blk = L1.getBlock(i);
            assertEq(blk.livenessBond, 0);
            assertEq(blk.assignedProver, address(0));
            assertEq(blk.proposedAt, block.timestamp);
            assertEq(blk.proposedIn, block.number - 1);

            // Prove the block
            bytes32 blockHash = bytes32(uint256(10_000 + i));
            bytes32 stateRoot = bytes32(uint256(20_000 + i));

            mineAndWrap(10 seconds);

            TaikoL1ForkA1(payable(L1)).setBlockMinTier(metaV2.id, LibTiersV2.TIER_SGX_ONTAKE);
            proveBlock2(
                Alice, metaV2, parentHash, blockHash, stateRoot, LibTiersV2.TIER_SGX_ONTAKE, ""
            );
            parentHash = blockHash;

            printBlockAndTrans(metaV2.id);
            blk = L1.getBlock(i);
            assertEq(blk.livenessBond, 0);
            assertEq(blk.assignedProver, address(0));
        }

        console2.log("====== Verify many blocks");
        mineAndWrap(7 days);
        verifyBlock(ontakeForkHeight + 10);
        {
            (, TaikoData.SlotB memory b) = L1.getStateVariables();
            assertEq(b.lastVerifiedBlockId, ontakeForkHeight + 5);

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether);
        }
    }
}
