// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestTaikoL1Base.sol";

contract TestTaikoL1_Group10 is TestTaikoL1Base {
    // Test summary:
    // 1. Alice proposes 5 blocks,
    // 2. Alice proves all 5 block within the proving window, using the correct parent hash.
    // 3. Verify up to 10 blocks

    function test_taikoL1_group_10_case_1() external {
        mineOneBlockAndWrap(1000 seconds);
        printBlockAndTrans(0);

        mintTaikoToken(Alice, 10_000 ether);
        mintEther(Alice, 1000 ether);

        console2.log("====== Alice propose 5 block");
        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 i = 1; i <= 5; ++i) {
            TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

            // Prove the block
            bytes32 blockHash = bytes32(uint256(10_000 + i));
            bytes32 stateRoot = bytes32(uint256(20_000 + i));

            mineOneBlockAndWrap(10 seconds);
            proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

            printBlockAndTrans(meta.id);

            parentHash = blockHash;
        }

        console2.log("====== Verify up to 10 block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(10);
        {
            (, TaikoData.SlotB memory b) = taikoL1.getStateVariables();
            assertEq(b.lastVerifiedBlockId, 5);

            assertEq(getBondTokenBalance(Alice), 10_000 ether);
        }
    }
}
