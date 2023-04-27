// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {AddressManager} from "../contracts/common/AddressManager.sol";
import {LibUtils} from "../contracts/L1/libs/LibUtils.sol";
import {TaikoConfig} from "../contracts/L1/TaikoConfig.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {TaikoL1} from "../contracts/L1/TaikoL1.sol";
import {TaikoToken} from "../contracts/L1/TaikoToken.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoL1TestBase} from "./TaikoL1TestBase.t.sol";

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
    }

    function testOracleProverWithSignature() external {
        depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        TaikoData.BlockMetadata memory meta = proposeBlock(Bob, 1000000, 1024);
        proveBlock(
            Bob,
            meta,
            GENESIS_BLOCK_HASH,
            10000,
            10001,
            bytes32(uint256(0x11)),
            bytes32(uint256(0x12)),
            false
        );

        TaikoData.BlockEvidence memory evidence = TaikoData.BlockEvidence({
            metaHash: LibUtils.hashMetadata(meta),
            parentHash: GENESIS_BLOCK_HASH,
            blockHash: bytes32(uint256(0x11)),
            signalRoot: bytes32(uint256(0x12)),
            graffiti: 0x0,
            prover: address(0),
            parentGasUsed: 10000,
            gasUsed: 40000,
            verifierId: 0,
            proof: new bytes(0)
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            AlicePK,
            keccak256(abi.encode(evidence))
        );

        evidence.verifierId = v;
        evidence.proof = bytes.concat(r, s);

        vm.prank(Carol, Carol);
        L1.proveBlock(meta.id, abi.encode(evidence));

        TaikoData.ForkChoice memory fc = L1.getForkChoice(
            1,
            GENESIS_BLOCK_HASH,
            10000
        );

        assertEq(fc.blockHash, bytes32(uint256(0x11)));
        assertEq(fc.signalRoot, bytes32(uint256(0x12)));
        assertEq(fc.provenAt, block.timestamp);
        assertEq(fc.prover, address(0));
        assertEq(fc.gasUsed, 40000);
    }

    function testOracleProverCanAlwaysOverwrite() external {
        depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint256 blockId = 1;
        TaikoData.BlockMetadata memory meta = proposeBlock(
            Alice,
            1000000,
            1024
        );

        for (uint i = 0; i < 5; ++i) {
            uint32 parentGasUsed = uint32(10000 + i);

            // Bob proves the block
            proveBlock(
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                10001,
                bytes32(uint256(0x11)),
                bytes32(uint256(0x12)),
                false
            );

            TaikoData.ForkChoice memory fc = L1.getForkChoice(
                blockId,
                parentHash,
                parentGasUsed
            );

            if (i == 0) {
                assertFalse(fc.key == 0);
            } else {
                assertEq(fc.key, 0);
            }
            assertEq(fc.blockHash, bytes32(uint256(0x11)));
            assertEq(fc.signalRoot, bytes32(uint256(0x12)));
            assertEq(fc.provenAt, block.timestamp);
            assertEq(fc.prover, Bob);
            assertEq(fc.gasUsed, 10001);

            // Carol cannot prove the fork choice again
            vm.warp(block.timestamp + 10 seconds);
            vm.expectRevert();
            proveBlock(
                Carol,
                meta,
                parentHash,
                parentGasUsed,
                10002,
                bytes32(uint256(0x21)),
                bytes32(uint256(0x22)),
                false
            );

            // Alice, the oracle prover,  cannot prove the fork choice again
            // as a normal prover.
            vm.warp(block.timestamp + 10 seconds);
            vm.expectRevert();
            proveBlock(
                Alice,
                meta,
                parentHash,
                parentGasUsed,
                10003,
                bytes32(uint256(0x31)),
                bytes32(uint256(0x32)),
                false
            );

            // Alice, the oracle prover,  cannot oracle-prove the fork choice
            vm.warp(block.timestamp + 10 seconds);
            proveBlock(
                Alice,
                meta,
                parentHash,
                parentGasUsed,
                10003,
                bytes32(uint256(0x31)),
                bytes32(uint256(0x32)),
                true
            );

            fc = L1.getForkChoice(blockId, parentHash, parentGasUsed);

            if (i == 0) {
                assertFalse(fc.key == 0);
            } else {
                assertEq(fc.key, 0);
            }
            assertEq(fc.blockHash, bytes32(uint256(0x31)));
            assertEq(fc.signalRoot, bytes32(uint256(0x32)));
            assertEq(fc.provenAt, block.timestamp);
            assertEq(fc.prover, address(0));
            assertEq(fc.gasUsed, 10003);

            // Alice, the oracle prover,  cannot oracle-prove the fork choice multiple times
            vm.warp(block.timestamp + 10 seconds);

            proveBlock(
                Alice,
                meta,
                parentHash,
                parentGasUsed,
                10004,
                bytes32(uint256(0x41)),
                bytes32(uint256(0x42)),
                true
            );

            fc = L1.getForkChoice(blockId, parentHash, parentGasUsed);

            if (i == 0) {
                assertFalse(fc.key == 0);
            } else {
                assertEq(fc.key, 0);
            }
            assertEq(fc.blockHash, bytes32(uint256(0x41)));
            assertEq(fc.signalRoot, bytes32(uint256(0x42)));
            assertEq(fc.provenAt, block.timestamp);
            assertEq(fc.prover, address(0));
            assertEq(fc.gasUsed, 10004);
        }
    }

    /// @dev Test we can propose, prove, then verify more blocks than 'maxNumProposedBlocks'
    function test_cooldown_more_blocks_than_ring_buffer_size() external {
        depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed = 0;
        uint32 gasUsed = 1000000;

        for (
            uint256 blockId = 1;
            blockId < conf.maxNumProposedBlocks * 10;
            blockId++
        ) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(
                Alice,
                1000000,
                1024
            );
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(
                Bob,
                meta,
                parentHash,
                parentGasUsed,
                gasUsed,
                blockHash,
                signalRoot,
                false
            );

            uint256 lastVerifiedBlockId = L1
                .getStateVariables()
                .lastVerifiedBlockId;

            vm.warp(block.timestamp + 4 minutes + 59 seconds);
            verifyBlock(Carol, 1);

            assertEq(
                lastVerifiedBlockId,
                L1.getStateVariables().lastVerifiedBlockId
            );

            vm.warp(block.timestamp + 1 seconds);
            verifyBlock(Carol, 1);
            assertFalse(
                lastVerifiedBlockId ==
                    L1.getStateVariables().lastVerifiedBlockId
            );

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        printVariables("");
    }
}
