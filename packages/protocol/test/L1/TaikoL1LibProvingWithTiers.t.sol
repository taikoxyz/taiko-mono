// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { LibUtils } from "../../contracts/L1/libs/LibUtils.sol";
import { GuardianVerifier } from
    "../../contracts/L1/verifiers/GuardianVerifier.sol";
import { TaikoData } from "../../contracts/L1/TaikoData.sol";
import { TaikoErrors } from "../../contracts/L1/TaikoErrors.sol";
import { TaikoL1 } from "../../contracts/L1/TaikoL1.sol";
import { TaikoToken } from "../../contracts/L1/TaikoToken.sol";
import { SignalService } from "../../contracts/signal/SignalService.sol";

import { TaikoL1TestBase } from "./TaikoL1TestBase.sol";
import { LibTiers } from "../../contracts/L1/tiers/ITierProvider.sol";

contract TaikoL1Tiers is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoL1.getConfig();

        config.blockMaxVerificationsPerTx = 0;
        config.blockMaxProposals = 10;
        config.blockRingBufferSize = 12;
        config.livenessBond = 1e18; // 1 Taiko token
        config.proposerRewardPerSecond = 1e15; // 0.001 Taiko token
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1LibProvingWithTiers is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1Tiers();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();
    }

    function test_L1_ContestingWithSameProof() external {
        giveEthAndTko(Alice, 1e7 ether, 1000 ether);
        giveEthAndTko(Carol, 1e7 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e6 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                L1.getBlock(meta.id).minTier,
                "",
                false
            );

            // Try to contest - but should revert with L1_ALREADY_PROVED
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                L1.getBlock(meta.id).minTier,
                TaikoErrors.L1_ALREADY_PROVED.selector,
                false
            );

            vm.roll(block.number + 15 * 12);

            uint16 minTier = L1.getBlock(meta.id).minTier;
            vm.warp(block.timestamp + L1.getTier(minTier).cooldownWindow + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_ContestingWithDifferentButCorrectProof() external {
        giveEthAndTko(Alice, 1e8 ether, 1000 ether);
        giveEthAndTko(Carol, 1e8 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // signalRoot instead of blockHash
            uint16 minTier = L1.getBlock(meta.id).minTier;
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                signalRoot,
                signalRoot,
                minTier,
                "",
                false
            );

            if (minTier == LibTiers.TIER_OPTIMISTIC) {
                // Try to contest
                proveBlock(
                    Carol,
                    Carol,
                    meta,
                    parentHash,
                    blockHash,
                    signalRoot,
                    minTier,
                    "",
                    false
                );

                vm.roll(block.number + 15 * 12);

                vm.warp(
                    block.timestamp + L1.getTier(minTier).cooldownWindow + 1
                );

                // Cannot verify block because it is contested..
                verifyBlock(Carol, 1);

                proveBlock(
                    Carol,
                    Carol,
                    meta,
                    parentHash,
                    blockHash,
                    signalRoot,
                    LibTiers.TIER_PSE_ZKEVM,
                    "",
                    false
                );
            }

            // Otherwise just not contest
            vm.warp(
                block.timestamp
                    + L1.getTier(LibTiers.TIER_GUARDIAN).cooldownWindow + 1
            );
            // Now can verify
            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_ContestingWithDifferentButInCorrectProof() external {
        giveEthAndTko(Alice, 1e8 ether, 1000 ether);
        giveEthAndTko(Carol, 1e8 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // signalRoot instead of blockHash
            uint16 minTier = L1.getBlock(meta.id).minTier;

            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                minTier,
                "",
                false
            );

            if (minTier == LibTiers.TIER_OPTIMISTIC) {
                // Try to contest
                proveBlock(
                    Carol,
                    Carol,
                    meta,
                    parentHash,
                    signalRoot,
                    signalRoot,
                    minTier,
                    "",
                    false
                );

                vm.roll(block.number + 15 * 12);

                vm.warp(
                    block.timestamp + L1.getTier(minTier).cooldownWindow + 1
                );

                // Cannot verify block because it is contested..
                verifyBlock(Carol, 1);

                proveBlock(
                    Carol,
                    Carol,
                    meta,
                    parentHash,
                    blockHash,
                    signalRoot,
                    LibTiers.TIER_PSE_ZKEVM,
                    "",
                    false
                );
            }

            // Otherwise just not contest
            vm.warp(
                block.timestamp
                    + L1.getTier(LibTiers.TIER_GUARDIAN).cooldownWindow + 1
            );
            // Now can verify
            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_ContestingWithInvalidBlockHash() external {
        giveEthAndTko(Alice, 1e8 ether, 1000 ether);
        giveEthAndTko(Carol, 1e8 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // signalRoot instead of blockHash
            uint16 minTier = L1.getBlock(meta.id).minTier;
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                signalRoot,
                signalRoot,
                minTier,
                "",
                false
            );

            if (minTier == LibTiers.TIER_OPTIMISTIC) {
                // Try to contest
                proveBlock(
                    Carol,
                    Carol,
                    meta,
                    parentHash,
                    blockHash,
                    signalRoot,
                    minTier,
                    "",
                    false
                );

                vm.roll(block.number + 15 * 12);

                vm.warp(
                    block.timestamp
                        + L1.getTier(LibTiers.TIER_GUARDIAN).cooldownWindow + 1
                );

                // Cannot verify block because it is contested..
                verifyBlock(Carol, 1);

                proveBlock(
                    Carol,
                    Carol,
                    meta,
                    parentHash,
                    0,
                    signalRoot,
                    LibTiers.TIER_PSE_ZKEVM,
                    TaikoErrors.L1_INVALID_EVIDENCE.selector,
                    false
                );
            }

            // Otherwise just not contest
            vm.warp(
                block.timestamp
                    + L1.getTier(LibTiers.TIER_GUARDIAN).cooldownWindow + 1
            );
            // Now can verify
            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_NonAsignedProverCannotBeFirstInProofWindowTime()
        external
    {
        giveEthAndTko(Alice, 1e8 ether, 100 ether);
        // This is a very weird test (code?) issue here.
        // If this line (or Bob's query balance) is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        console2.log("Alice balance:", tko.balanceOf(Alice));
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        giveEthAndTko(Carol, 1e8 ether, 100 ether);
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId < 10; blockId++) {
            //printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                L1.getBlock(meta.id).minTier,
                TaikoErrors.L1_NOT_ASSIGNED_PROVER.selector,
                false
            );
            vm.roll(block.number + 15 * 12);

            uint16 minTier = L1.getBlock(meta.id).minTier;
            vm.warp(block.timestamp + L1.getTier(minTier).cooldownWindow + 1);

            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_asignedProverCannotProveAfterHisWindowElapsed() external {
        giveEthAndTko(Alice, 1e8 ether, 100 ether);
        // This is a very weird test (code?) issue here.
        // If this line (or Bob's query balance) is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        console2.log("Alice balance:", tko.balanceOf(Alice));
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        giveEthAndTko(Carol, 1e8 ether, 100 ether);
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint256 blockId = 1; blockId < 10; blockId++) {
            //printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            vm.roll(block.number + 15 * 12);

            uint16 minTier = L1.getBlock(meta.id).minTier;
            vm.warp(block.timestamp + L1.getTier(minTier).cooldownWindow + 1);

            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                L1.getBlock(meta.id).minTier,
                TaikoErrors.L1_ASSIGNED_PROVER_NOT_ALLOWED.selector,
                false
            );

            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_GuardianProverCannotOverwriteIfSameProof() external {
        registerAddress("guardian", Carol);

        giveEthAndTko(Alice, 1e7 ether, 1000 ether);
        giveEthAndTko(Carol, 1e7 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e6 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                L1.getBlock(meta.id).minTier,
                "",
                false
            );

            // Try to contest - but should revert with L1_ALREADY_PROVED
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                LibTiers.TIER_GUARDIAN,
                TaikoErrors.L1_ALREADY_PROVED.selector,
                false
            );

            vm.roll(block.number + 15 * 12);

            uint16 minTier = L1.getBlock(meta.id).minTier;
            vm.warp(block.timestamp + L1.getTier(minTier).cooldownWindow + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_GuardianProverFailsWithInvalidBlockHash() external {
        registerAddress("guardian", Carol);

        giveEthAndTko(Alice, 1e7 ether, 1000 ether);
        giveEthAndTko(Carol, 1e7 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e6 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                L1.getBlock(meta.id).minTier,
                "",
                false
            );

            // Try to contest - but should revert with L1_ALREADY_PROVED
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                0,
                signalRoot,
                LibTiers.TIER_GUARDIAN,
                TaikoErrors.L1_INVALID_EVIDENCE.selector,
                false
            );

            vm.roll(block.number + 15 * 12);

            uint16 minTier = L1.getBlock(meta.id).minTier;
            vm.warp(block.timestamp + L1.getTier(minTier).cooldownWindow + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_GuardianProverCanOverwriteIfNotSameProof() external {
        registerAddress("guardian", Carol);

        giveEthAndTko(Alice, 1e7 ether, 1000 ether);
        giveEthAndTko(Carol, 1e7 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e7 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                signalRoot,
                signalRoot,
                L1.getBlock(meta.id).minTier,
                "",
                false
            );

            // Prove as guardian
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                LibTiers.TIER_GUARDIAN,
                "",
                false
            );

            vm.roll(block.number + 15 * 12);

            uint16 minTier = L1.getBlock(meta.id).minTier;
            vm.warp(block.timestamp + L1.getTier(minTier).cooldownWindow + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_IfGuardianRoleIsNotGrantedToProver() external {
        registerAddress("guardian", Alice);

        giveEthAndTko(Alice, 1e8 ether, 1000 ether);
        giveEthAndTko(Carol, 1e8 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of
            // blockhash:blockId
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                signalRoot,
                signalRoot,
                L1.getBlock(meta.id).minTier,
                "",
                false
            );

            // Prove as guardian but in reality not a guardian
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                LibTiers.TIER_GUARDIAN,
                GuardianVerifier.PERMISSION_DENIED.selector,
                false
            );

            vm.roll(block.number + 15 * 12);

            uint16 minTier = L1.getBlock(meta.id).minTier;
            vm.warp(block.timestamp + L1.getTier(minTier).cooldownWindow + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_ProveWithInvalidBlockId() external {
        registerAddress("guardian", Alice);

        giveEthAndTko(Alice, 1e8 ether, 1000 ether);
        giveEthAndTko(Carol, 1e8 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            meta.id = 100;
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                LibTiers.TIER_PSE_ZKEVM,
                TaikoErrors.L1_INVALID_BLOCK_ID.selector,
                false
            );

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_ProveWithInvalidMetahash() external {
        registerAddress("guardian", Alice);

        giveEthAndTko(Alice, 1e8 ether, 1000 ether);
        giveEthAndTko(Carol, 1e8 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are ongoing with foundry team
        giveEthAndTko(Bob, 1e8 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (uint256 blockId = 1; blockId < 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            // Mess up metahash
            meta.l1Height = 200;
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                LibTiers.TIER_PSE_ZKEVM,
                TaikoErrors.L1_BLOCK_MISMATCH.selector,
                false
            );

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_GuardianProofCannotBeOverwrittenByLowerTier() external {
        registerAddress("guardian", Carol);

        giveEthAndTko(Alice, 1e7 ether, 1000 ether);
        giveEthAndTko(Carol, 1e7 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are onsgoing with foundry team
        giveEthAndTko(Bob, 1e7 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of blockhash is
            // exchanged with signalRoot
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                signalRoot,
                signalRoot,
                L1.getBlock(meta.id).minTier,
                "",
                false
            );

            // Prove as guardian
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                blockHash,
                signalRoot,
                LibTiers.TIER_GUARDIAN,
                "",
                false
            );

            // Try to re-prove but reverts
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                signalRoot,
                signalRoot,
                LibTiers.TIER_PSE_ZKEVM,
                TaikoErrors.L1_INVALID_TIER.selector,
                false
            );

            vm.roll(block.number + 15 * 12);

            uint16 minTier = L1.getBlock(meta.id).minTier;
            vm.warp(block.timestamp + L1.getTier(minTier).cooldownWindow + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }

    function test_L1_GuardianCanReturnBondIfBlockUnprovable() external {
        registerAddress("guardian", Carol);

        giveEthAndTko(Alice, 1e7 ether, 1000 ether);
        giveEthAndTko(Carol, 1e7 ether, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));
        // This is a very weird test (code?) issue here.
        // If this line is uncommented,
        // Alice/Bob has no balance.. (Causing reverts !!!)
        // Current investigations are onsgoing with foundry team
        giveEthAndTko(Bob, 1e7 ether, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        for (
            uint256 blockId = 1; blockId < conf.blockMaxProposals * 3; blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, Bob, 1_000_000, 1024);
            //printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            // This proof cannot be verified obviously because of blockhash is
            // exchanged with signalRoot
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                signalRoot,
                signalRoot,
                L1.getBlock(meta.id).minTier,
                "",
                false
            );

            // Let's say the 10th block is unprovable
            if (blockId == 10) {
                // Prove as guardian
                proveBlock(
                    Carol,
                    Carol,
                    meta,
                    parentHash,
                    blockHash,
                    signalRoot,
                    LibTiers.TIER_GUARDIAN,
                    "",
                    true
                );

                // Credited back the bond (not transferred to the user wallet,
                // but in-contract account credited only.)
                assertEq(L1.getTaikoTokenBalance(Bob), 1 ether);
            } else {
                // Prove as guardian
                proveBlock(
                    Carol,
                    Carol,
                    meta,
                    parentHash,
                    blockHash,
                    signalRoot,
                    LibTiers.TIER_GUARDIAN,
                    "",
                    false
                );
            }
            vm.roll(block.number + 15 * 12);

            uint16 minTier = L1.getBlock(meta.id).minTier;
            vm.warp(block.timestamp + L1.getTier(minTier).cooldownWindow + 1);

            verifyBlock(Carol, 1);

            parentHash = blockHash;
        }
        printVariables("");
    }
}
