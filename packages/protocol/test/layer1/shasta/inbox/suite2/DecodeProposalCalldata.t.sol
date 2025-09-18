// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { DevnetShastaInbox } from "src/layer1/shasta/impl/DevnetShastaInbox.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";

contract DecodeProposalCalldata is Test {
    DevnetShastaInbox inbox;

    function setUp() public {
        // Deploy DevnetShastaInbox instance for decoding
        inbox = new DevnetShastaInbox(
            address(0x1), // checkpointManager
            address(0x2), // proofVerifier
            address(0x3), // proposerChecker
            address(0x4)  // taikoToken
        );
    }

    function test_decodeProposalCalldata() public {
        // The raw calldata from the user
        bytes memory rawCalldata = hex"9791e64400000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001b7000000000000000000000c48000000000c2f2e54b352dd58fd085d95fe528c9eabe395f1bec2380b5d6aed0214091d505ab80000000000000000000000000000000000000000000000000000000000000000000002000000000c47000068cb21a00000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bcf8183d4ce6d4f75ba5c8bf8202d14db9e94f851cf8bd954c9c8897bd479861a395acd9d8dea32f20bf518910420ef90ed39d49355af4f7ee6a4af47b387f61ae000000000be4000068cb13b40000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc8dc8ee580f0f803a412a571557f14f70427bd1fc1965bbcf57eeaace9dbd764e3ac937c6a6897d2b9d63f7b3c7f612c22aa29370c7f9d7018f50fceb93e8b84b00000001000000000001010000003e536f75ef315e9a041548ab194c2c22a83d6e43d8e2e4ae16235b2db639f73c78ad54ff96468f7498a57c43cf32fa9a8b3917f6c28cc0c57ff640097d406f3401000000000c30eef654ac7163d83552992c5a1931b17e749ca65b2578934c1af2d18b32c5d35f9455424c5168f475dd97d54ed793a1eb5c67d5c250d50d211b270c09650be45b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        // Skip the function selector (first 4 bytes)
        bytes memory calldataWithoutSelector = new bytes(rawCalldata.length - 4);
        for (uint i = 0; i < calldataWithoutSelector.length; i++) {
            calldataWithoutSelector[i] = rawCalldata[i + 4];
        }

        // Decode the parameters: (bytes calldata _lookahead, bytes calldata _data)
        (bytes memory lookahead, bytes memory data) = abi.decode(calldataWithoutSelector, (bytes, bytes));

        console2.log("\n=== DECODED PROPOSE FUNCTION PARAMETERS ===\n");
        console2.log("Lookahead length:", lookahead.length);
        console2.log("Data length:", data.length);

        // Let's print the raw data to debug
        console2.log("\nRaw data (first 100 bytes):");
        bytes memory debugData = new bytes(100);
        for (uint i = 0; i < 100 && i < data.length; i++) {
            debugData[i] = data[i];
        }
        console2.logBytes(debugData);

        // Now decode the ProposeInput using the contract's decoder
        IInbox.ProposeInput memory input = inbox.decodeProposeInput(data);

        console2.log("\n=== PROPOSE INPUT STRUCTURE ===\n");
        console2.log("Deadline:", input.deadline);

        console2.log("\n--- Core State ---");
        console2.log("Next Proposal ID:", input.coreState.nextProposalId);
        console2.log("Last Finalized Proposal ID:", input.coreState.lastFinalizedProposalId);
        console2.log("Last Finalized Transition Hash:");
        console2.logBytes32(input.coreState.lastFinalizedTransitionHash);
        console2.log("Bond Instructions Hash:");
        console2.logBytes32(input.coreState.bondInstructionsHash);

        console2.log("\n--- Parent Proposals ---");
        console2.log("Number of parent proposals:", input.parentProposals.length);
        for (uint i = 0; i < input.parentProposals.length; i++) {
            console2.log("\nParent Proposal", i, ":");
            console2.log("  ID:", input.parentProposals[i].id);
            console2.log("  Timestamp:", input.parentProposals[i].timestamp);
            console2.log("  End of Submission Window:", input.parentProposals[i].endOfSubmissionWindowTimestamp);
            console2.log("  Proposer:", input.parentProposals[i].proposer);
            console2.log("  Core State Hash:");
            console2.logBytes32(input.parentProposals[i].coreStateHash);
            console2.log("  Derivation Hash:");
            console2.logBytes32(input.parentProposals[i].derivationHash);
        }

        console2.log("\n--- Blob Reference ---");
        console2.log("Blob Start Index:", input.blobReference.blobStartIndex);
        console2.log("Number of Blobs:", input.blobReference.numBlobs);
        console2.log("Offset:", input.blobReference.offset);

        console2.log("\n--- Transition Records ---");
        console2.log("Number of transition records:", input.transitionRecords.length);
        for (uint i = 0; i < input.transitionRecords.length; i++) {
            console2.log("\nTransition Record", i, ":");
            console2.log("  Span:", input.transitionRecords[i].span);
            console2.log("  Number of Bond Instructions:", input.transitionRecords[i].bondInstructions.length);

            for (uint j = 0; j < input.transitionRecords[i].bondInstructions.length; j++) {
                console2.log("  Bond Instruction", j, ":");
                console2.log("    Proposal ID:", input.transitionRecords[i].bondInstructions[j].proposalId);
                console2.log("    Bond Type:", uint(input.transitionRecords[i].bondInstructions[j].bondType));
                console2.log("    Payer:", input.transitionRecords[i].bondInstructions[j].payer);
                console2.log("    Receiver:", input.transitionRecords[i].bondInstructions[j].receiver);
            }

            console2.log("  Transition Hash:");
            console2.logBytes32(input.transitionRecords[i].transitionHash);
            console2.log("  Checkpoint Hash:");
            console2.logBytes32(input.transitionRecords[i].checkpointHash);
        }

        console2.log("\n--- Checkpoint ---");
        console2.log("Block Number:", input.checkpoint.blockNumber);
        console2.log("Block Hash:");
        console2.logBytes32(input.checkpoint.blockHash);
        console2.log("State Root:");
        console2.logBytes32(input.checkpoint.stateRoot);

        console2.log("\n--- Forced Inclusions ---");
        console2.log("Number of Forced Inclusions:", input.numForcedInclusions);

        // Now write to JSON file using vm.writeJson
        string memory json = _createJsonOutput(input);
        vm.writeFile("decoded_propose_calldata_verified.json", json);
        console2.log("\n=== JSON output written to decoded_propose_calldata_verified.json ===");
    }

    function _createJsonOutput(IInbox.ProposeInput memory input) internal pure returns (string memory) {
        string memory json = '{\n';
        json = string.concat(json, '  "function": "propose",\n');
        json = string.concat(json, '  "decoded_data": {\n');

        // Deadline
        json = string.concat(json, '    "deadline": ', vm.toString(input.deadline), ',\n');

        // Core State
        json = string.concat(json, '    "coreState": {\n');
        json = string.concat(json, '      "nextProposalId": ', vm.toString(input.coreState.nextProposalId), ',\n');
        json = string.concat(json, '      "lastFinalizedProposalId": ', vm.toString(input.coreState.lastFinalizedProposalId), ',\n');
        json = string.concat(json, '      "lastFinalizedTransitionHash": "', vm.toString(input.coreState.lastFinalizedTransitionHash), '",\n');
        json = string.concat(json, '      "bondInstructionsHash": "', vm.toString(input.coreState.bondInstructionsHash), '"\n');
        json = string.concat(json, '    },\n');

        // Parent Proposals
        json = string.concat(json, '    "parentProposals": [\n');
        for (uint i = 0; i < input.parentProposals.length; i++) {
            json = string.concat(json, '      {\n');
            json = string.concat(json, '        "id": ', vm.toString(input.parentProposals[i].id), ',\n');
            json = string.concat(json, '        "timestamp": ', vm.toString(input.parentProposals[i].timestamp), ',\n');
            json = string.concat(json, '        "endOfSubmissionWindowTimestamp": ', vm.toString(input.parentProposals[i].endOfSubmissionWindowTimestamp), ',\n');
            json = string.concat(json, '        "proposer": "', vm.toString(input.parentProposals[i].proposer), '",\n');
            json = string.concat(json, '        "coreStateHash": "', vm.toString(input.parentProposals[i].coreStateHash), '",\n');
            json = string.concat(json, '        "derivationHash": "', vm.toString(input.parentProposals[i].derivationHash), '"\n');
            json = string.concat(json, '      }');
            if (i < input.parentProposals.length - 1) {
                json = string.concat(json, ',');
            }
            json = string.concat(json, '\n');
        }
        json = string.concat(json, '    ],\n');

        // Blob Reference
        json = string.concat(json, '    "blobReference": {\n');
        json = string.concat(json, '      "blobStartIndex": ', vm.toString(input.blobReference.blobStartIndex), ',\n');
        json = string.concat(json, '      "numBlobs": ', vm.toString(input.blobReference.numBlobs), ',\n');
        json = string.concat(json, '      "offset": ', vm.toString(input.blobReference.offset), '\n');
        json = string.concat(json, '    },\n');

        // Transition Records
        json = string.concat(json, '    "transitionRecords": [\n');
        for (uint i = 0; i < input.transitionRecords.length; i++) {
            json = string.concat(json, '      {\n');
            json = string.concat(json, '        "span": ', vm.toString(input.transitionRecords[i].span), ',\n');
            json = string.concat(json, '        "bondInstructions": [\n');

            for (uint j = 0; j < input.transitionRecords[i].bondInstructions.length; j++) {
                json = string.concat(json, '          {\n');
                json = string.concat(json, '            "proposalId": ', vm.toString(input.transitionRecords[i].bondInstructions[j].proposalId), ',\n');
                json = string.concat(json, '            "bondType": ', vm.toString(uint(input.transitionRecords[i].bondInstructions[j].bondType)), ',\n');
                json = string.concat(json, '            "payer": "', vm.toString(input.transitionRecords[i].bondInstructions[j].payer), '",\n');
                json = string.concat(json, '            "receiver": "', vm.toString(input.transitionRecords[i].bondInstructions[j].receiver), '"\n');
                json = string.concat(json, '          }');
                if (j < input.transitionRecords[i].bondInstructions.length - 1) {
                    json = string.concat(json, ',');
                }
                json = string.concat(json, '\n');
            }

            json = string.concat(json, '        ],\n');
            json = string.concat(json, '        "transitionHash": "', vm.toString(input.transitionRecords[i].transitionHash), '",\n');
            json = string.concat(json, '        "checkpointHash": "', vm.toString(input.transitionRecords[i].checkpointHash), '"\n');
            json = string.concat(json, '      }');
            if (i < input.transitionRecords.length - 1) {
                json = string.concat(json, ',');
            }
            json = string.concat(json, '\n');
        }
        json = string.concat(json, '    ],\n');

        // Checkpoint
        json = string.concat(json, '    "checkpoint": {\n');
        json = string.concat(json, '      "blockNumber": ', vm.toString(input.checkpoint.blockNumber), ',\n');
        json = string.concat(json, '      "blockHash": "', vm.toString(input.checkpoint.blockHash), '",\n');
        json = string.concat(json, '      "stateRoot": "', vm.toString(input.checkpoint.stateRoot), '"\n');
        json = string.concat(json, '    },\n');

        // Forced Inclusions
        json = string.concat(json, '    "numForcedInclusions": ', vm.toString(input.numForcedInclusions), '\n');

        json = string.concat(json, '  }\n');
        json = string.concat(json, '}\n');

        return json;
    }
}