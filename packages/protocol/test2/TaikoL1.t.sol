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
        config.maxNumBlocks = 5;
        config.maxVerificationsPerTx = 0;
        config.constantFeeRewardBlocks = 10;
        config.enableSoloProposer = false;
        config.enableOracleProver = false;
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
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Bob, meta, parentHash, blockHash, signalRoot);
            mine(1);

            verifyBlock(Carol, 1);
            mine(1);

            parentHash = blockHash;
        }
    }

    /// @dev Test more than one block can be proposed, proven, & verified in the
    ///      same L1 block.
    function test_multiple_blocks_in_one_L1_block() external {
        _depositTaikoToken(Alice, 1E6, 100);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint blockId = 1; blockId <= 2; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Alice, meta, parentHash, blockHash, signalRoot);
            verifyBlock(Alice, 2);
            parentHash = blockHash;
        }
    }

    /// @dev Test verify multiple blocks in one transaction
    function test_verifying_multiple_blocks_once() external {
        _depositTaikoToken(Alice, 1E6, 100);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint blockId = 1; blockId <= conf.maxNumBlocks - 1; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(Alice, 1024);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(Alice, meta, parentHash, blockHash, signalRoot);
            parentHash = blockHash;
        }
        verifyBlock(Alice, conf.maxNumBlocks - 2);
        verifyBlock(Alice, conf.maxNumBlocks);
    }
}
