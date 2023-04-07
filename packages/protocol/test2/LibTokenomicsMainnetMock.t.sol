// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

// Uncomment if you want to compare fee/vs reward
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

contract TaikoL1WithNonMintingConfig is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.txListCacheExpiry = 5 minutes;
        config.maxVerificationsPerTx = 0;
        config.enableSoloProposer = false;
        config.enableOracleProver = false;
        config.maxNumProposedBlocks = 200;
        config.ringBufferSize = 240;
    }
}

// Since the fee/reward calculation heavily depends on the baseFeeProof and the proofTime
// we need to simulate proposing/proving so that can calculate them.
contract LibL1TokenomicsTest is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1WithNonMintingConfig();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();

        _depositTaikoToken(Alice, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E6 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E6 * 1E8, 100 ether);
    }

    /// @dev To mock a mainnet: set proofTImeTarget in TaikoConfig.sol to 30 mins and run this test

    /// @dev A possible (close to) mainnet scenarios is the following:
    //// - Blocks ever 10 seconds proposed
    //// - Proofs coming shifted 30 min / proposed block afterwards
    //// Foundry has some issues with the iterations (EVM revert) but the calculation mechnism can be seen from this
    function xtest_possible_mainnet_scenarios() external {
        mine(1);
        //Needs lot of token here - because there is lots of time elapsed between 2 'propose' blocks, which will raise the fee
        _depositTaikoToken(Alice, 1E8 * 1E8, 100 ether);
        _depositTaikoToken(Bob, 1E8 * 1E8, 100 ether);
        _depositTaikoToken(Carol, 1E8 * 1E8, 100 ether);

        // Check balances
        uint256 Alice_start_balance = L1.getBalance(Alice);
        uint256 Bob_start_balance = L1.getBalance(Bob);

        /// 1.step: mine 180 blocks without proofs - then start prooving with a -180 offset
        TaikoData.BlockMetadata[] memory meta = new TaikoData.BlockMetadata[](
            250
        );
        uint64[] memory proposedAt = new uint64[](250);
        bytes32[] memory parentHashes = new bytes32[](250);
        bytes32[] memory blockHashes = new bytes32[](250);
        bytes32[] memory signalRoots = new bytes32[](250);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        console2.logBytes32(parentHash);

        // Run another session with huge times
        for (uint256 blockId = 1; blockId < 215; blockId++) {
            meta[blockId] = proposeBlock(Alice, 1024);
            proposedAt[blockId] = (uint64(block.timestamp));
            printVariables("after propose");

            blockHashes[blockId] = bytes32(1E10 + blockId);
            signalRoots[blockId] = bytes32(1E9 + blockId);

            if (blockId > 99) {
                //Start proving with an offset except parentHash because that's one index behind
                // console2.logBytes32(parentHashes[blockId-179]);
                // console2.logBytes32(blockHashes[blockId-179]);
                // console2.logBytes32(signalRoots[blockId-179]);
                proveBlock(
                    Bob,
                    meta[blockId - 99],
                    parentHashes[blockId - 99],
                    blockHashes[blockId - 99],
                    signalRoots[blockId - 99]
                );
                uint64 provenAt = uint64(block.timestamp);
                console2.log(
                    "Proof reward is:",
                    L1.getProofReward(provenAt, proposedAt[blockId - 99])
                );
                verifyBlock(Carol, 1);
            }

            mine_every_10_sec();

            parentHashes[blockId] = parentHash;
            parentHash = blockHashes[blockId];
        }

        //Check end balances
        uint256 deposits = Alice_start_balance - L1.getBalance(Alice);
        uint256 withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        //Check end balances
        deposits = Alice_start_balance - L1.getBalance(Alice);
        withdrawals = L1.getBalance(Bob) - Bob_start_balance;

        // console2.log("Deposits:", deposits);
        // console2.log("withdrawals:", withdrawals);
        assertEq(deposits, withdrawals);
    }

    // Currently set to 85s proofTimeTarget
    function mine_every_10_sec() internal {
        vm.warp(block.timestamp + 10);
        vm.roll(block.number + 1);
    }

    function mine_every_5_sec() internal {
        vm.warp(block.timestamp + 5);
        vm.roll(block.number + 1);
    }
}
