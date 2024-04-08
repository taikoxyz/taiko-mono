// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestGroupBase.sol";

contract TaikoL1TestGroup8 is TaikoL1TestGroupBase {
    // Test summary:
    // 1. Alice proposes a block, assigning Bob as the prover.
    // 2. TaikoL1 is paused.
    // 3. Bob attempts to prove the block within the proving window.
    // 4. Alice tries to propose another block.
    // 5. TaikoL1 is unpaused.
    // 6. Bob attempts again to prove the first block within the proving window.
    // 7. Alice tries to propose another block.
    function test_taikoL1_group_8_case_1() external {
        vm.warp(1_000_000);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Bob, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block with bob as the assigned prover");

        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob, "");

        console2.log("====== Pause TaikoL1");
        mineAndWrap(10 seconds);
        vm.prank(L1.owner());
        L1.pause();

        console2.log("====== Bob proves the block first after L1 paused");

        bytes32 parentHash1 = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));
        proveBlock(
            Bob,
            meta,
            parentHash1,
            blockHash,
            stateRoot,
            meta.minTier,
            EssentialContract.INVALID_PAUSE_STATUS.selector
        );

        console2.log("====== Alice tries to propose another block after L1 paused");
        proposeBlock(Alice, Bob, EssentialContract.INVALID_PAUSE_STATUS.selector);

        console2.log("====== Unpause TaikoL1");
        mineAndWrap(10 seconds);
        vm.prank(L1.owner());
        L1.unpause();

        console2.log("====== Bob proves the block first after L1 unpaused");
        proveBlock(Bob, meta, parentHash1, blockHash, stateRoot, meta.minTier, "");
        console2.log("====== Alice tries to propose another block after L1 unpaused");
        proposeBlock(Alice, Bob, "");
    }

    // Test summary:
    // 1. Alice proposes a block, assigning Bob as the prover.
    // 2. TaikoL1 proving is paused.
    // 3. Bob attempts to prove the block within the proving window.
    // 4. Alice tries to propose another block.
    // 5. TaikoL1 proving is unpaused.
    // 6. Bob attempts again to prove the first block within the proving window.
    // 7. Alice tries to propose another block.
    function test_taikoL1_group_8_case_2() external {
        vm.warp(1_000_000);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);
        giveEthAndTko(Bob, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block with bob as the assigned prover");

        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, Bob, "");

        console2.log("====== Pause TaikoL1 proving");
        mineAndWrap(10 seconds);
        vm.prank(L1.owner());
        L1.pauseProving(true);

        console2.log("====== Bob proves the block first after L1 proving paused");

        bytes32 parentHash1 = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));
        proveBlock(
            Bob,
            meta,
            parentHash1,
            blockHash,
            stateRoot,
            meta.minTier,
            TaikoErrors.L1_PROVING_PAUSED.selector
        );

        console2.log("====== Alice tries to propose another block after L1 proving paused");
        proposeBlock(Alice, Bob, "");

        console2.log("====== Unpause TaikoL1 proving");
        mineAndWrap(10 seconds);
        vm.prank(L1.owner());
        L1.pauseProving(false);

        console2.log("====== Bob proves the block first after L1 proving unpaused");
        proveBlock(Bob, meta, parentHash1, blockHash, stateRoot, meta.minTier, "");
    }

    // Test summary:
    // 1. Gets a block that doesn't exist
    // 2. Gets a transition by ID & hash that doesn't exist.
    function test_taikoL1_group_8_case_3() external {
        vm.expectRevert(TaikoErrors.L1_INVALID_BLOCK_ID.selector);
        L1.getBlock(2);

        vm.expectRevert(TaikoErrors.L1_TRANSITION_NOT_FOUND.selector);
        L1.getTransition(0, 2);

        vm.expectRevert(TaikoErrors.L1_TRANSITION_NOT_FOUND.selector);
        L1.getTransition(0, randBytes32());

        vm.expectRevert(TaikoErrors.L1_INVALID_BLOCK_ID.selector);
        L1.getTransition(3, randBytes32());
    }
}
