// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL10TestGroup1 is TaikoL1TestGroupBase {
    // Test summary:
    // 1. Alice proposes 5 blocks, assigning Bob as the prover.
    // 2. Bob proves all 5 block within the proving window, using the correct parent hash.
    // 3. Verify up to 10 blocks
    function test_taikoL1_group_10_case_1() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Bob, 10_000 ether, 1000 ether);
        giveEthAndTko(Taylor, 10_000 ether, 1000 ether);

        ITierProvider.Tier memory tierOp = TestTierProvider(cp).getTier(LibTiers.TIER_OPTIMISTIC);
        uint96 livenessBond = L1.getConfig().livenessBond;
        console2.log("====== Alice propose 5 block with bob as the assigned prover");
        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 i = 1; i <= 5; ++i) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob, "");

            // Prove the block

            bytes32 blockHash = bytes32(uint256(10_000 + i));
            bytes32 stateRoot = bytes32(uint256(20_000 + i));

            console2.log("====== Bob proves the block");
            mineAndWrap(10 seconds);
            proveBlock(Bob, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

            printBlockAndTrans(meta.id);

            parentHash = blockHash;
        }

        console2.log("====== Verify up to 10 block");
        mineAndWrap(7 days);
        verifyBlock(10);
        {
            (TaikoData.SlotA memory a, TaikoData.SlotB memory b) = L1.getStateVariables();
            assertEq(b.lastVerifiedBlockId, 5);

            assertEq(tko.balanceOf(Bob), 10_000 ether);
            assertEq(tko.balanceOf(Alice), 10_000 ether);
        }
    }
}
