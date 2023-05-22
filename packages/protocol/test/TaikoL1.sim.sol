// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoConfig} from "../contracts/L1/TaikoConfig.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {TaikoL1} from "../contracts/L1/TaikoL1.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TaikoL1TestBase} from "./TaikoL1TestBase.t.sol";
import {LibLn} from "./LibLn.sol";

/// @dev Tweak this if you iwhs to set - the config and the calculation of the proofTimeIssued
/// @dev also originates from this
uint16 constant INITIAL_PROOF_TIME_TARGET = 375; //sec. Approx mainnet scenario

/// @dev Warning: this test will take 7-10 minutes and require 1GB memory.
///      `pnpm sim`
contract TaikoL1_b is TaikoL1 {
    function getConfig() public pure override returns (TaikoData.Config memory config) {
        config = TaikoConfig.getConfig();

        config.txListCacheExpiry = 0;
        config.maxNumProposedBlocks = 1100;
        config.ringBufferSize = 1200;
        config.maxVerificationsPerTx = 10;
        config.proofCooldownPeriod = 1 minutes;
        config.realProofSkipSize = 0;
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1Simulation is TaikoL1TestBase {
    // Need to bring variable declaration here - to avoid stack too deep
    // Initial salt for semi-random generation
    uint256 salt = 2195684615435261315311;
    // Can play to adjust
    uint256 blocksToSimulate = 4000;
    // RandomNumber - pseudo random but fine
    uint256 newRandomWithoutSalt;

    //////////////////////////////////////////
    //            TUNABLE PARAMS            //
    //////////////////////////////////////////
    // This means block proposals will be averaged out (long term if random function is random enough) to 18s
    // It is fine it simulates that we do not necessarily put Taiko block at every 12s, but on average around every x1.5 of ETH block
    // Meaninig we have less blocks / sec. (We should test what happens if quicker!)
    uint256 nextBlockTime = 12 seconds;
    uint256 minDiffToBlockPropTime = 12 seconds;

    // This means block provings will be averaged out (long term if random function is random enough) to 200s
    uint256 startBlockProposeTime = 1600 seconds;
    uint256 upperDevToBlockProveTime = 800 seconds;
    uint256 secondsToSimulate = blocksToSimulate * 18; //Because of the expected average blocktimestamp - we can tweak it obv.
    //////////////////////////////////////////
    //          TUNABLE PARAMS END          //
    //////////////////////////////////////////
    uint256 maxTime = 0;
    uint256 totalDiffsProp = 0;
    uint256 totalDiffsProve = 0;
    uint256 lastTimestampProp = 0;
    uint256 lastTimestampProve = 0;
    // Need to map a second to a proofTIme, and might be possible that multiple proofs coming in the same block
    mapping(uint256 proofTimeSecond => uint256[] arrivalIdxOfBlockIds) private
        _proofTimeToBlockIndexes;
    // Pre-calculate propose and prove timestamp
    uint64[] blocksProposedTimestamp = new uint64[](blocksToSimulate);

    bytes32 parentHash = GENESIS_BLOCK_HASH;

    bytes32[] parentHashes = new bytes32[](blocksToSimulate);
    bytes32[] blockHashes = new bytes32[](blocksToSimulate);
    bytes32[] signalRoots = new bytes32[](blocksToSimulate);
    uint32[] parentGasUsed = new uint32[](blocksToSimulate);
    uint32[] gasUsed = new uint32[](blocksToSimulate);
    uint32[] gasLimits = new uint32[](blocksToSimulate);

    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1_b();
    }

    function setUp() public override {
        proofTimeTarget = INITIAL_PROOF_TIME_TARGET; // Approx. value which close to what is in the simulation

        initProofTimeIssued =
            LibLn.calcInitProofTimeIssued(feeBase, proofTimeTarget, ADJUSTMENT_QUOTIENT);

        TaikoL1TestBase.setUp();

        registerAddress(L1.getVerifierName(100), address(new Verifier()));
    }

    // A real world scenario
    function xtestGeneratingManyRandomBlocksNonConsecutive() external {
        uint256 time = block.timestamp;

        assertEq(time, 1);

        depositTaikoToken(Alice, 1e6 * 1e8, 10000 ether);

        TaikoData.BlockMetadata[] memory metas = new TaikoData.BlockMetadata[](
            blocksToSimulate
        );

        // Determine every timestamp of the block we want to simulate
        console2.log("BlockId, ProofTime");
        for (uint256 i = 0; i < blocksToSimulate; i++) {
            newRandomWithoutSalt = uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty, msg.sender, block.timestamp, i, newRandomWithoutSalt, salt
                    )
                )
            );
            blocksProposedTimestamp[i] = uint64(
                pickRandomNumber(newRandomWithoutSalt, nextBlockTime, (minDiffToBlockPropTime + 1))
            );
            nextBlockTime = blocksProposedTimestamp[i] + minDiffToBlockPropTime;

            // Avg. calculation
            if (lastTimestampProp > 0) {
                totalDiffsProp += blocksProposedTimestamp[i] - lastTimestampProp;
            }

            lastTimestampProp = blocksProposedTimestamp[i];
            // We need this info to extract / export !!
            //console2.log("Time of PROPOSAL is:", blocksProposedTimestamp[i]);
            salt =
                uint256(keccak256(abi.encodePacked(nextBlockTime, salt, i, newRandomWithoutSalt)));

            uint64 proofTimePerBlockI = uint64(
                pickRandomNumber(
                    newRandomWithoutSalt,
                    (nextBlockTime + startBlockProposeTime),
                    (upperDevToBlockProveTime + 1)
                )
            );

            if (proofTimePerBlockI > maxTime) {
                maxTime = proofTimePerBlockI;
            }

            if (lastTimestampProve > 0) {
                totalDiffsProve += proofTimePerBlockI - lastTimestampProp;
            }
            lastTimestampProve = proofTimePerBlockI;
            // It is possible that proof for block N+1 comes before N, so we need to keep track of that. Because
            // the proofs per block is related to propose of that same block (index).
            _proofTimeToBlockIndexes[proofTimePerBlockI].push(i);

            // We need this info to extract / export !!
            console2.log(i + 1, ";", proofTimePerBlockI - lastTimestampProp);
            salt = uint256(keccak256(abi.encodePacked(proofTimePerBlockI, salt)));
        }

        uint256 proposedIndex;

        console2.log("Last second:", maxTime);
        console2.log("Proof time target:", INITIAL_PROOF_TIME_TARGET);
        console2.log("Average proposal time: ", totalDiffsProp / blocksToSimulate);
        console2.log("Average proof time: ", totalDiffsProve / blocksToSimulate);
        printVariableHeaders();
        //It is a divider / marker for the parser
        console2.log("!-----------------------------");
        printVariables();
        // This is a way we can de-couple proposing from proving
        for (uint256 secondsElapsed = 0; secondsElapsed <= maxTime; secondsElapsed++) {
            newRandomWithoutSalt = uint256(
                keccak256(
                    abi.encodePacked(
                        newRandomWithoutSalt,
                        block.difficulty,
                        secondsElapsed,
                        msg.sender,
                        block.timestamp,
                        salt
                    )
                )
            );

            // We are proposing here
            if (
                secondsElapsed == blocksProposedTimestamp[proposedIndex]
                    && proposedIndex < blocksToSimulate
            ) {
                //console2.log("FOR CYCLE: Time of PROPOSAL is:", blocksProposedTimestamp[proposedIndex]);
                uint32 gasLimit =
                    uint32(pickRandomNumber(newRandomWithoutSalt, 100e3, (3000000 - 100000 + 1))); // 100K to 30M
                salt = uint256(keccak256(abi.encodePacked(gasLimit, salt)));

                if (proposedIndex == 0) {
                    parentGasUsed[proposedIndex] = 0;
                    parentHashes[proposedIndex] = GENESIS_BLOCK_HASH;
                } else {
                    parentGasUsed[proposedIndex] = gasUsed[proposedIndex - 1];
                    parentHashes[proposedIndex] = blockHashes[proposedIndex - 1];
                }

                gasUsed[proposedIndex] = uint32(
                    pickRandomNumber(newRandomWithoutSalt, (gasLimit / 2), ((gasLimit / 2) + 1))
                );
                salt = uint256(keccak256(abi.encodePacked(gasUsed, salt)));

                uint24 txListSize = uint24(
                    pickRandomNumber(newRandomWithoutSalt, 1, conf.maxBytesPerTxList) //Actually (conf.maxBytesPerTxList-1)+1 but that's the same
                );
                salt = uint256(keccak256(abi.encodePacked(txListSize, salt)));

                blockHashes[proposedIndex] =
                    bytes32(pickRandomNumber(newRandomWithoutSalt, 0, type(uint256).max));
                salt = uint256(keccak256(abi.encodePacked(blockHashes[proposedIndex], salt)));

                signalRoots[proposedIndex] =
                    bytes32(pickRandomNumber(newRandomWithoutSalt, 0, type(uint256).max));
                salt = uint256(keccak256(abi.encodePacked(signalRoots[proposedIndex], salt)));

                metas[proposedIndex] = proposeBlock(Alice, gasLimit, txListSize);

                if (proposedIndex < blocksToSimulate - 1) proposedIndex++;

                printVariables();
            }

            // We are proving here
            if (_proofTimeToBlockIndexes[secondsElapsed].length > 0) {
                //console2.log("Duplicates check");
                for (uint256 i; i < _proofTimeToBlockIndexes[secondsElapsed].length; i++) {
                    uint256 blockId = _proofTimeToBlockIndexes[secondsElapsed][i];

                    proveBlock(
                        Bob,
                        Bob,
                        metas[blockId],
                        parentHashes[blockId],
                        parentGasUsed[blockId],
                        gasUsed[blockId],
                        blockHashes[blockId],
                        signalRoots[blockId]
                    );
                }
            }

            // Increment time with 1 seconds
            vm.warp(block.timestamp + 1);
            //Log every 12 sec
            if (block.timestamp % 12 == 0) {
                printVariables();
            }
        }
        console2.log("-----------------------------!");
    }

    // 90% slow proofs (around 30 mins or so) and 10% (around 1-5 mins )
    function xtest_90percent_slow_10percent_quick() external {
        uint256 time = block.timestamp;

        uint256 startBlockProposeTime_quick = 60 seconds; // For the 10% where it is 'quick'
        uint256 upperDevToBlockProveTime_quick = 240 seconds; // For the 10% where it is quick

        assertEq(time, 1);

        depositTaikoToken(Alice, 1e6 * 1e8, 10000 ether);

        TaikoData.BlockMetadata[] memory metas = new TaikoData.BlockMetadata[](
            blocksToSimulate
        );

        // Determine every timestamp of the block we want to simulate
        console2.log("BlockId, ProofTime");
        for (uint256 i = 0; i < blocksToSimulate; i++) {
            newRandomWithoutSalt = uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty, msg.sender, block.timestamp, i, newRandomWithoutSalt, salt
                    )
                )
            );
            blocksProposedTimestamp[i] = uint64(
                pickRandomNumber(newRandomWithoutSalt, nextBlockTime, (minDiffToBlockPropTime + 1))
            );
            nextBlockTime = blocksProposedTimestamp[i] + minDiffToBlockPropTime;

            // Avg. calculation
            if (lastTimestampProp > 0) {
                totalDiffsProp += blocksProposedTimestamp[i] - lastTimestampProp;
            }

            lastTimestampProp = blocksProposedTimestamp[i];
            // We need this info to extract / export !!
            //console2.log("Time of PROPOSAL is:", blocksProposedTimestamp[i]);
            salt =
                uint256(keccak256(abi.encodePacked(nextBlockTime, salt, i, newRandomWithoutSalt)));
            uint64 proofTimePerBlockI;
            if (i % 10 == 0) {
                // A very quick proof this case
                proofTimePerBlockI = uint64(
                    pickRandomNumber(
                        newRandomWithoutSalt,
                        (nextBlockTime + startBlockProposeTime_quick),
                        (upperDevToBlockProveTime_quick + 1)
                    )
                );

                if (proofTimePerBlockI > maxTime) {
                    maxTime = proofTimePerBlockI;
                }
            } else {
                proofTimePerBlockI = uint64(
                    pickRandomNumber(
                        newRandomWithoutSalt,
                        (nextBlockTime + startBlockProposeTime),
                        (upperDevToBlockProveTime + 1)
                    )
                );

                if (proofTimePerBlockI > maxTime) {
                    maxTime = proofTimePerBlockI;
                }
            }

            if (lastTimestampProve > 0) {
                totalDiffsProve += proofTimePerBlockI - lastTimestampProp;
            }
            lastTimestampProve = proofTimePerBlockI;
            // It is possible that proof for block N+1 comes before N, so we need to keep track of that. Because
            // the proofs per block is related to propose of that same block (index).
            _proofTimeToBlockIndexes[proofTimePerBlockI].push(i);

            // We need this info to extract / export !!
            console2.log(i + 1, ";", proofTimePerBlockI - lastTimestampProp);
            salt = uint256(keccak256(abi.encodePacked(proofTimePerBlockI, salt)));
        }

        uint256 proposedIndex;

        console2.log("Last second:", maxTime);
        console2.log("Proof time target:", INITIAL_PROOF_TIME_TARGET);
        console2.log("Average proposal time: ", totalDiffsProp / blocksToSimulate);
        console2.log("Average proof time: ", totalDiffsProve / blocksToSimulate);
        printVariableHeaders();
        //It is a divider / marker for the parser
        console2.log("!-----------------------------");
        printVariables();
        // This is a way we can de-couple proposing from proving
        for (uint256 secondsElapsed = 0; secondsElapsed <= maxTime; secondsElapsed++) {
            newRandomWithoutSalt = uint256(
                keccak256(
                    abi.encodePacked(
                        newRandomWithoutSalt,
                        block.difficulty,
                        secondsElapsed,
                        msg.sender,
                        block.timestamp,
                        salt
                    )
                )
            );

            // We are proposing here
            if (
                secondsElapsed == blocksProposedTimestamp[proposedIndex]
                    && proposedIndex < blocksToSimulate
            ) {
                //console2.log("FOR CYCLE: Time of PROPOSAL is:", blocksProposedTimestamp[proposedIndex]);
                uint32 gasLimit =
                    uint32(pickRandomNumber(newRandomWithoutSalt, 100e3, (3000000 - 100000 + 1))); // 100K to 30M
                salt = uint256(keccak256(abi.encodePacked(gasLimit, salt)));

                if (proposedIndex == 0) {
                    parentGasUsed[proposedIndex] = 0;
                    parentHashes[proposedIndex] = GENESIS_BLOCK_HASH;
                } else {
                    parentGasUsed[proposedIndex] = gasUsed[proposedIndex - 1];
                    parentHashes[proposedIndex] = blockHashes[proposedIndex - 1];
                }

                gasUsed[proposedIndex] = uint32(
                    pickRandomNumber(newRandomWithoutSalt, (gasLimit / 2), ((gasLimit / 2) + 1))
                );
                salt = uint256(keccak256(abi.encodePacked(gasUsed, salt)));

                uint24 txListSize = uint24(
                    pickRandomNumber(newRandomWithoutSalt, 1, conf.maxBytesPerTxList) //Actually (conf.maxBytesPerTxList-1)+1 but that's the same
                );
                salt = uint256(keccak256(abi.encodePacked(txListSize, salt)));

                blockHashes[proposedIndex] =
                    bytes32(pickRandomNumber(newRandomWithoutSalt, 0, type(uint256).max));
                salt = uint256(keccak256(abi.encodePacked(blockHashes[proposedIndex], salt)));

                signalRoots[proposedIndex] =
                    bytes32(pickRandomNumber(newRandomWithoutSalt, 0, type(uint256).max));
                salt = uint256(keccak256(abi.encodePacked(signalRoots[proposedIndex], salt)));

                metas[proposedIndex] = proposeBlock(Alice, gasLimit, txListSize);

                if (proposedIndex < blocksToSimulate - 1) proposedIndex++;

                printVariables();
            }

            // We are proving here
            if (_proofTimeToBlockIndexes[secondsElapsed].length > 0) {
                //console2.log("Duplicates check");
                for (uint256 i; i < _proofTimeToBlockIndexes[secondsElapsed].length; i++) {
                    uint256 blockId = _proofTimeToBlockIndexes[secondsElapsed][i];

                    proveBlock(
                        Bob,
                        Bob,
                        metas[blockId],
                        parentHashes[blockId],
                        parentGasUsed[blockId],
                        gasUsed[blockId],
                        blockHashes[blockId],
                        signalRoots[blockId]
                    );
                }
            }

            // Increment time with 1 seconds
            vm.warp(block.timestamp + 1);
            //Log every 12 sec
            if (block.timestamp % 12 == 0) {
                printVariables();
            }
        }
        console2.log("-----------------------------!");
    }

    // 90% slow proofs (around 30 mins or so) and 10% (around 1-5 mins )
    function test_90percent_quick_10percent_slow() external {
        uint256 time = block.timestamp;
        uint256 startBlockProposeTime_quick = 60 seconds; // For the 10% where it is 'quick'
        uint256 upperDevToBlockProveTime_quick = 240 seconds; // For the 10% where it is quick

        assertEq(time, 1);

        depositTaikoToken(Alice, 1e6 * 1e8, 10000 ether);

        TaikoData.BlockMetadata[] memory metas = new TaikoData.BlockMetadata[](
            blocksToSimulate
        );

        // Determine every timestamp of the block we want to simulate
        console2.log("BlockId, ProofTime");
        for (uint256 i = 0; i < blocksToSimulate; i++) {
            newRandomWithoutSalt = uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty, msg.sender, block.timestamp, i, newRandomWithoutSalt, salt
                    )
                )
            );
            blocksProposedTimestamp[i] = uint64(
                pickRandomNumber(newRandomWithoutSalt, nextBlockTime, (minDiffToBlockPropTime + 1))
            );
            nextBlockTime = blocksProposedTimestamp[i] + minDiffToBlockPropTime;

            // Avg. calculation
            if (lastTimestampProp > 0) {
                totalDiffsProp += blocksProposedTimestamp[i] - lastTimestampProp;
            }

            lastTimestampProp = blocksProposedTimestamp[i];
            // We need this info to extract / export !!
            //console2.log("Time of PROPOSAL is:", blocksProposedTimestamp[i]);
            salt =
                uint256(keccak256(abi.encodePacked(nextBlockTime, salt, i, newRandomWithoutSalt)));

            uint64 proofTimePerBlockI;
            if (i % 10 == 0) {
                // 10% 'slow proofs'
                proofTimePerBlockI = uint64(
                    pickRandomNumber(
                        newRandomWithoutSalt,
                        (nextBlockTime + startBlockProposeTime),
                        (upperDevToBlockProveTime + 1)
                    )
                );

                if (proofTimePerBlockI > maxTime) {
                    maxTime = proofTimePerBlockI;
                }
            } else {
                // A very quick proof this case
                proofTimePerBlockI = uint64(
                    pickRandomNumber(
                        newRandomWithoutSalt,
                        (nextBlockTime + startBlockProposeTime_quick),
                        (upperDevToBlockProveTime_quick + 1)
                    )
                );

                if (proofTimePerBlockI > maxTime) {
                    maxTime = proofTimePerBlockI;
                }
            }

            if (proofTimePerBlockI > maxTime) {
                maxTime = proofTimePerBlockI;
            }

            if (lastTimestampProve > 0) {
                totalDiffsProve += proofTimePerBlockI - lastTimestampProp;
            }
            lastTimestampProve = proofTimePerBlockI;
            // It is possible that proof for block N+1 comes before N, so we need to keep track of that. Because
            // the proofs per block is related to propose of that same block (index).
            _proofTimeToBlockIndexes[proofTimePerBlockI].push(i);

            // We need this info to extract / export !!
            console2.log(i + 1, ";", proofTimePerBlockI - lastTimestampProp);
            salt = uint256(keccak256(abi.encodePacked(proofTimePerBlockI, salt)));
        }

        uint256 proposedIndex;

        console2.log("Last second:", maxTime);
        console2.log("Proof time target:", INITIAL_PROOF_TIME_TARGET);
        console2.log("Average proposal time: ", totalDiffsProp / blocksToSimulate);
        console2.log("Average proof time: ", totalDiffsProve / blocksToSimulate);
        printVariableHeaders();
        //It is a divider / marker for the parser
        console2.log("!-----------------------------");
        printVariables();
        // This is a way we can de-couple proposing from proving
        for (uint256 secondsElapsed = 0; secondsElapsed <= maxTime; secondsElapsed++) {
            newRandomWithoutSalt = uint256(
                keccak256(
                    abi.encodePacked(
                        newRandomWithoutSalt,
                        block.difficulty,
                        secondsElapsed,
                        msg.sender,
                        block.timestamp,
                        salt
                    )
                )
            );

            // We are proposing here
            if (
                secondsElapsed == blocksProposedTimestamp[proposedIndex]
                    && proposedIndex < blocksToSimulate
            ) {
                //console2.log("FOR CYCLE: Time of PROPOSAL is:", blocksProposedTimestamp[proposedIndex]);
                uint32 gasLimit =
                    uint32(pickRandomNumber(newRandomWithoutSalt, 100e3, (3000000 - 100000 + 1))); // 100K to 30M
                salt = uint256(keccak256(abi.encodePacked(gasLimit, salt)));

                if (proposedIndex == 0) {
                    parentGasUsed[proposedIndex] = 0;
                    parentHashes[proposedIndex] = GENESIS_BLOCK_HASH;
                } else {
                    parentGasUsed[proposedIndex] = gasUsed[proposedIndex - 1];
                    parentHashes[proposedIndex] = blockHashes[proposedIndex - 1];
                }

                gasUsed[proposedIndex] = uint32(
                    pickRandomNumber(newRandomWithoutSalt, (gasLimit / 2), ((gasLimit / 2) + 1))
                );
                salt = uint256(keccak256(abi.encodePacked(gasUsed, salt)));

                uint24 txListSize = uint24(
                    pickRandomNumber(newRandomWithoutSalt, 1, conf.maxBytesPerTxList) //Actually (conf.maxBytesPerTxList-1)+1 but that's the same
                );
                salt = uint256(keccak256(abi.encodePacked(txListSize, salt)));

                blockHashes[proposedIndex] =
                    bytes32(pickRandomNumber(newRandomWithoutSalt, 0, type(uint256).max));
                salt = uint256(keccak256(abi.encodePacked(blockHashes[proposedIndex], salt)));

                signalRoots[proposedIndex] =
                    bytes32(pickRandomNumber(newRandomWithoutSalt, 0, type(uint256).max));
                salt = uint256(keccak256(abi.encodePacked(signalRoots[proposedIndex], salt)));

                metas[proposedIndex] = proposeBlock(Alice, gasLimit, txListSize);

                if (proposedIndex < blocksToSimulate - 1) proposedIndex++;

                printVariables();
            }

            // We are proving here
            if (_proofTimeToBlockIndexes[secondsElapsed].length > 0) {
                //console2.log("Duplicates check");
                for (uint256 i; i < _proofTimeToBlockIndexes[secondsElapsed].length; i++) {
                    uint256 blockId = _proofTimeToBlockIndexes[secondsElapsed][i];

                    proveBlock(
                        Bob,
                        Bob,
                        metas[blockId],
                        parentHashes[blockId],
                        parentGasUsed[blockId],
                        gasUsed[blockId],
                        blockHashes[blockId],
                        signalRoots[blockId]
                    );
                }
            }

            // Increment time with 1 seconds
            vm.warp(block.timestamp + 1);
            //Log every 12 sec
            if (block.timestamp % 12 == 0) {
                printVariables();
            }
        }
        console2.log("-----------------------------!");
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
            ";",
            Strings.toString(block.timestamp),
            ";",
            Strings.toString(vars.lastVerifiedBlockId),
            ";",
            Strings.toString(vars.numBlocks),
            ";",
            Strings.toString(vars.blockFee),
            ";",
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
