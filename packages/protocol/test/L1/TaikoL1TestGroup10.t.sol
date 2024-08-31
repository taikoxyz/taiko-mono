// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL10TestGroup1 is TaikoL1TestGroupBase {
    // Test summary:
    // 1. Alice proposes 5 blocks,
    // 2. Alice proves all 5 block within the proving window, using the correct parent hash.
    // 3. Verify up to 10 blocks
    function test_taikoL1_group_10_case_1() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose 5 block");
        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 i = 1; i <= 5; ++i) {
            TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

            // Prove the block
            bytes32 blockHash = bytes32(uint256(10_000 + i));
            bytes32 stateRoot = bytes32(uint256(20_000 + i));

            mineAndWrap(10 seconds);
            proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

            printBlockAndTrans(meta.id);

            parentHash = blockHash;
        }

        console2.log("====== Verify up to 10 block");
        mineAndWrap(7 days);
        verifyBlock(10);
        {
            (, TaikoData.SlotB memory b) = L1.getStateVariables();
            assertEq(b.lastVerifiedBlockId, 5);

            assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether);
        }
    }
}
