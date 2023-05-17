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
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);

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

    /// @dev So in case we have regular proving mechanism we shall check if still a cooldown happens
    /// @dev when proving a block (in a normal way).
    /// @notice In case both oracle_prover and system_prover is disbaled, there is no reason why
    /// @notice cooldowns be above 0 min tho (!).
    function test_if_oracle_is_disabled_cooldown_is_still_as_proofCooldownPeriod() external {
        registerAddress("oracle_prover", address(0));
        registerAddress("system_prover", address(0));

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks * 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(Bob, Bob, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot);

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            vm.warp(block.timestamp + 1 seconds);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

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
    function test_that_simple_oracle_prover_cannot_be_verified_only_if_normal_proof_comes_in()
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
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks * 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);
            proveBlock(
                Bob, address(0), meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot
            );

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            vm.warp(block.timestamp + 1 seconds);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is the same (bc it is an oracle proof)
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            // Cannot be verified
            assertEq(lastVerifiedBlockIdNow, lastVerifiedBlockId);

            proveBlock(
                Carol, Carol, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot
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

    /// @dev Test if system prover is the prover, cooldown is proofCooldownPeriod
    function test_if_prover_is_system_prover_cooldown_is_proofCooldownPeriod()
        external
    {
        registerAddress("system_prover", Bob);

        depositTaikoToken(Alice, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        depositTaikoToken(Carol, 1e6 * 1e8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (uint256 blockId = 1; blockId < conf.maxNumProposedBlocks * 10; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1000000, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1e10 + blockId);
            bytes32 signalRoot = bytes32(1e9 + blockId);

            uint256 realproof = blockId % conf.realProofSkipSize;

            if (realproof == 0) {
                proveBlock(
                    Carol, Carol, meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot
                );
            } else {
                proveBlock(
                    Bob, address(1), meta, parentHash, parentGasUsed, gasUsed, blockHash, signalRoot
                );
            }

            uint256 lastVerifiedBlockId = L1.getStateVariables().lastVerifiedBlockId;

            vm.warp(block.timestamp + 1 seconds);
            verifyBlock(Carol, 1);

            // Check if shortly after proving (+verify) the last verify is not the same anymore
            // no need to have a cooldown period
            uint256 lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            // It would be true anyways, but better to separate things.
            // If not real proof is necessary, also the proofCooldownPeriod needs to be elapsed to be true.
            // So separating the check.
            /// @notice: In case both system and oracle are disabled, we should set the cooldown time to 0 mins.
            if (realproof != 0) {
                assertEq(lastVerifiedBlockIdNow, lastVerifiedBlockId);
            }

            vm.warp(
                block.timestamp + L1.getStateVariables().proofTimeTarget
                    + conf.proofCooldownPeriod
            );
            verifyBlock(Carol, 1);

            lastVerifiedBlockIdNow = L1.getStateVariables().lastVerifiedBlockId;

            assertFalse(lastVerifiedBlockIdNow == lastVerifiedBlockId);

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
            printVariables("after propose");
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

    /// @dev impelement these
    function test_if_fails_if_verify_before_proof_cooldown() external {}
    function test_if_fails_multi_proving_with_only_zk_proof() external {}
    function test_if_fails_multi_proving_with_only_sgx_sig_proof() external {}
    function test_if_fails_multi_proving_with_invalid_proof_type() external {}
    function test_if_fails_multi_proving_with_not_enabled_proof_type() external {}
    function test_if_regular_prover_cannot_override() external {}
    function test_if_failsafe_account_can_set_fork_choice() external {}
    function test_if_failsafe_account_can_overwrite_fork_choice() external {}

}
