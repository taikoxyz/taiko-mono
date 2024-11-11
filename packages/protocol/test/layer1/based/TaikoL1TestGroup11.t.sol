// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestTaikoL1Base.sol";

contract TestTaikoL1_Group11 is TestTaikoL1Base {
    // Test summary:
    // 1. Zachary proposes a block with a custom proposer in the block parameters
    // 2. The proposal will revert as Zachary is not registered as the preconf task manager.
    function test_taikoL1_group_11_case_1() external {
        mineOneBlockAndWrap(1000 seconds);
        printBlockAndTrans(0);

        mintTaikoToken(Zachary, 10_000 ether);
        mintEther(Zachary, 1000 ether);

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
        vm.startPrank(deployer);
        register("preconf_task_manager", Zachary);
        vm.stopPrank();

        mineOneBlockAndWrap(1000 seconds);
        printBlockAndTrans(0);

        mintTaikoToken(Zachary, 10_000 ether);
        mintEther(Zachary, 1000 ether);
        mintTaikoToken(Alice, 10_000 ether);
        mintEther(Alice, 1000 ether);

        console2.log("====== Zachary proposes a block with Alice as the proposer");

        TaikoData.BlockParamsV2 memory params;
        params.proposer = Alice;
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Zachary, params, "");

        assertEq(getBondTokenBalance(Zachary), 10_000 ether);
        assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);

        console2.log("====== Alice proves the block");
        // Prove the block
        bytes32 blockHash = bytes32(uint256(10_000));
        bytes32 stateRoot = bytes32(uint256(20_000));

        mineOneBlockAndWrap(10 seconds);
        proveBlock(Alice, meta, GENESIS_BLOCK_HASH, blockHash, stateRoot, meta.minTier, "");

        assertEq(getBondTokenBalance(Zachary), 10_000 ether);
        assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);

        printBlockAndTrans(meta.id);

        console2.log("====== Alice's block is verified");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);

        assertEq(getBondTokenBalance(Zachary), 10_000 ether);
        assertEq(getBondTokenBalance(Alice), 10_000 ether);
    }
}
