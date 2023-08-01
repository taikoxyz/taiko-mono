// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { LibUtils } from "../contracts/L1/libs/LibUtils.sol";
import { TaikoConfig } from "../contracts/L1/TaikoConfig.sol";
import { TaikoData } from "../contracts/L1/TaikoData.sol";
import { TaikoErrors } from "../contracts/L1/TaikoErrors.sol";
import { TaikoL1 } from "../contracts/L1/TaikoL1.sol";
import { TaikoToken } from "../contracts/L1/TaikoToken.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { TaikoL1TestBase } from "./TaikoL1TestBase.t.sol";
import { NonEmptyBytes121K } from "./NonEmpty_120K_Bytes.sol";

contract TaikoL1MaxGasMeasurements is TaikoL1 {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config = TaikoConfig.getConfig();

        config.blockTxListExpiry = 5 minutes;
        config.blockMaxVerificationsPerTx = 10;
        config.blockMaxProposals = 30;
        config.blockRingBufferSize = 32;
        config.proofRegularCooldown = 15 minutes;
        config.proofRegularCooldown = 15 minutes;
    }
}

contract Verifier {
    fallback(bytes calldata) external returns (bytes memory) {
        return bytes.concat(keccak256("taiko"));
    }
}

contract TaikoL1MaxGasMeasurementsTest is TaikoL1TestBase {
    uint256 blocksToSimulate = 25;
    bytes32 parentHash = GENESIS_BLOCK_HASH;
    
    bytes32[] parentHashes = new bytes32[](blocksToSimulate);
    bytes32[] blockHashes = new bytes32[](blocksToSimulate);
    bytes32[] signalRoots = new bytes32[](blocksToSimulate);
    uint32[] parentGasUsed = new uint32[](blocksToSimulate);
    uint32[] gasUsed = new uint32[](blocksToSimulate);
    uint32[] gasLimits = new uint32[](blocksToSimulate);

    function deployTaikoL1() internal override returns (TaikoL1 taikoL1) {
        taikoL1 = new TaikoL1MaxGasMeasurements();
    }

    function setUp() public override {
        TaikoL1TestBase.setUp();
        registerAddress(L1.getVerifierName(100), address(new Verifier()));
        registerAddress("oracle_prover", Alice);
    }

    function proposeBlockInternal(
        address proposer,
        uint32 gasLimit,
        uint24 txListSize,
        bool measureConsumedGas
    )
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
        bytes memory txList = NonEmptyBytes121K.getNonEmpty120KBytes();
        
        TaikoData.BlockMetadataInput memory input = TaikoData.BlockMetadataInput({
            beneficiary: proposer,
            gasLimit: gasLimit,
            txListHash: keccak256(txList),
            txListByteStart: 0,
            txListByteEnd: txListSize,
            cacheTxListInfo: false
        });

        TaikoData.StateVariables memory variables = L1.getStateVariables();

        uint256 _mixHash;
        unchecked {
            _mixHash = block.prevrandao * variables.numBlocks;
        }

        meta.id = variables.numBlocks;
        meta.timestamp = uint64(block.timestamp);
        meta.l1Height = uint64(block.number - 1);
        meta.l1Hash = blockhash(block.number - 1);
        meta.mixHash = bytes32(_mixHash);
        meta.txListHash = keccak256(txList);
        meta.txListByteStart = 0;
        meta.txListByteEnd = txListSize;
        meta.gasLimit = gasLimit;
        meta.beneficiary = proposer;
        meta.treasury = L2Treasury;

        if(measureConsumedGas) {
            uint256 gasRemaining = gasleft();
            vm.prank(proposer, proposer);
            meta = L1.proposeBlock(abi.encode(input), txList);
            uint256 gasRemainingAfter10Verification = gasleft();
            console2.log("Gas used by proposeBlock() with 10 verifications:",gasRemaining - gasRemainingAfter10Verification );
        }
        else{
            vm.prank(proposer, proposer);
            meta = L1.proposeBlock(abi.encode(input), txList);
        }
    }


    function proveBlockInternal(
        address msgSender,
        address prover,
        TaikoData.BlockMetadata memory meta,
        bytes32 parentHashSingle,
        uint32 parentGasUsedSingle,
        uint32 gasUsedSingle,
        bytes32 blockHash,
        bytes32 signalRoot,
        bool measureConsumedGas
    )
        internal
    {
        TaikoData.BlockEvidence memory evidence = TaikoData.BlockEvidence({
            metaHash: LibUtils.hashMetadata(meta),
            parentHash: parentHashSingle,
            blockHash: blockHash,
            signalRoot: signalRoot,
            graffiti: 0x0,
            prover: prover,
            parentGasUsed: parentGasUsedSingle,
            gasUsed: gasUsedSingle,
            proofs: new bytes(102)
        });

        bytes32 instance = getInstance(conf, evidence);
        uint16 verifierId = 100;

        evidence.proofs = bytes.concat(
            bytes2(verifierId),
            bytes16(0),
            bytes16(instance),
            bytes16(0),
            bytes16(uint128(uint256(instance))),
            new bytes(100)
        );


        if(measureConsumedGas) {
            uint256 gasRemaining = gasleft();
            vm.prank(msgSender, msgSender);
            L1.proveBlock(meta.id, abi.encode(evidence));
            uint256 gasRemainingAfter10Verification = gasleft();
            console2.log("Gas used by proveBlock() with 10 verifications:",gasRemaining - gasRemainingAfter10Verification );
        }
        else{
            vm.prank(msgSender, msgSender);
            L1.proveBlock(meta.id, abi.encode(evidence));
        }
    }

    function test_gasConsumption_with10verifications_in_a_row_with_prove_and_propose() external {

        bytes memory txList2 = NonEmptyBytes121K.getNonEmpty120KBytes();
        console2.log("txList hossza:");
        console2.log(txList2.length);

        // Save metadata
        TaikoData.BlockMetadata[] memory metas = new TaikoData.BlockMetadata[](
            blocksToSimulate
        );
        // Carol is the oracle prover
        //registerAddress("oracle_prover", Carol);

        depositTaikoToken(Alice, 1000 * 1e8, 1000 ether);
        console2.log("Alice balance:", tko.balanceOf(Alice));

        depositTaikoToken(Bob, 1e6 * 1e8, 100 ether);
        console2.log("Bob balance:", tko.balanceOf(Bob));
        // Bob
        vm.prank(Bob, Bob);
        proverPool.reset(Bob, 10);

        uint256 proposedIndex;
        // This one is proposing 25 blocks
        for (
            uint256 blockId = 1;
            blockId < 23;
            blockId++
        ) {
            if (proposedIndex == 0) {
                parentGasUsed[proposedIndex] = 0;
                parentHashes[proposedIndex] = GENESIS_BLOCK_HASH;
            } else {
                parentGasUsed[proposedIndex] = gasUsed[proposedIndex - 1];
                parentHashes[proposedIndex] = blockHashes[proposedIndex - 1];
            }
            gasUsed[proposedIndex] = 6_000_000;
            blockHashes[proposedIndex] = bytes32(1e10 + blockId);
            signalRoots[proposedIndex] = bytes32(1e9 + blockId);

            //printVariables("before propose");
            metas[proposedIndex] =
                proposeBlockInternal(Alice, 6_000_000, 120_000, false);
            
            if (proposedIndex < blocksToSimulate - 1) proposedIndex++;
            printVariables("after propose");
            mine(1);

            // Prove blocks from 1 .. 21
            if(blockId == 22)
            {
                for (uint j = 1; j < blockId-1; j++) {
                    proveBlockInternal(
                        Bob,
                        Bob,
                        metas[j],
                        parentHashes[j],
                        parentGasUsed[j],
                        gasUsed[j],
                        blockHashes[j],
                        signalRoots[j],
                        false
                    );
                }

                printVariables("after proves - but not the first");
                // Prove block will verify 10 blocks (1..10)
                proveBlockInternal(
                    Bob,
                    Bob,
                    metas[0],
                    parentHashes[0],
                    parentGasUsed[0],
                    gasUsed[0],
                    blockHashes[0],
                    signalRoots[0],
                    false
                );

                vm.warp(block.timestamp + 1 seconds);
                vm.warp(block.timestamp + 10 * (conf.proofRegularCooldown));
                
                proveBlockInternal(
                    Bob,
                    Bob,
                    metas[blockId-1],
                    parentHashes[blockId-1],
                    parentGasUsed[blockId-1],
                    gasUsed[blockId-1],
                    blockHashes[blockId-1],
                    signalRoots[blockId-1],
                    true
                );

                printVariables("after proves - this one should have verified 10");

                proposeBlockInternal(Alice, 1_000_000, 1024, true);
                printVariables("after propose - this one should have verified 10 again");
            }
        }
        printVariables("");
    }
}
