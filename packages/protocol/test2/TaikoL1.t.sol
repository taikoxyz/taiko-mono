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
import {TaikoL1TestBase} from "./TaikoL1TestBase.sol";

contract TaikoL1WithConfig is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();
        config.enableTokenomics = true;
        config.bootstrapDiscountHalvingPeriod = 0;
        config.constantFeeRewardBlocks = 0;
        config.txListCacheExpiry = 5 minutes;
        config.proposerDepositPctg = 0;
        config.maxVerificationsPerTx = 0;
        config.enableSoloProposer = false;
        config.enableOracleProver = false;
        config.maxNumBlocks = 11;
        // this value must be changed if `maxNumBlocks` is changed.
        config.slotSmoothingFactor = 4160;
        config.anchorTxGasLimit = 180000;

        config.proposingConfig = TaikoData.FeeConfig({
            avgTimeMAF: 64,
            avgTimeCap: 10 minutes * 1000,
            gracePeriodPctg: 100,
            maxPeriodPctg: 400,
            multiplerPctg: 400
        });

        config.provingConfig = TaikoData.FeeConfig({
            avgTimeMAF: 64,
            avgTimeCap: 10 minutes * 1000,
            gracePeriodPctg: 100,
            maxPeriodPctg: 400,
            multiplerPctg: 400
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
        taikoL1 = new TaikoL1WithConfig();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();
        _registerAddress(
            string(abi.encodePacked("verifier_", uint256(100))),
            address(new Verifier())
        );
    }

    /// @dev Test we can propose, prove, then verify more blocks than 'maxNumBlocks'
    function test_more_blocks_than_ring_buffer_size() external {
        _depositTaikoToken(Alice, 1E6, 100);
        _depositTaikoToken(Bob, 1E6, 100);
        _depositTaikoToken(Carol, 1E6, 100);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint blockId = 1; blockId < conf.maxNumBlocks * 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            printVariables("after propose");
            mine(1);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            parentHash = blockHash;
        }
        printVariables("");
    }

    /// @dev Test more than one block can be proposed, proven, & verified in the
    ///      same L1 block.
    function test_multiple_blocks_in_one_L1_block() external {
        _depositTaikoToken(Alice, 1000, 1000);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint blockId = 1; blockId <= 2; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            printVariables("after propose");

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Alice, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Alice, 2);
            parentHash = blockHash;
        }
        printVariables("");
    }

    /// @dev Test verifying multiple blocks in one transaction
    function test_verifying_multiple_blocks_once() external {
        _depositTaikoToken(Alice, 1E6, 100);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint blockId = 1; blockId <= conf.maxNumBlocks - 1; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            printVariables("after propose");

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Alice, meta, parentHash, blockHash, signalRoot);
            parentHash = blockHash;
        }
        verifyBlock(Alice, conf.maxNumBlocks - 2);
        printVariables("after verify");
        verifyBlock(Alice, conf.maxNumBlocks);
        printVariables("after verify");
    }

    /// @dev Test block timeincrease and fee shall decrease.
    function test_block_time_increases_but_fee_decreases() external {
        _depositTaikoToken(Alice, 1E6, 100);
        _depositTaikoToken(Bob, 1E6, 100);
        _depositTaikoToken(Carol, 1E6, 100);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint blockId = 1; blockId < conf.maxNumBlocks * 10; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            mine(blockId);
            parentHash = blockHash;
        }
        printVariables("");
    }

    /// @dev Test block time goes down lover time and the fee should remain
    // the same.
    function test_block_time_decreases_but_fee_remains() external {
        _depositTaikoToken(Alice, 1E6, 100);
        _depositTaikoToken(Bob, 1E6, 100);
        _depositTaikoToken(Carol, 1E6, 100);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        uint total = conf.maxNumBlocks * 10;

        for (uint blockId = 1; blockId < total; blockId++) {
            printVariables("before propose");
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Carol, 1);
            mine(total + 1 - blockId);
            parentHash = blockHash;
        }
        printVariables("");
    }
}
