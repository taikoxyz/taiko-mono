// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoConfig} from "../contracts/L1/TaikoConfig.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {TaikoL1} from "../contracts/L1/TaikoL1.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoL1TestBase} from "./TaikoL1TestBase.t.sol";
import {LibLn} from "./LibLn.sol";

/// @dev Warning: this test will take 7-10 minutes and require 1GB memory.
///      `pnpm test:sim`
contract TaikoL1_b is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.txListCacheExpiry = 0;
        config.maxNumProposedBlocks = 36;
        config.ringBufferSize = 40;
        config.maxVerificationsPerTx = 5;
        config.proofCooldownPeriod = 1 minutes;
        config.proofTimeTarget = 200;
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1Simulation is TaikoL1TestBase {
    // Initial salt for semi-random generation
    uint256 salt = 2195684615613153;

    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1_b();
    }

    function setUp() public override {
        uint16 proofTimeTarget = 200; // Approx. value which close to what is in the simulation

        initProofTimeIssued = LibLn.calcInitProofTimeIssued(
            feeBase,
            proofTimeTarget,
            ADJUSTMENT_QUOTIENT
        );

        TaikoL1TestBase.setUp();
        registerAddress(L1.getVerifierNameHash(100), address(new Verifier()));
    }

    function testGeneratingManyRandomBlocks() external {
        uint256 time = block.timestamp;
        assertEq(time, 1);

        depositTaikoToken(Alice, 1E6 * 1E8, 10000 ether);

        bytes32 parentHash = GENESIS_BLOCK_HASH;
        uint32 parentGasUsed;

        printVariableHeaders();
        printVariables();

        // Every 1000 blocks take about 40 seconds
        // TODO(daniel|dani): change this to 10000
        uint256 blocksToSimulate = 100;
        uint256 avgBlockTime = 10 seconds;

        for (uint256 blockId = 1; blockId < blocksToSimulate; blockId++) {
            uint256 newRandomWithoutSalt = uint256(
                keccak256(abi.encodePacked(time, msg.sender, block.timestamp))
            );

            time += pickRandomNumber(
                newRandomWithoutSalt,
                avgBlockTime,
                (avgBlockTime * 2 - avgBlockTime + 1)
            );
            //Regenerate salt every time used at pickRandomNumber
            salt = uint256(keccak256(abi.encodePacked(time, salt)));

            while ((time / 12) * 12 > block.timestamp) {
                vm.warp(block.timestamp + 12);
                vm.roll(block.number + 1);
            }

            uint32 gasLimit = uint32(
                pickRandomNumber(
                    newRandomWithoutSalt,
                    100E3,
                    (3000000 - 100000 + 1)
                )
            ); // 100K to 30M
            salt = uint256(keccak256(abi.encodePacked(gasLimit, salt)));

            uint32 gasUsed = uint32(
                pickRandomNumber(
                    newRandomWithoutSalt,
                    (gasLimit / 2),
                    ((gasLimit / 2) + 1)
                )
            );
            salt = uint256(keccak256(abi.encodePacked(gasUsed, salt)));

            uint24 txListSize = uint24(
                pickRandomNumber(
                    newRandomWithoutSalt,
                    1,
                    conf.maxBytesPerTxList
                ) //Actually (conf.maxBytesPerTxList-1)+1 but that's the same
            );
            salt = uint256(keccak256(abi.encodePacked(txListSize, salt)));

            bytes32 blockHash = bytes32(
                pickRandomNumber(newRandomWithoutSalt, 0, type(uint256).max)
            );
            salt = uint256(keccak256(abi.encodePacked(blockHash, salt)));

            bytes32 signalRoot = bytes32(
                pickRandomNumber(newRandomWithoutSalt, 0, type(uint256).max)
            );
            salt = uint256(keccak256(abi.encodePacked(signalRoot, salt)));

            TaikoData.BlockMetadata memory meta = proposeBlock(
                Alice,
                gasLimit,
                txListSize
            );

            // Here we need to have some time elapsed between propose and prove
            // Realistically lets make it somewhere 160-240 sec, it is realistic
            // for a testnet.
            uint256 proveTimeCnt = pickRandomNumber(newRandomWithoutSalt, 8, 5);

            salt = uint256(keccak256(abi.encodePacked(proveTimeCnt, salt)));
            //console2.log("salt:", salt);

            mine(proveTimeCnt);

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
            printVariables();

            parentHash = blockHash;
            parentGasUsed = gasUsed;
        }
        console2.log("-----------------------------");
        console2.log("avgBlockTime:", avgBlockTime);
    }

    // TODO(daniel|dani): log enough state variables for analysis.
    function printVariableHeaders() internal view {
        string memory str = string.concat(
            "\nlogCount,",
            "time,",
            "lastVerifiedBlockId,",
            "numBlocks,",
            "blockFee,",
            "accProposedAt"
        );
        console2.log(str);
    }

    // TODO(daniel|dani): log enough state variables for analysis.
    function printVariables() internal {
        TaikoData.StateVariables memory vars = L1.getStateVariables();
        string memory str = string.concat(
            Strings.toString(logCount++),
            ",",
            Strings.toString(block.timestamp),
            ",",
            Strings.toString(vars.lastVerifiedBlockId),
            ",",
            Strings.toString(vars.numBlocks),
            ",",
            Strings.toString(vars.blockFee),
            ",",
            Strings.toString(vars.accProposedAt)
        );
        console2.log(str);
    }

    // Semi-random number generator
    function pickRandomNumber(
        uint256 randomNum,
        uint256 lowerLimit,
        uint256 diffBtwLowerAndUpperLimit
    ) internal view returns (uint256) {
        randomNum = uint256(keccak256(abi.encodePacked(randomNum, salt)));
        return (lowerLimit + (randomNum % diffBtwLowerAndUpperLimit));
    }
}
