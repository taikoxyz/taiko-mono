// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestTaikoL1Base.sol";

contract TestTaikoL1_Group12 is TestTaikoL1Base {
    /// @dev Test we can propose, prove, then verify more blocks than
    /// 'blockMaxProposals'
    function test_taikoL1_group_12_more_blocks_than_ring_buffer_size() external {
        giveEthAndTko(Alice, 1_000_000 ether, 1_000_000 ether);
        giveEthAndTko(Bob, 1_000_000 ether, 1_000_000 ether);
        giveEthAndTko(Carol, 1_000_000 ether, 1_000_000 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId < getConfig().blockMaxProposals * 3; blockId++) {
            //printStateVariables("before propose");
            TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

            //printStateVariables("after propose");
            mineOneBlockAndWrap(12 seconds);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 stateRoot = bytes32(1e9 + blockId);
            proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
            vm.roll(block.number + 15 * 12);

            uint16 minTier = meta.minTier;
            vm.warp(block.timestamp + tierProvider.getTier(0, minTier).cooldownWindow * 60 + 1);

            taikoL1.verifyBlocks(1);
            parentHash = blockHash;
        }
        printStateVariables("");
    }

    /// @dev Test more than one block can be proposed, proven, & verified in the
    ///      same L1 block.
    function test_taikoL1_group_12_multiple_blocks_in_one_L1_block() external {
        giveEthAndTko(Alice, 1_000_000 ether, 1_000_000 ether);
        console2.log("Alice balance:", bondToken.balanceOf(Alice));
        giveEthAndTko(Carol, 1_000_000 ether, 1_000_000 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId <= 20; ++blockId) {
            printStateVariables("before propose");
            TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

            printStateVariables("after propose");

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 stateRoot = bytes32(1e9 + blockId);

            proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
            vm.roll(block.number + 15 * 12);
            uint16 minTier = meta.minTier;
            vm.warp(block.timestamp + tierProvider.getTier(0, minTier).cooldownWindow * 60 + 1);

            taikoL1.verifyBlocks(2);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(meta.id, blk.blockId);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, parentHash);
            assertEq(ts.prover, Alice);

            parentHash = blockHash;
        }
        printStateVariables("");
    }

    /// @dev Test verifying multiple blocks in one transaction
    function test_taikoL1_group_12_verifying_multiple_blocks_once() external {
        giveEthAndTko(Alice, 1_000_000 ether, 1_000_000 ether);
        console2.log("Alice balance:", bondToken.balanceOf(Alice));
        giveEthAndTko(Carol, 1_000_000 ether, 1_000_000 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId <= getConfig().blockMaxProposals; blockId++) {
            printStateVariables("before propose");
            TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

            printStateVariables("after propose");

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 stateRoot = bytes32(1e9 + blockId);

            proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
            parentHash = blockHash;
        }

        vm.roll(block.number + 15 * 12);
        taikoL1.verifyBlocks(getConfig().blockMaxProposals - 1);
        printStateVariables("after verify");
        taikoL1.verifyBlocks(getConfig().blockMaxProposals);
        printStateVariables("after verify");
    }

    /// @dev Test if a given transition deadline is based on proposal time
    function test_taikoL1_group_12_in_proving_window_logic() external {
        giveEthAndTko(Alice, 1_000_000 ether, 1_000_000 ether);
        giveEthAndTko(Carol, 1_000_000 ether, 1_000_000 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId <= getConfig().blockMaxProposals; blockId++) {
            TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

            bytes32 blockHash;
            bytes32 stateRoot;
            if (blockId % 2 == 0) {
                // Stay within proving window
                vm.warp(block.timestamp + 60);

                blockHash = bytes32(1e10 + blockId);
                stateRoot = bytes32(1e9 + blockId);

                bytes32 secondTransitionHash = randBytes32();

                // Within window and first transition -> Should revert if not assigned prover or
                // guardian
                proveBlock(
                    Carol,
                    meta,
                    parentHash,
                    secondTransitionHash,
                    stateRoot,
                    meta.minTier,
                    LibProving.L1_NOT_ASSIGNED_PROVER.selector
                );

                // Only guardian or assigned prover is allowed
                if (blockId % 4 == 0) {
                    proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
                } else {
                    proveBlock(Carol, meta, parentHash, blockHash, stateRoot, 74, "");
                }
            } else {
                // Go into the future, outside of block proposal time + window
                mineOneBlockAndWrap(2 days);

                blockHash = bytes32(1e10 + blockId);
                stateRoot = bytes32(1e9 + blockId);

                bytes32 secondTransitionHash = randBytes32();

                // Carol can prove since it is outside of the window
                proveBlock(
                    Carol, meta, parentHash, secondTransitionHash, stateRoot, meta.minTier, ""
                );

                parentHash = blockHash;
            }
            parentHash = blockHash;
        }
    }

    function test_taikoL1_group_12_pauseProving() external {
        vm.prank(deployer);
        taikoL1.pauseProving(true);

        giveEthAndTko(Alice, 1_000_000 ether, 1_000_000 ether);
        giveEthAndTko(Bob, 1_000_000 ether, 1_000_000 ether);

        // Proposing is still possible
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        // Proving is not, so supply the revert reason to proveBlock
        proveBlock(
            Bob,
            meta,
            GENESIS_BLOCK_HASH,
            bytes32("01"),
            bytes32("02"),
            meta.minTier,
            LibProving.L1_PROVING_PAUSED.selector
        );
    }

    function test_taikoL1_group_12_unpause() external {
        vm.prank(deployer);
        taikoL1.pause();

        giveEthAndTko(Alice, 1_000_000 ether, 1_000_000 ether);
        giveEthAndTko(Bob, 1_000_000 ether, 1_000_000 ether);

        // Proposing is also not possible
        proposeBlock(Alice, EssentialContract.INVALID_PAUSE_STATUS.selector);

        // unpause
        vm.prank(deployer);
        taikoL1.unpause();

        // Proposing is possible again
        proposeBlock(Alice, "");
    }
}
