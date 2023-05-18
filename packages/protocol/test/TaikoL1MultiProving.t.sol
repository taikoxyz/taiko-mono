// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {AddressManager} from "../contracts/common/AddressManager.sol";
import {LibUtils} from "../contracts/L1/libs/LibUtils.sol";
import {TaikoConfig} from "../contracts/L1/TaikoConfig.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {TaikoErrors} from "../contracts/L1/TaikoErrors.sol";
import {TaikoL1} from "../contracts/L1/TaikoL1.sol";
import {TaikoToken} from "../contracts/L1/TaikoToken.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoL1TestBase} from "./TaikoL1TestBase.t.sol";

contract TaikoL1Oracle is TaikoL1 {
    function getConfig() public pure override returns (TaikoData.Config memory config) {
        config = TaikoConfig.getConfig();

        config.txListCacheExpiry = 5 minutes;
        config.maxVerificationsPerTx = 0;
        config.maxNumProposedBlocks = 10;
        config.ringBufferSize = 12;
        config.proofCooldownPeriod = 5 minutes;
        config.realProofSkipSize = 10;
        config.proofToggleMask = 3; // It means SGX proof is necessary
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
    }

    function testProvingWithSgx() external {
        depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint256 blockId = 1;
        TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);

        for (uint256 i = 0; i < 5; ++i) {
            uint32 parentGasUsed = uint32(10000 + i);

            // Bob proves the block
            proveBlockWithSgxSignature(
                Bob,
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                10001,
                bytes32(uint256(0x11)),
                bytes32(uint256(0x12))
            );

            uint256 provenAt = block.timestamp;

            TaikoData.ForkChoice memory fc = L1.getForkChoice(blockId, parentHash, parentGasUsed);

            vm.warp(block.timestamp + 1);
            vm.warp(block.timestamp + conf.proofCooldownPeriod);
            verifyBlock(Carol, 1);

            if (i == 0) {
                assertFalse(fc.key == 0);
            } else {
                assertEq(fc.key, 0);
            }
            assertEq(fc.blockHash, bytes32(uint256(0x11)));
            assertEq(fc.signalRoot, bytes32(uint256(0x12)));
            assertEq(fc.provenAt, provenAt);
            assertEq(fc.prover, Bob);
            assertEq(fc.gasUsed, 10001);
        }
    }

    /// @dev Test we can propose, prove, then verify more blocks than 'maxNumProposedBlocks'
    function test_cooldown_more_blocks_than_ring_buffer_size() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks * 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlockWithSgxSignature(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            vm.warp(block.timestamp + 4 minutes + 59 seconds);
            verifyBlock(Carol, 1);

            assertEq(lastVerifiedBlockId, L1.getStateVariables().lastVerifiedBlockId);

            vm.warp(block.timestamp + 1 seconds);
            verifyBlock(Carol, 1);
            assertFalse(lastVerifiedBlockId == L1.getStateVariables().lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Test if system works with both proof submitted
    function test_multi_proving_with_both_signatures() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks * 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlockWithSgxSignature(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            // Need to wait config.proofCooldownPeriod
            vm.warp(block.timestamp + conf.proofCooldownPeriod);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Not possible to verify below proof cooldown time
    function test_if_fails_if_verify_before_proof_cooldown() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks * 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlockWithSgxSignature(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            // Need to wait config.proofCooldownPeriod
            vm.warp(block.timestamp + 4 minutes);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertEq(lastVerifiedBlockIdNow,lastVerifiedBlockId);
            // Mine 1 min 1 sec to be above the 5 mins
            vm.warp(block.timestamp + 61);
            verifyBlock(Carol, 1);

            lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
    }

    /// @dev Not possible to prove if only ZKP is present
    function test_if_fails_multi_proving_with_only_zk_proof() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            // Try only with ZK proof
            vm.expectRevert(TaikoErrors.L1_NOT_ALL_REQ_PROOF_VERIFIED.selector);
            proveBlock(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            // Need to wait config.proofCooldownPeriod
            vm.warp(block.timestamp + 4 minutes);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertEq(lastVerifiedBlockIdNow,lastVerifiedBlockId);
            // Mine 1 min 1 sec to be above the 5 mins
            vm.warp(block.timestamp + 61);
            verifyBlock(Carol, 1);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
    }

    /// @dev Try with SGX only and fail
    function test_if_fails_multi_proving_with_only_sgx_sig_proof() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            // Try only with SGX sig proof
            vm.expectRevert(TaikoErrors.L1_NOT_ALL_REQ_PROOF_VERIFIED.selector);
            proveBlockWithSgxSignatureOnly(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            // Need to wait config.proofCooldownPeriod
            vm.warp(block.timestamp + 4 minutes);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertEq(lastVerifiedBlockIdNow,lastVerifiedBlockId);
            // Mine 1 min 1 sec to be above the 5 mins
            vm.warp(block.timestamp + 61);
            verifyBlock(Carol, 1);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
    }

    /// @dev Try with invalid proof type (=0)
    function test_if_fails_multi_proving_with_invalid_proof_type() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            vm.expectRevert(TaikoErrors.L1_INVALID_PROOFTYPE.selector);
            proveBlockWithSpecificType(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot, 0);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            // Need to wait config.proofCooldownPeriod
            vm.warp(block.timestamp + 4 minutes);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertEq(lastVerifiedBlockIdNow,lastVerifiedBlockId);
            // Mine 1 min 1 sec to be above the 5 mins
            vm.warp(block.timestamp + 61);
            verifyBlock(Carol, 1);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
    }

    /// @dev Test if proof type is not enabled
    function test_if_fails_multi_proving_with_not_enabled_proof_type() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            vm.expectRevert(TaikoErrors.L1_NOT_ENABLED_PROOFTYPE.selector);
            proveBlockWithSpecificType(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot, 4);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            // Need to wait config.proofCooldownPeriod
            vm.warp(block.timestamp + 4 minutes);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertEq(lastVerifiedBlockIdNow,lastVerifiedBlockId);
            // Mine 1 min 1 sec to be above the 5 mins
            vm.warp(block.timestamp + 61);
            verifyBlock(Carol, 1);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
    }

    /// @dev Test if regular prover cannot overwrite
    function test_if_regular_prover_cannot_override() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks * 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlockWithSgxSignature(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            vm.expectRevert(TaikoErrors.L1_ALREADY_PROVEN.selector);
            proveBlockWithSgxSignature(Carol, Carol, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);

            // Need to wait config.proofCooldownPeriod
            vm.warp(block.timestamp + conf.proofCooldownPeriod);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev At some point set forkchoice by the 'failsafe' mechanism
    function test_if_failsafe_account_can_set_fork_choice() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks * 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            // 'Prove' every second block with the failsafe mechanism
            if(blockId % 2 == 0) {
                TaikoData.TypedProof[] memory blockProofs;

                TaikoData.BlockEvidence memory evidence = TaikoData.BlockEvidence({
                    metaHash: LibUtils.hashMetadata(meta),
                    parentHash: parentHash,
                    blockHash: blockHash,
                    signalRoot: signalRoot,
                    graffiti: 0x0,
                    prover: FailsafeProver,
                    parentGasUsed: parentGasUsed,
                    gasUsed: gasUsed,
                    blockProofs: blockProofs
                });

                vm.prank(FailsafeProver,FailsafeProver);
                L1.setForkChoice(meta.id,abi.encode(evidence));

                // Wait enough because now provenAt set in the future - exactly at proofTimeTarget to not
                // cause any 'damage' to the tokenomics
                vm.warp(block.timestamp + (L1.getStateVariables().proofTimeTarget + 1) + conf.proofCooldownPeriod);
            }
            else {
                proveBlockWithSgxSignature(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);
                vm.warp(block.timestamp + (conf.proofCooldownPeriod + 1));
            }

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Kind of same as above but not setting the fork choice directly but overwriting it
    function test_if_failsafe_account_can_overwrite_fork_choice() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks * 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            proveBlockWithSgxSignature(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);
            
            // Overwrite fk
            TaikoData.TypedProof[] memory blockProofs;

            TaikoData.BlockEvidence memory evidence = TaikoData.BlockEvidence({
                metaHash: LibUtils.hashMetadata(meta),
                parentHash: parentHash,
                blockHash: blockHash,
                signalRoot: signalRoot,
                graffiti: 0x0,
                prover: FailsafeProver,
                parentGasUsed: parentGasUsed,
                gasUsed: gasUsed,
                blockProofs: blockProofs
            });

            vm.prank(FailsafeProver,FailsafeProver);
            L1.setForkChoice(meta.id,abi.encode(evidence));

            // Wait enough because now provenAt set in the future - exactly at proofTimeTarget to not
            // cause any 'damage' to the tokenomics
            vm.warp(block.timestamp + (L1.getStateVariables().proofTimeTarget + 1) + conf.proofCooldownPeriod);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

    /// @dev Any random account cannot overwrite / call setForkChoice
    function test_if_non_failsafe_account_cannot_call_setForkChoice_function() external {
        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks * 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            // Proving OK
            proveBlockWithSgxSignature(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);
            
            // Overwrite fk - cannot without the rights
            TaikoData.TypedProof[] memory blockProofs;

            TaikoData.BlockEvidence memory evidence = TaikoData.BlockEvidence({
                metaHash: LibUtils.hashMetadata(meta),
                parentHash: parentHash,
                blockHash: blockHash,
                signalRoot: signalRoot,
                graffiti: 0x0,
                prover: FailsafeProver,
                parentGasUsed: parentGasUsed,
                gasUsed: gasUsed,
                blockProofs: blockProofs
            });

            vm.prank(Bob,Bob);
            vm.expectRevert(TaikoErrors.L1_NO_AUTH_TO_OVERWRITE_FK.selector);
            L1.setForkChoice(meta.id,abi.encode(evidence));

            // Wait enough because now provenAt set in the future - exactly at proofTimeTarget to not
            // cause any 'damage' to the tokenomics
            vm.warp(block.timestamp + (L1.getStateVariables().proofTimeTarget + 1) + conf.proofCooldownPeriod);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }

}
