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
    address public constant ALICE = 0xc8885E210E59Dba0164Ba7CDa25f607e6d586B7A;
    address public constant BOB = 0x000000000000000000636F6e736F6c652e6c6f67;
    uint64 feeBaseTwei = 1000000; // 1 TKO

    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1WithConfig();
        taikoL1.init(address(addressManager), GENESIS_BLOCK_HASH, feeBaseTwei);
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();
        _registerAddress(
            string(abi.encodePacked("verifier_", uint256(100))),
            address(new Verifier())
        );
    }

    /// @dev Testing we can propose, prove, then verify more blocks than 'maxNumBlocks'
    function testBlockRingBuffer() external {
        _depositTaikoToken(ALICE, 1E6, 100);
        _depositTaikoToken(BOB, 1E6, 100);

        bytes32 parentHash = GENESIS_BLOCK_HASH;

        for (uint blockId = 1; blockId < conf.maxNumBlocks * 3; blockId++) {
            TaikoData.BlockMetadata memory meta = proposeBlock(ALICE, 1024);
            mine(1);

            bytes32 blockHash = bytes32(1E10 + blockId);
            bytes32 signalRoot = bytes32(1E9 + blockId);
            proveBlock(BOB, meta, parentHash, blockHash, signalRoot);

            verifyBlock(BOB, 1);

            parentHash = blockHash;
            mine(1);
        }
    }
}
