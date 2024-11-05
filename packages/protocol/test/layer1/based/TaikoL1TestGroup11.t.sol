// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL10TestGroup11 is TaikoL1TestGroupBase {
    // Test summary:
    // 1. Zachary proposes a block with a custom proposer in the block parameters
    // 2. The proposal will revert as Zachary is not registered as the preconf task manager.
    function test_taikoL1_group_11_case_1() external {
        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Zachary, 10_000 ether, 1000 ether);

        ITierProvider.Tier memory tierOp = ITierProvider(tr).getTier(LibTiers.TIER_OPTIMISTIC);

        console2.log("====== Zachary proposes a block");

        TaikoData.BlockParamsV2 memory params;
        params.proposer = Alice;
        proposeBlock(Zachary, params, LibProposing.L1_INVALID_CUSTOM_PROPOSER.selector);
    }

    // Test summary:
    // 1. Zachary proposes a block with a Alice as the proposer
    // 2. Alice proves the block
    // 3. Alice verifies the block to get back her bonds.
    function test_taikoL1_group_11_case_2() external {
        registerAddress("preconf_task_manager", Zachary);

        vm.warp(1_000_000);
        printBlockAndTrans(0);

        giveEthAndTko(Zachary, 10_000 ether, 1000 ether);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        ITierProvider.Tier memory tierOp = ITierProvider(tr).getTier(LibTiers.TIER_OPTIMISTIC);

        console2.log("====== Zachary proposes a block with Alice as the proposer");

        TaikoData.BlockParamsV2 memory params;
        params.proposer = Alice;
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Zachary, params, "");

        assertEq(totalTkoBalance(tko, L1, Zachary), 10_000 ether);
        assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - L1.getConfig().livenessBond);

        console2.log("====== Alice proves the block");
        // Prove the block
        bytes32 blockHash = bytes32(uint256(10_000));
        bytes32 stateRoot = bytes32(uint256(20_000));

        mineAndWrap(10 seconds);
        proveBlock(Alice, meta, GENESIS_BLOCK_HASH, blockHash, stateRoot, meta.minTier, "");

        assertEq(totalTkoBalance(tko, L1, Zachary), 10_000 ether);
        assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether - tierOp.validityBond);

        printBlockAndTrans(meta.id);

        console2.log("====== Alice's block is verified");
        mineAndWrap(7 days);
        verifyBlock(1);

        assertEq(totalTkoBalance(tko, L1, Zachary), 10_000 ether);
        assertEq(totalTkoBalance(tko, L1, Alice), 10_000 ether);
    }
}
