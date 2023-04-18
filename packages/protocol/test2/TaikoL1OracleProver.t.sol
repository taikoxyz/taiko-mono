// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {AddressManager} from "../contracts/thirdparty/AddressManager.sol";
import {TaikoConfig} from "../contracts/L1/TaikoConfig.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {TaikoL1} from "../contracts/L1/TaikoL1.sol";
import {TaikoToken} from "../contracts/L1/TaikoToken.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoL1TestBase} from "./TaikoL1TestBase.t.sol";

contract TaikoL1_withOracleProver is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.enableTokenomics = true;
        config.txListCacheExpiry = 5 minutes;
        config.proposerDepositPctg = 0;
        config.maxVerificationsPerTx = 0;
        config.enableSoloProposer = false;
        config.enableOracleProver = true;
        config.maxNumProposedBlocks = 10;
        config.ringBufferSize = 12;
        // this value must be changed if `maxNumProposedBlocks` is changed.
        config.slotSmoothingFactor = 4160;

        config.proposingConfig = TaikoData.FeeConfig({
            avgTimeMAF: 64,
            dampingFactorBips: 5000
        });

        config.provingConfig = TaikoData.FeeConfig({
            avgTimeMAF: 64,
            dampingFactorBips: 5000
        });
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1Test is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1_withOracleProver();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();
        _registerAddress(
            string(abi.encodePacked("verifier_", uint16(100))),
            address(new Verifier())
        );

        _registerAddress("oracle_prover", Alice);
    }

    // Test a block can be oracle-proven multiple times by the
    // oracle prover
    function testOracleProver() external {
        _depositTaikoToken(Alice, 1000 * 1E8, 1000 ether);
        _depositTaikoToken(Bob, 1000 * 1E8, 1000 ether);
        _depositTaikoToken(Carol, 1000 * 1E8, 1000 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        TaikoData.BlockMetadata memory meta = proposeBlock(Bob, 1000000, 1024);

        // No forkchoice can be found
        vm.expectRevert();
        TaikoData.ForkChoice memory fc = L1.getForkChoice({
            blockId: 1,
            parentHash: parentHash,
            parentGasUsed: 123
        });

        // Alice cannot prove the forkchoice
        vm.expectRevert();
        proveBlock(
            Alice,
            meta,
            parentHash,
            123,
            456,
            bytes32(uint256(0x100)),
            bytes32(uint256(0x101))
        );

        // Bob also cannot prove the forkchoice
        vm.expectRevert();
        proveBlock(
            Bob,
            meta,
            parentHash,
            123,
            456,
            bytes32(uint256(0x100)),
            bytes32(uint256(0x101))
        );

        // Bob cannot oracle-prove the forkchoice
        vm.expectRevert();
        oracleProveBlock(
            Bob,
            1,
            parentHash,
            123,
            456,
            bytes32(uint256(0x100)),
            bytes32(uint256(0x101))
        );

        // Alice can oracle-prove the forkchoice
        oracleProveBlock(
            Alice,
            1,
            parentHash,
            123,
            456,
            bytes32(uint256(0x100)),
            bytes32(uint256(0x101))
        );

        fc = L1.getForkChoice({
            blockId: 1,
            parentHash: parentHash,
            parentGasUsed: 123
        });
        assertEq(fc.blockHash, bytes32(uint256(0x100)));
        assertEq(fc.signalRoot, bytes32(uint256(0x101)));
        assertEq(uint256(fc.provenAt), block.timestamp);
        assertEq(fc.prover, address(0));
        assertEq(fc.gasUsed, 456);

        // Alice can oracle-prove the forkchoice more than once
        for (uint i = 0; i < 2; ++i) {
            mine(1);
            oracleProveBlock({
                prover: Alice,
                blockId: 1,
                parentHash: parentHash,
                parentGasUsed: 123,
                gasUsed: 789,
                blockHash: bytes32(uint256(0x103)),
                signalRoot: bytes32(uint256(0x104))
            });
        }

        fc = L1.getForkChoice({
            blockId: 1,
            parentHash: parentHash,
            parentGasUsed: 123
        });

        assertEq(fc.blockHash, bytes32(uint256(0x103)));
        assertEq(fc.signalRoot, bytes32(uint256(0x104)));
        assertEq(uint256(fc.provenAt), block.timestamp);
        assertEq(fc.prover, address(0));
        assertEq(fc.gasUsed, 789);

        // Bob cannot prove the forkchoice with conflicting proof
        vm.expectRevert();
        proveBlock({
            prover: Bob,
            meta: meta,
            parentHash: parentHash,
            parentGasUsed: 123,
            gasUsed: 789,
            blockHash: bytes32(uint256(0x100)),
            signalRoot: bytes32(uint256(0x101))
        });

        vm.expectRevert();
        proveBlock({
            prover: Bob,
            meta: meta,
            parentHash: parentHash,
            parentGasUsed: 123,
            gasUsed: 456,
            blockHash: bytes32(uint256(0x103)),
            signalRoot: bytes32(uint256(0x104))
        });

        // Bob can prove the forkchoice with a matching proof
        mine(1);
        proveBlock({
            prover: Bob,
            meta: meta,
            parentHash: parentHash,
            parentGasUsed: 123,
            gasUsed: 789,
            blockHash: bytes32(uint256(0x103)),
            signalRoot: bytes32(uint256(0x104))
        });

        fc = L1.getForkChoice({
            blockId: 1,
            parentHash: parentHash,
            parentGasUsed: 123
        });

        assertEq(fc.blockHash, bytes32(uint256(0x103)));
        assertEq(fc.signalRoot, bytes32(uint256(0x104)));
        assertEq(uint256(fc.provenAt), block.timestamp);
        assertEq(fc.prover, Bob);
        assertEq(fc.gasUsed, 789);

        // Nobody can prove the forkchoice again
        vm.expectRevert();
        proveBlock({
            prover: Carol,
            meta: meta,
            parentHash: parentHash,
            parentGasUsed: 123,
            gasUsed: 789,
            blockHash: bytes32(uint256(0x103)),
            signalRoot: bytes32(uint256(0x104))
        });

        // Including Alice
        vm.expectRevert();
        proveBlock({
            prover: Alice,
            meta: meta,
            parentHash: parentHash,
            parentGasUsed: 123,
            gasUsed: 789,
            blockHash: bytes32(uint256(0x103)),
            signalRoot: bytes32(uint256(0x104))
        });

        // But Alice can still oracle-proof the block again
        mine(1);
        oracleProveBlock({
            prover: Alice,
            blockId: 1,
            parentHash: parentHash,
            parentGasUsed: 123,
            gasUsed: 987,
            blockHash: bytes32(uint256(0x105)),
            signalRoot: bytes32(uint256(0x106))
        });

        fc = L1.getForkChoice({
            blockId: 1,
            parentHash: parentHash,
            parentGasUsed: 123
        });

        assertEq(fc.blockHash, bytes32(uint256(0x105)));
        assertEq(fc.signalRoot, bytes32(uint256(0x106)));
        assertEq(uint256(fc.provenAt), block.timestamp);
        assertEq(fc.prover, address(0));
        assertEq(fc.gasUsed, 987);
    }
}
