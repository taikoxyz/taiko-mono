// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";
import { LibProposeInputDecoder } from "src/layer1/shasta/libs/LibProposeInputDecoder.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";

contract LibProposeInputDecoderTest is Test {
    function test_baseline_vs_optimized_simple() public {
        // Setup simple test case
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 10,
            nextProposalBlockId: 1000,
            lastFinalizedProposalId: 9,
            lastFinalizedTransitionHash: bytes32(0),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);

        IInbox.Derivation[] memory derivations = new IInbox.Derivation[](1);
        derivations[0] = IInbox.Derivation({
            originBlockNumber: 100,
            originBlockHash: bytes32(uint256(100)),
            isForcedInclusion: false,
            basefeeSharingPctg: 50,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: new bytes32[](1), offset: 0, timestamp: 1000 })
        });
        derivations[0].blobSlice.blobHashes[0] = bytes32(uint256(1));

        proposals[0] = IInbox.Proposal({
            id: 10,
            proposer: address(0x1),
            timestamp: 1000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: bytes32(0),
            derivationHash: keccak256(abi.encode(derivations[0]))
        });

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 });

        IInbox.TransitionRecord[] memory transitionRecords = new IInbox.TransitionRecord[](1);
        transitionRecords[0] = IInbox.TransitionRecord({
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0),
            transitionHash: bytes32(0),
            checkpointHash: bytes32(0)
        });

        uint48 deadline = 2_000_000;

        // Create ProposeInput struct
        IInbox.ProposeInput memory proposeInput = IInbox.ProposeInput({
            deadline: deadline,
            coreState: coreState,
            parentProposals: proposals,
            blobReference: blobRef,
            transitionRecords: transitionRecords,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0,
                blockHash: bytes32(0),
                stateRoot: bytes32(0)
            }),
            numForcedInclusions: 0
        });

        // Test with standard ABI encoding for baseline
        bytes memory abiEncodedData = abi.encode(proposeInput);

        // Test with compact encoding
        bytes memory compactEncodedData = LibProposeInputDecoder.encode(proposeInput);

        // Measure baseline gas (ABI decoding)
        uint256 gasStart = gasleft();
        IInbox.ProposeInput memory decoded1 = abi.decode(abiEncodedData, (IInbox.ProposeInput));
        uint256 baselineGas = gasStart - gasleft();

        // Measure optimized gas (compact decoding)
        gasStart = gasleft();
        IInbox.ProposeInput memory decoded2 = LibProposeInputDecoder.decode(compactEncodedData);
        uint256 optimizedGas = gasStart - gasleft();

        // Verify correctness
        assertEq(decoded1.deadline, decoded2.deadline);
        assertEq(decoded1.coreState.nextProposalId, decoded2.coreState.nextProposalId);
        assertEq(
            decoded1.coreState.lastFinalizedProposalId, decoded2.coreState.lastFinalizedProposalId
        );
        assertEq(decoded1.parentProposals.length, decoded2.parentProposals.length);
        assertEq(decoded1.blobReference.numBlobs, decoded2.blobReference.numBlobs);
        assertEq(decoded1.transitionRecords.length, decoded2.transitionRecords.length);

        // Log gas usage
        emit log_named_uint("Simple case - Baseline ABI gas", baselineGas);
        emit log_named_uint("Simple case - Optimized compact gas", optimizedGas);

        // Log data sizes
        emit log_named_uint("ABI encoded size", abiEncodedData.length);
        emit log_named_uint("Compact encoded size", compactEncodedData.length);

        if (optimizedGas < baselineGas) {
            uint256 savings = ((baselineGas - optimizedGas) * 100) / baselineGas;
            emit log_named_uint("Gas savings %", savings);
        } else if (optimizedGas > baselineGas) {
            uint256 increase = ((optimizedGas - baselineGas) * 100) / baselineGas;
            emit log_named_uint("Gas increase %", increase);
        } else {
            emit log_string("Gas usage unchanged");
        }
    }

    function test_baseline_vs_optimized_complex() public {
        // Setup complex test case
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 100,
            nextProposalBlockId: 10_000,
            lastFinalizedProposalId: 95,
            lastFinalizedTransitionHash: keccak256("last_finalized"),
            bondInstructionsHash: keccak256("bond_instructions")
        });

        // Setup 2 proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        IInbox.Derivation[] memory derivations = new IInbox.Derivation[](2);

        derivations[0] = IInbox.Derivation({
            originBlockNumber: 5_000_000,
            originBlockHash: bytes32(uint256(5_000_000)),
            isForcedInclusion: false,
            basefeeSharingPctg: 50,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: new bytes32[](2),
                offset: 1024,
                timestamp: 1_000_001
            })
        });
        derivations[0].blobSlice.blobHashes[0] = keccak256("blob_hash_1");
        derivations[0].blobSlice.blobHashes[1] = keccak256("blob_hash_2");

        proposals[0] = IInbox.Proposal({
            id: 96,
            proposer: address(0x1234),
            timestamp: 1_000_000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: keccak256("core_state_96"),
            derivationHash: keccak256(abi.encode(derivations[0]))
        });

        derivations[1] = IInbox.Derivation({
            originBlockNumber: 5_000_010,
            originBlockHash: bytes32(uint256(5_000_010)),
            isForcedInclusion: true,
            basefeeSharingPctg: 75,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: new bytes32[](1),
                offset: 2048,
                timestamp: 1_000_011
            })
        });
        derivations[1].blobSlice.blobHashes[0] = keccak256("blob_hash_3");

        proposals[1] = IInbox.Proposal({
            id: 97,
            proposer: address(0x5678),
            timestamp: 1_000_010,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: keccak256("core_state_97"),
            derivationHash: keccak256(abi.encode(derivations[1]))
        });

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 1, numBlobs: 3, offset: 512 });

        // Setup 2 transition records with bond instructions
        IInbox.TransitionRecord[] memory transitionRecords = new IInbox.TransitionRecord[](2);

        LibBonds.BondInstruction[] memory bondInstructions1 = new LibBonds.BondInstruction[](2);
        bondInstructions1[0] = LibBonds.BondInstruction({
            proposalId: 96,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0xcccc),
            receiver: address(0xdddd)
        });
        bondInstructions1[1] = LibBonds.BondInstruction({
            proposalId: 96,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0xeeee),
            receiver: address(0xffff)
        });

        transitionRecords[0] = IInbox.TransitionRecord({
            span: 1,
            bondInstructions: bondInstructions1,
            transitionHash: keccak256("transition_96"),
            checkpointHash: keccak256("end_block_96")
        });

        LibBonds.BondInstruction[] memory bondInstructions2 = new LibBonds.BondInstruction[](1);
        bondInstructions2[0] = LibBonds.BondInstruction({
            proposalId: 97,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333),
            receiver: address(0x4444)
        });

        transitionRecords[1] = IInbox.TransitionRecord({
            span: 2,
            bondInstructions: bondInstructions2,
            transitionHash: keccak256("transition_97"),
            checkpointHash: keccak256("end_block_97")
        });

        uint48 deadline = 2_000_000;

        // Create ProposeInput struct
        IInbox.ProposeInput memory proposeInput = IInbox.ProposeInput({
            deadline: deadline,
            coreState: coreState,
            parentProposals: proposals,
            blobReference: blobRef,
            transitionRecords: transitionRecords,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 2_000_010,
                blockHash: keccak256("end_block"),
                stateRoot: keccak256("end_state")
            }),
            numForcedInclusions: 0
        });

        // Test with standard ABI encoding for baseline
        bytes memory abiEncodedData = abi.encode(proposeInput);

        // Test with compact encoding
        bytes memory compactEncodedData = LibProposeInputDecoder.encode(proposeInput);

        // Measure baseline gas (ABI decoding)
        uint256 gasStart = gasleft();
        IInbox.ProposeInput memory decoded1 = abi.decode(abiEncodedData, (IInbox.ProposeInput));
        uint256 baselineGas = gasStart - gasleft();

        // Measure optimized gas (compact decoding)
        gasStart = gasleft();
        IInbox.ProposeInput memory decoded2 = LibProposeInputDecoder.decode(compactEncodedData);
        uint256 optimizedGas = gasStart - gasleft();

        // Verify correctness
        assertEq(decoded1.deadline, decoded2.deadline);
        assertEq(decoded1.coreState.nextProposalId, decoded2.coreState.nextProposalId);
        assertEq(
            decoded1.coreState.lastFinalizedProposalId, decoded2.coreState.lastFinalizedProposalId
        );
        assertEq(
            decoded1.coreState.lastFinalizedTransitionHash,
            decoded2.coreState.lastFinalizedTransitionHash
        );
        assertEq(decoded1.coreState.bondInstructionsHash, decoded2.coreState.bondInstructionsHash);
        assertEq(decoded1.parentProposals.length, decoded2.parentProposals.length);
        assertEq(decoded1.blobReference.blobStartIndex, decoded2.blobReference.blobStartIndex);
        assertEq(decoded1.blobReference.numBlobs, decoded2.blobReference.numBlobs);
        assertEq(decoded1.blobReference.offset, decoded2.blobReference.offset);
        assertEq(decoded1.transitionRecords.length, decoded2.transitionRecords.length);

        // Log gas usage
        emit log_named_uint("Complex case - Baseline ABI gas", baselineGas);
        emit log_named_uint("Complex case - Optimized compact gas", optimizedGas);

        // Log data sizes
        emit log_named_uint("ABI encoded size", abiEncodedData.length);
        emit log_named_uint("Compact encoded size", compactEncodedData.length);

        if (optimizedGas < baselineGas) {
            uint256 savings = ((baselineGas - optimizedGas) * 100) / baselineGas;
            emit log_named_uint("Gas savings %", savings);
        } else if (optimizedGas > baselineGas) {
            uint256 increase = ((optimizedGas - baselineGas) * 100) / baselineGas;
            emit log_named_uint("Gas increase %", increase);
        } else {
            emit log_string("Gas usage unchanged");
        }
    }

    function test_correctness() public pure {
        // Test with various edge cases to ensure correctness
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            nextProposalBlockId: 0,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: bytes32(uint256(0xdead)),
            bondInstructionsHash: bytes32(uint256(0xbeef))
        });

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        IInbox.Derivation[] memory derivations = new IInbox.Derivation[](1);

        derivations[0] = IInbox.Derivation({
            originBlockNumber: 888_888,
            originBlockHash: bytes32(uint256(888_888)),
            isForcedInclusion: true,
            basefeeSharingPctg: 100,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: new bytes32[](3),
                offset: 16_777_215, // max uint24
                timestamp: 281_474_976_710_655 // max uint48
             })
        });

        for (uint256 i = 0; i < 3; i++) {
            derivations[0].blobSlice.blobHashes[i] = bytes32(uint256(i + 1));
        }

        proposals[0] = IInbox.Proposal({
            id: 1,
            proposer: address(0xabcd),
            timestamp: 999_999,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: bytes32(uint256(0x123456)),
            derivationHash: keccak256(abi.encode(derivations[0]))
        });

        LibBlobs.BlobReference memory blobRef = LibBlobs.BlobReference({
            blobStartIndex: 65_535, // max uint16
            numBlobs: 65_535, // max uint16
            offset: 16_777_215 // max uint24
         });

        IInbox.TransitionRecord[] memory transitionRecords = new IInbox.TransitionRecord[](0);

        uint48 deadline = 281_474_976_710_655; // max uint48

        // Create ProposeInput struct
        IInbox.ProposeInput memory proposeInput = IInbox.ProposeInput({
            deadline: deadline,
            coreState: coreState,
            parentProposals: proposals,
            blobReference: blobRef,
            transitionRecords: transitionRecords,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 999_999,
                blockHash: bytes32(uint256(0xabcdef)),
                stateRoot: bytes32(uint256(0xfedcba))
            }),
            numForcedInclusions: 0
        });

        // Encode using compact encoding
        bytes memory compactEncodedData = LibProposeInputDecoder.encode(proposeInput);

        // Decode
        IInbox.ProposeInput memory decodedInput = LibProposeInputDecoder.decode(compactEncodedData);

        // Verify all fields decoded correctly
        assertEq(decodedInput.deadline, deadline);
        assertEq(decodedInput.coreState.nextProposalId, coreState.nextProposalId);
        assertEq(decodedInput.coreState.lastFinalizedProposalId, coreState.lastFinalizedProposalId);
        assertEq(
            decodedInput.coreState.lastFinalizedTransitionHash,
            coreState.lastFinalizedTransitionHash
        );
        assertEq(decodedInput.coreState.bondInstructionsHash, coreState.bondInstructionsHash);

        assertEq(decodedInput.parentProposals.length, 1);
        assertEq(decodedInput.parentProposals[0].id, proposals[0].id);
        assertEq(decodedInput.parentProposals[0].proposer, proposals[0].proposer);

        assertEq(decodedInput.blobReference.blobStartIndex, blobRef.blobStartIndex);
        assertEq(decodedInput.blobReference.numBlobs, blobRef.numBlobs);
        assertEq(decodedInput.blobReference.offset, blobRef.offset);

        assertEq(decodedInput.transitionRecords.length, 0);

        assertEq(decodedInput.checkpoint.blockNumber, 999_999);
        assertEq(decodedInput.checkpoint.blockHash, bytes32(uint256(0xabcdef)));
        assertEq(decodedInput.checkpoint.stateRoot, bytes32(uint256(0xfedcba)));
    }
}
