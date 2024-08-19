// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestBase.sol";

contract TaikoL1_NoCooldown is TaikoL1 {
    function getConfig() public pure override returns (TaikoData.Config memory config) {
        config = TaikoL1.getConfig();
        // over-write the following
        config.maxBlocksToVerify = 0;
        config.blockMaxProposals = 10;
        config.blockRingBufferSize = 12;
        config.livenessBond = 1e18; // 1 Taiko token
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1Test is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return TaikoL1(
            payable(
                deployProxy({ name: "taiko", impl: address(new TaikoL1_NoCooldown()), data: "" })
            )
        );
    }

    /// @dev Test we can propose, prove, then verify more blocks than
    /// 'blockMaxProposals'
    function test_L1_more_blocks_than_ring_buffer_size() external {
        giveEthAndTko(Alice, 1e8 ether, 100 ether);
        // This is a very weird test (code?) issue here.
        // If this line (or Bob's query balance) is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        console2.log("Alice balance:", tko.balanceOf(Alice));
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        giveEthAndTko(Carol, 1e8 ether, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++) {
            //printVariables("before propose");
            TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, 1024);

            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 stateRoot = bytes32(1e9 + blockId);
            proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
            vm.roll(block.number + 15 * 12);

            uint16 minTier = meta.minTier;
            vm.warp(block.timestamp + tierProvider().getTier(minTier).cooldownWindow * 60 + 1);

            verifyBlock(1);
            parentHash = blockHash;
        }
        printVariables("");
    }

    /// @dev Test more than one block can be proposed, proven, & verified in the
    ///      same L1 block.
    function test_L1_multiple_blocks_in_one_L1_block() external {
        giveEthAndTko(Alice, 1e8 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        giveEthAndTko(Carol, 1e8 ether, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId <= 20; ++blockId) {
            printVariables("before propose");
            TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, 1024);

            printVariables("after propose");

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 stateRoot = bytes32(1e9 + blockId);

            proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
            vm.roll(block.number + 15 * 12);
            uint16 minTier = meta.minTier;
            vm.warp(block.timestamp + tierProvider().getTier(minTier).cooldownWindow * 60 + 1);

            verifyBlock(2);

            TaikoData.BlockV2 memory blk = L1.getBlockV2(meta.id);
            assertEq(meta.id, blk.blockId);

            TaikoData.TransitionState memory ts = L1.getTransition(meta.id, parentHash);
            assertEq(ts.prover, Alice);

            parentHash = blockHash;
        }
        printVariables("");
    }

    /// @dev Test verifying multiple blocks in one transaction
    function test_L1_verifying_multiple_blocks_once() external {
        giveEthAndTko(Alice, 1e8 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        giveEthAndTko(Carol, 1e8 ether, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId <= conf.blockMaxProposals; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, 1024);

            printVariables("after propose");

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 stateRoot = bytes32(1e9 + blockId);

            proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");
            parentHash = blockHash;
        }

        vm.roll(block.number + 15 * 12);
        verifyBlock(conf.blockMaxProposals - 1);
        printVariables("after verify");
        verifyBlock(conf.blockMaxProposals);
        printVariables("after verify");
    }

    /// @dev Test if a given transition deadline is based on proposal time
    function test_L1_in_proving_window_logic() external {
        giveEthAndTko(Alice, 1000 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        giveEthAndTko(Carol, 1e8 ether, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId <= conf.blockMaxProposals; blockId++) {
            TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, 1024);

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
                    proveBlock(
                        Carol, meta, parentHash, blockHash, stateRoot, LibTiers.TIER_GUARDIAN, ""
                    );
                }
            } else {
                // Go into the future, outside of block proposal time + window
                vm.warp(block.timestamp + 2 days);

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

    function test_pauseProving() external {
        L1.pauseProving(true);

        giveEthAndTko(Alice, 1000 ether, 1000 ether);
        giveEthAndTko(Bob, 1e8 ether, 100 ether);

        // Proposing is still possible
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, 1024);

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

    function test_unpause() external {
        L1.pause();

        giveEthAndTko(Alice, 1000 ether, 1000 ether);
        giveEthAndTko(Bob, 1e8 ether, 100 ether);

        // Proposing is also not possible
        proposeButRevert(Alice, 1024, EssentialContract.INVALID_PAUSE_STATUS.selector);

        // unpause
        L1.unpause();

        // Proposing is possible again
        proposeBlock(Alice, 1024);
    }

    function test_getTierIds() external {
        uint16[] memory tiers = cp.getTierIds();
        assertEq(tiers[0], LibTiers.TIER_OPTIMISTIC);
        assertEq(tiers[1], LibTiers.TIER_SGX);
        assertEq(tiers[2], LibTiers.TIER_GUARDIAN);

        vm.expectRevert();
        cp.getTier(123);
    }

    function proposeButRevert(address proposer, uint24 txListSize, bytes4 revertReason) internal {
        vm.prank(proposer, proposer);
        vm.expectRevert(revertReason);
        L1.proposeBlockV2("", new bytes(txListSize));
    }
}
