// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { LibUtils } from "../contracts/L1/libs/LibUtils.sol";
import { TaikoConfig } from "../contracts/L1/TaikoConfig.sol";
import { TaikoData } from "../contracts/L1/TaikoData.sol";
import { TaikoErrors } from "../contracts/L1/TaikoErrors.sol";
import { TaikoL1 } from "../contracts/L1/TaikoL1.sol";
import { TaikoToken } from "../contracts/L1/TaikoToken.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { TaikoL1TestBase } from "./TaikoL1TestBase.t.sol";

contract TaikoL1Oracle is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.txListCacheExpiry = 5 minutes;
        config.maxVerificationsPerTx = 0;
        config.maxNumProposedBlocks = 10;
        config.ringBufferSize = 12;
        config.proofCooldownPeriod = 5 minutes;
        config.realProofSkipSize = 10;
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1OracleTest is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1Oracle();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();
        registerAddress(L1.getVerifierName(100), address(new Verifier()));
        registerAddress("oracle_prover", Alice);
        registerAddress("system_prover", Alice);
    }

    function testOracleProverWithSignature() external {
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        TaikoData.BlockMetadata memory meta = proposeBlock(Bob, 1_000_000, 1024);
        proveBlock(
            Bob,
            Bob,
            meta,
            GENESIS_BLOCK_HASH,
            10_000,
            10_001,
            bytes32(uint256(0x11)),
            bytes32(uint256(0x12))
        );
        TaikoData.BlockEvidence memory evidence = TaikoData.BlockEvidence({
            metaHash: LibUtils.hashMetadata(meta),
            parentHash: GENESIS_BLOCK_HASH,
            blockHash: bytes32(uint256(0x11)),
            signalRoot: bytes32(uint256(0x12)),
            graffiti: 0x0,
            prover: address(0),
            parentGasUsed: 10_000,
            gasUsed: 40_000,
            verifierId: 0,
            proof: new bytes(0)
        });
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(AlicePK, keccak256(abi.encode(evidence)));

        evidence.verifierId = v;
        evidence.proof = bytes.concat(r, s);

        vm.prank(Carol, Carol);
        L1.proveBlock(meta.id, abi.encode(evidence));
        TaikoData.ForkChoice memory fc =
            L1.getForkChoice(1, GENESIS_BLOCK_HASH, 10_000);

        assertEq(fc.blockHash, bytes32(uint256(0x11)));
        assertEq(fc.signalRoot, bytes32(uint256(0x12)));
        assertEq(fc.provenAt, block.timestamp);
        assertEq(fc.prover, address(0));
        assertEq(fc.gasUsed, 40_000);
    }

    function testOracleProverCanAlwaysOverwriteIfNotSameProof() external {
        // Carol is the oracle prover
        registerAddress("oracle_prover", Carol);
        registerAddress("system_prover", Carol);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint256 blockId = 1;
        TaikoData.BlockMetadata memory meta =
            proposeBlock(Alice, 1_000_000, 1024);

        for (uint256 i = 0; i < 5; ++i) {
            uint32 parentGasUsed = uint32(10_000 + i);

            // Bob proves the block
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                10_001,
                bytes32(uint256(0x11)),
                bytes32(uint256(0x12))
            );

            uint256 provenAt = block.timestamp;

            TaikoData.ForkChoice memory fc =
                L1.getForkChoice(blockId, parentHash, parentGasUsed);

            if (i == 0) {
                assertFalse(fc.key == 0);
            } else {
                assertEq(fc.key, 0);
            }
            assertEq(fc.blockHash, bytes32(uint256(0x11)));
            assertEq(fc.signalRoot, bytes32(uint256(0x12)));
            assertEq(fc.provenAt, provenAt);
            assertEq(fc.prover, Bob);
            assertEq(fc.gasUsed, 10_001);

            // Carol - who is oracle prover - can overwrite with same proof
            vm.warp(block.timestamp + 10 seconds);
            proveBlock(
                Carol,
                address(0),
                meta,
                parentHash,
                parentGasUsed,
                10_002,
                bytes32(uint256(0x11)),
                bytes32(uint256(0x12))
            );

            provenAt = block.timestamp;

            fc = L1.getForkChoice(blockId, parentHash, parentGasUsed);

            if (i == 0) {
                assertFalse(fc.key == 0);
            } else {
                assertEq(fc.key, 0);
            }
            assertEq(fc.blockHash, bytes32(uint256(0x11)));
            assertEq(fc.signalRoot, bytes32(uint256(0x12)));
            assertEq(fc.provenAt, provenAt);
            assertEq(fc.prover, address(0));
            assertEq(fc.gasUsed, 10_002);
        }
    }

    function testOracleProverCannotOverwriteIfSameProof() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint256 blockId = 1;
        TaikoData.BlockMetadata memory meta =
            proposeBlock(Alice, 1_000_000, 1024);

        for (uint256 i = 0; i < 5; ++i) {
            uint32 parentGasUsed = uint32(10_000 + i);

            // Bob proves the block
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                10_001,
                bytes32(uint256(0x11)),
                bytes32(uint256(0x12))
            );

            uint256 provenAt = block.timestamp;

            TaikoData.ForkChoice memory fc =
                L1.getForkChoice(blockId, parentHash, parentGasUsed);

            if (i == 0) {
                assertFalse(fc.key == 0);
            } else {
                assertEq(fc.key, 0);
            }
            assertEq(fc.blockHash, bytes32(uint256(0x11)));
            assertEq(fc.signalRoot, bytes32(uint256(0x12)));
            assertEq(fc.provenAt, provenAt);
            assertEq(fc.prover, Bob);
            assertEq(fc.gasUsed, 10_001);

            // Carol cannot prove the fork choice again
            vm.warp(block.timestamp + 10 seconds);
            vm.expectRevert();
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                parentGasUsed,
                10_002,
                bytes32(uint256(0x21)),
                bytes32(uint256(0x22))
            );

            // Alice, the oracle prover,  cannot overwrite with same parameters
            vm.warp(block.timestamp + 10 seconds);

            vm.expectRevert(TaikoErrors.L1_SAME_PROOF.selector);
            proveBlock(
                Alice,
                address(0),
                meta,
                parentHash,
                parentGasUsed,
                10_001,
                bytes32(uint256(0x11)),
                bytes32(uint256(0x12))
            );

            verifyBlock(Carol, 1);

            fc = L1.getForkChoice(blockId, parentHash, parentGasUsed);

            if (i == 0) {
                assertFalse(fc.key == 0);
            } else {
                assertEq(fc.key, 0);
            }
            assertEq(fc.blockHash, bytes32(uint256(0x11)));
            assertEq(fc.signalRoot, bytes32(uint256(0x12)));
            assertEq(fc.provenAt, provenAt);
            assertEq(fc.prover, Bob);
            assertEq(fc.gasUsed, 10_001);

            vm.warp(block.timestamp + 10 seconds);
        }
    }

    /// @dev So in case we have regular proving mechanism we shall check if
    /// still a cooldown happens
    /// @dev when proving a block (in a normal way).
    /// @notice In case both oracle_prover and system_prover is disbaled, there
    /// is no reason why
    /// @notice cooldowns be above 0 min tho (!).
    function test_if_oracle_is_disabled_cooldown_is_still_as_proofCooldownPeriod(
    )
        external
    {
        registerAddress("oracle_prover", address(0));
        registerAddress("system_prover", address(0));

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;

        for (
            uint256 blockId = 1;
            blockId < conf.maxNumProposedBlocks * 10;
            blockId++
        ) {
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            uint256 lastVerifiedBlockId =
                L1.getStateVariables().lastVerifiedBlockId;

            vm.warp(block.timestamp + 1 seconds);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not
            // the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow =
                L1.getStateVariables().lastVerifiedBlockId;

            assertEq(lastVerifiedBlockIdNow, lastVerifiedBlockId);

            vm.warp(block.timestamp + 5 minutes);
            verifyBlock(Carol, 1);

            lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test if oracle prover is the only prover it cannot be verified
    function test_that_simple_oracle_prover_cannot_be_verified_only_if_normal_proof_comes_in(
    )
        external
    {
        // Bob is an oracle prover now
        registerAddress("oracle_prover", Bob);
        registerAddress("system_prover", Bob);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;

        for (
            uint256 blockId = 1;
            blockId < conf.maxNumProposedBlocks * 10;
            blockId++
        ) {
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                address(0),
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            uint256 lastVerifiedBlockId =
                L1.getStateVariables().lastVerifiedBlockId;

            vm.warp(block.timestamp + 1 seconds);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is the
            // same (bc it is an oracle proof)
            uint256 lastVerifiedBlockIdNow =
                L1.getStateVariables().lastVerifiedBlockId;

            // Cannot be verified
            assertEq(lastVerifiedBlockIdNow, lastVerifiedBlockId);

            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            vm.warp(block.timestamp + 1 seconds);
            vm.warp(block.timestamp + 5 minutes);
            verifyBlock(Carol, 1);

            lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            // Can be verified now bc regular user overwrote it
            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test if system proofs can be verified
    function test_if_system_proofs_can_be_verified_without_regular_proofs()
        external
    {
        registerAddress("system_prover", Bob);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;

        for (
            uint256 blockId = 1;
            blockId < conf.maxNumProposedBlocks * 10;
            blockId++
        ) {
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            uint256 lastVerifiedBlockId =
                L1.getStateVariables().lastVerifiedBlockId;

            // Need to wait config.systemProofCooldownPeriod
            vm.warp(block.timestamp + conf.systemProofCooldownPeriod);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not
            // the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow =
                L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test if system prover cannot be overwritten
    function test_if_systemProver_can_prove_but_regular_provers_can_overwrite()
        external
    {
        registerAddress("system_prover", Bob);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;

        for (
            uint256 blockId = 1;
            blockId < conf.maxNumProposedBlocks * 10;
            blockId++
        ) {
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            uint256 realProof = blockId % conf.realProofSkipSize;

            if (realProof == 0) {
                proveBlock(
                    Carol,
                    Carol,
                    meta,
                    parentHash,
                    parentGasUsed,
                    gasUsed,
                    blockHash,
                    signalRoot
                );
            } else {
                proveBlock(
                    Bob,
                    address(1),
                    meta,
                    parentHash,
                    parentGasUsed,
                    gasUsed,
                    blockHash,
                    signalRoot
                );
            }

            uint256 lastVerifiedBlockId =
                L1.getStateVariables().lastVerifiedBlockId;

            // Carol could overwrite it
            if (realProof != 0) {
                proveBlock(
                    Carol,
                    Carol,
                    meta,
                    parentHash,
                    parentGasUsed,
                    gasUsed,
                    blockHash,
                    signalRoot
                );
            }

            vm.warp(block.timestamp + 1 seconds);
            vm.warp(block.timestamp + 5 minutes);

            TaikoData.ForkChoice memory fc =
                L1.getForkChoice(blockId, parentHash, parentGasUsed);

            if (realProof != 0) assertEq(fc.prover, Carol);

            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not
            // the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow =
                L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test if there is no system/oracle proofs
    function test_if_there_is_no_system_and_oracle_provers() external {
        registerAddress("system_prover", address(0));
        registerAddress("oracle_prover", address(0));

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1_000_000;

        for (
            uint256 blockId = 1;
            blockId < conf.maxNumProposedBlocks * 10;
            blockId++
        ) {
            TaikoData.BlockMetadata memory meta =
                proposeBlock(Alice, 1_000_000, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob,
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            uint256 lastVerifiedBlockId =
                L1.getStateVariables().lastVerifiedBlockId;

            // Carol could not overwrite it
            vm.expectRevert(TaikoErrors.L1_ALREADY_PROVEN.selector);
            proveBlock(
                Carol,
                Carol,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot
            );

            /// @notice: Based on the current codebase we still need to wait
            /// even if the system and oracle proofs are disbaled, which
            /// @notice: in such case best to set 0 mins (cause noone could
            /// overwrite a valid fk).
            vm.warp(block.timestamp + conf.proofCooldownPeriod);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not
            // the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow =
                L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }
}
