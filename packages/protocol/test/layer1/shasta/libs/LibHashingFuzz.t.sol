// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibHashing } from "src/layer1/shasta/libs/LibHashing.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";

/// @title LibHashingFuzzTest
/// @notice Fuzz testing suite for LibHashing library
contract LibHashingFuzzTest is Test {
    // ---------------------------------------------------------------
    // Fuzz Tests for Core Structures
    // ---------------------------------------------------------------

    function testFuzz_hashTransition(
        bytes32 proposalHash,
        bytes32 parentTransitionHash,
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        pure
    {
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: proposalHash,
            parentTransitionHash: parentTransitionHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber,
                blockHash: blockHash,
                stateRoot: stateRoot
            })
        });

        bytes32 hash1 = LibHashing.hashTransition(transition);
        bytes32 hash2 = LibHashing.hashTransition(transition);

        assertEq(hash1, hash2, "Transition hash should be deterministic");
    }

    function testFuzz_hashCheckpoint(
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        pure
    {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber,
            blockHash: blockHash,
            stateRoot: stateRoot
        });

        bytes32 hash1 = LibHashing.hashCheckpoint(checkpoint);
        bytes32 hash2 = LibHashing.hashCheckpoint(checkpoint);

        assertEq(hash1, hash2, "Checkpoint hash should be deterministic");
    }

    function testFuzz_hashCoreState(
        uint48 nextProposalId,
        uint48 nextProposalBlockId,
        uint48 lastFinalizedProposalId,
        bytes32 lastFinalizedTransitionHash,
        bytes32 bondInstructionsHash
    )
        public
        pure
    {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: nextProposalId,
            nextProposalBlockId: nextProposalBlockId,
            lastFinalizedProposalId: lastFinalizedProposalId,
            lastFinalizedTransitionHash: lastFinalizedTransitionHash,
            bondInstructionsHash: bondInstructionsHash
        });

        bytes32 hash1 = LibHashing.hashCoreState(coreState);
        bytes32 hash2 = LibHashing.hashCoreState(coreState);

        assertEq(hash1, hash2, "CoreState hash should be deterministic");
    }

    function testFuzz_hashProposal(
        uint48 id,
        uint48 timestamp,
        uint48 endOfSubmissionWindowTimestamp,
        address proposer,
        bytes32 coreStateHash,
        bytes32 derivationHash
    )
        public
        pure
    {
        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: id,
            timestamp: timestamp,
            endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
            proposer: proposer,
            coreStateHash: coreStateHash,
            derivationHash: derivationHash
        });

        bytes32 hash1 = LibHashing.hashProposal(proposal);
        bytes32 hash2 = LibHashing.hashProposal(proposal);

        assertEq(hash1, hash2, "Proposal hash should be deterministic");
    }

    function testFuzz_hashDerivation_WithSources(
        uint48 originBlockNumber,
        bytes32 originBlockHash,
        uint8 basefeeSharingPctg,
        bool isForcedInclusion1,
        bytes32 blobHash1,
        uint16 offset1,
        uint48 timestamp1
    )
        public
        pure
    {
        // Limit basefee sharing percentage to valid range
        basefeeSharingPctg = basefeeSharingPctg % 101; // 0-100

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);

        bytes32[] memory blobHashes1 = new bytes32[](1);
        blobHashes1[0] = blobHash1;

        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: isForcedInclusion1,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes1,
                offset: offset1,
                timestamp: timestamp1
            })
        });

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: originBlockNumber,
            originBlockHash: originBlockHash,
            basefeeSharingPctg: basefeeSharingPctg,
            sources: sources
        });

        bytes32 hash1 = LibHashing.hashDerivation(derivation);
        bytes32 hash2 = LibHashing.hashDerivation(derivation);

        assertEq(hash1, hash2, "Derivation hash should be deterministic");
    }

    // ---------------------------------------------------------------
    // Fuzz Tests for Array Hashing
    // ---------------------------------------------------------------

    function testFuzz_hashBlobHashesArray_Single(bytes32 blobHash) public pure {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = blobHash;

        bytes32 hash1 = LibHashing.hashBlobHashesArray(blobHashes);
        bytes32 hash2 = LibHashing.hashBlobHashesArray(blobHashes);

        assertEq(hash1, hash2, "Blob hashes array hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero for non-empty array");
    }

    function testFuzz_hashBlobHashesArray_Two(bytes32 blobHash1, bytes32 blobHash2) public pure {
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = blobHash1;
        blobHashes[1] = blobHash2;

        bytes32 hash1 = LibHashing.hashBlobHashesArray(blobHashes);
        bytes32 hash2 = LibHashing.hashBlobHashesArray(blobHashes);

        assertEq(hash1, hash2, "Blob hashes array hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero for non-empty array");
    }

    function testFuzz_hashBlobHashesArray_Multiple(bytes32[] memory blobHashes) public pure {
        vm.assume(blobHashes.length > 0 && blobHashes.length <= 100); // Reasonable bounds

        bytes32 hash1 = LibHashing.hashBlobHashesArray(blobHashes);
        bytes32 hash2 = LibHashing.hashBlobHashesArray(blobHashes);

        assertEq(hash1, hash2, "Blob hashes array hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero for non-empty array");
    }

    function testFuzz_hashTransitionsArray_Single(
        bytes32 proposalHash,
        bytes32 parentTransitionHash,
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        pure
    {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposalHash: proposalHash,
            parentTransitionHash: parentTransitionHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber,
                blockHash: blockHash,
                stateRoot: stateRoot
            })
        });

        bytes32 hash1 = LibHashing.hashTransitionsArray(transitions);
        bytes32 hash2 = LibHashing.hashTransitionsArray(transitions);

        assertEq(hash1, hash2, "Transitions array hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero for non-empty array");
    }

    function testFuzz_hashTransitionRecord(
        uint8 span,
        bytes32 transitionHash,
        bytes32 checkpointHash,
        uint8 numInstructions
    )
        public
        pure
    {
        // Limit instructions to reasonable number
        numInstructions = numInstructions % 10;

        LibBonds.BondInstruction[] memory bondInstructions =
            new LibBonds.BondInstruction[](numInstructions);

        for (uint256 i = 0; i < numInstructions; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(i),
                bondType: i % 2 == 0 ? LibBonds.BondType.PROVABILITY : LibBonds.BondType.LIVENESS,
                payer: address(uint160(i + 1)),
                receiver: address(uint160(i + 100))
            });
        }

        IInbox.TransitionRecord memory record = IInbox.TransitionRecord({
            span: span,
            transitionHash: transitionHash,
            checkpointHash: checkpointHash,
            bondInstructions: bondInstructions
        });

        bytes26 hash1 = LibHashing.hashTransitionRecord(record);
        bytes26 hash2 = LibHashing.hashTransitionRecord(record);

        assertEq(hash1, hash2, "TransitionRecord hash should be deterministic");
    }

    // ---------------------------------------------------------------
    // Fuzz Tests for Utility Functions
    // ---------------------------------------------------------------

    function testFuzz_composeTransitionKey(
        uint48 proposalId,
        bytes32 parentTransitionHash
    )
        public
        pure
    {
        bytes32 key1 = LibHashing.composeTransitionKey(proposalId, parentTransitionHash);
        bytes32 key2 = LibHashing.composeTransitionKey(proposalId, parentTransitionHash);

        assertEq(key1, key2, "Composite key should be deterministic");
        assertNotEq(key1, bytes32(0), "Composite key should not be zero");
    }

    // ---------------------------------------------------------------
    // Differential Fuzz Tests (Collision Resistance)
    // ---------------------------------------------------------------

    function testFuzz_differentProposals_DifferentHashes(
        uint48 id1,
        uint48 id2,
        uint48 timestamp,
        address proposer
    )
        public
        pure
    {
        vm.assume(id1 != id2); // Ensure different IDs
        // Ensure timestamp doesn't cause overflow
        vm.assume(timestamp < type(uint48).max - 1000);

        IInbox.Proposal memory proposal1 = IInbox.Proposal({
            id: id1,
            timestamp: timestamp,
            endOfSubmissionWindowTimestamp: timestamp + 1000,
            proposer: proposer,
            coreStateHash: bytes32(uint256(0x1)),
            derivationHash: bytes32(uint256(0x2))
        });

        IInbox.Proposal memory proposal2 = IInbox.Proposal({
            id: id2,
            timestamp: timestamp,
            endOfSubmissionWindowTimestamp: timestamp + 1000,
            proposer: proposer,
            coreStateHash: bytes32(uint256(0x1)),
            derivationHash: bytes32(uint256(0x2))
        });

        bytes32 hash1 = LibHashing.hashProposal(proposal1);
        bytes32 hash2 = LibHashing.hashProposal(proposal2);

        assertNotEq(hash1, hash2, "Different proposals should have different hashes");
    }

    function testFuzz_differentArrayLengths_DifferentHashes(
        bytes32 element,
        uint8 length1,
        uint8 length2
    )
        public
        pure
    {
        // Limit to reasonable array sizes and ensure different lengths
        length1 = (length1 % 20) + 1; // 1-20
        length2 = (length2 % 20) + 21; // 21-40
        vm.assume(length1 != length2);

        bytes32[] memory array1 = new bytes32[](length1);
        bytes32[] memory array2 = new bytes32[](length2);

        // Fill arrays with same element
        for (uint256 i = 0; i < length1; i++) {
            array1[i] = element;
        }
        for (uint256 i = 0; i < length2; i++) {
            array2[i] = element;
        }

        bytes32 hash1 = LibHashing.hashBlobHashesArray(array1);
        bytes32 hash2 = LibHashing.hashBlobHashesArray(array2);

        assertNotEq(hash1, hash2, "Arrays with different lengths should have different hashes");
    }

    function testFuzz_differentCheckpoints_DifferentHashes(
        uint48 blockNumber1,
        uint48 blockNumber2,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        pure
    {
        vm.assume(blockNumber1 != blockNumber2); // Ensure different block numbers

        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber1,
            blockHash: blockHash,
            stateRoot: stateRoot
        });

        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber2,
            blockHash: blockHash,
            stateRoot: stateRoot
        });

        bytes32 hash1 = LibHashing.hashCheckpoint(checkpoint1);
        bytes32 hash2 = LibHashing.hashCheckpoint(checkpoint2);

        assertNotEq(hash1, hash2, "Different checkpoints should have different hashes");
    }

    // ---------------------------------------------------------------
    // Edge Case Fuzz Tests
    // ---------------------------------------------------------------

    function testFuzz_emptyArraysAlwaysHashToSame() public pure {
        bytes32[] memory emptyArray1 = new bytes32[](0);
        bytes32[] memory emptyArray2 = new bytes32[](0);

        bytes32 hash1 = LibHashing.hashBlobHashesArray(emptyArray1);
        bytes32 hash2 = LibHashing.hashBlobHashesArray(emptyArray2);

        assertEq(hash1, hash2, "Empty arrays should always hash to the same value");
        assertEq(hash1, keccak256(""), "Empty arrays should hash to keccak256 of empty bytes");
    }

    function testFuzz_largeArraysHandled(uint8 size) public pure {
        // Test with larger arrays (up to 255 elements)
        vm.assume(size > 0);

        bytes32[] memory largeArray = new bytes32[](size);
        for (uint256 i = 0; i < size; i++) {
            largeArray[i] = bytes32(uint256(i));
        }

        bytes32 hash1 = LibHashing.hashBlobHashesArray(largeArray);
        bytes32 hash2 = LibHashing.hashBlobHashesArray(largeArray);

        assertEq(hash1, hash2, "Large arrays should hash deterministically");
        assertNotEq(hash1, bytes32(0), "Large array hash should not be zero");
    }
}
