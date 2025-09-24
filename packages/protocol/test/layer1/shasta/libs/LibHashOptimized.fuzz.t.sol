// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibHashOptimized } from "src/layer1/shasta/libs/LibHashOptimized.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";

/// @title LibHashOptimizedFuzzTest
/// @notice Comprehensive fuzz testing for LibHashOptimized library functions
contract LibHashOptimizedFuzzTest is Test {
    // ---------------------------------------------------------------
    // Fuzz Test: hashCheckpoint
    // ---------------------------------------------------------------

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

        bytes32 hash1 = LibHashOptimized.hashCheckpoint(checkpoint);
        bytes32 hash2 = LibHashOptimized.hashCheckpoint(checkpoint);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    function testFuzz_hashCheckpoint_differentInputs(
        uint48 blockNumber1,
        bytes32 blockHash1,
        bytes32 stateRoot1,
        uint48 blockNumber2,
        bytes32 blockHash2,
        bytes32 stateRoot2
    )
        public
        pure
    {
        // Skip if inputs are identical
        vm.assume(
            blockNumber1 != blockNumber2 || blockHash1 != blockHash2 || stateRoot1 != stateRoot2
        );

        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber1,
            blockHash: blockHash1,
            stateRoot: stateRoot1
        });

        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber2,
            blockHash: blockHash2,
            stateRoot: stateRoot2
        });

        bytes32 hash1 = LibHashOptimized.hashCheckpoint(checkpoint1);
        bytes32 hash2 = LibHashOptimized.hashCheckpoint(checkpoint2);

        // Different inputs should produce different hashes
        assertTrue(hash1 != hash2, "Different inputs should produce different hashes");
    }

    // ---------------------------------------------------------------
    // Fuzz Test: hashCoreState
    // ---------------------------------------------------------------

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

        bytes32 hash1 = LibHashOptimized.hashCoreState(coreState);
        bytes32 hash2 = LibHashOptimized.hashCoreState(coreState);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Fuzz Test: hashProposal
    // ---------------------------------------------------------------

    function testFuzz_hashProposal(
        uint48 id,
        address proposer,
        uint48 timestamp,
        uint48 endOfSubmissionWindowTimestamp,
        bytes32 coreStateHash,
        bytes32 derivationHash
    )
        public
        pure
    {
        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: id,
            proposer: proposer,
            timestamp: timestamp,
            endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
            coreStateHash: coreStateHash,
            derivationHash: derivationHash
        });

        bytes32 hash1 = LibHashOptimized.hashProposal(proposal);
        bytes32 hash2 = LibHashOptimized.hashProposal(proposal);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Fuzz Test: hashTransition
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

        bytes32 hash1 = LibHashOptimized.hashTransition(transition);
        bytes32 hash2 = LibHashOptimized.hashTransition(transition);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Fuzz Test: hashDerivation
    // ---------------------------------------------------------------

    function testFuzz_hashDerivation_emptySources(
        uint48 originBlockNumber,
        bytes32 originBlockHash,
        uint8 basefeeSharingPctg
    )
        public
        pure
    {
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: originBlockNumber,
            originBlockHash: originBlockHash,
            basefeeSharingPctg: basefeeSharingPctg,
            sources: new IInbox.DerivationSource[](0)
        });

        bytes32 hash1 = LibHashOptimized.hashDerivation(derivation);
        bytes32 hash2 = LibHashOptimized.hashDerivation(derivation);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    function testFuzz_hashDerivation_singleSource(
        uint48 originBlockNumber,
        bytes32 originBlockHash,
        uint8 basefeeSharingPctg,
        bool isForcedInclusion,
        uint24 offset,
        uint48 timestamp,
        bytes32 blobHash
    )
        public
        pure
    {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = blobHash;

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: isForcedInclusion,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: offset,
                timestamp: timestamp
            })
        });

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: originBlockNumber,
            originBlockHash: originBlockHash,
            basefeeSharingPctg: basefeeSharingPctg,
            sources: sources
        });

        bytes32 hash1 = LibHashOptimized.hashDerivation(derivation);
        bytes32 hash2 = LibHashOptimized.hashDerivation(derivation);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Fuzz Test: hashTransitions
    // ---------------------------------------------------------------

    function testFuzz_hashTransitions_empty() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](0);

        bytes32 hash1 = LibHashOptimized.hashTransitions(transitions);
        bytes32 hash2 = LibHashOptimized.hashTransitions(transitions);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Empty array should have consistent hash
        assertEq(hash1, keccak256(""), "Empty array should hash to empty bytes hash");
    }

    function testFuzz_hashTransitions_single(
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

        bytes32 hash1 = LibHashOptimized.hashTransitions(transitions);
        bytes32 hash2 = LibHashOptimized.hashTransitions(transitions);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    function testFuzz_hashTransitions_lengthMatters(
        bytes32 proposalHash,
        bytes32 parentTransitionHash,
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        pure
    {
        // Create single transition
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: proposalHash,
            parentTransitionHash: parentTransitionHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber,
                blockHash: blockHash,
                stateRoot: stateRoot
            })
        });

        // Single element array
        IInbox.Transition[] memory singleArray = new IInbox.Transition[](1);
        singleArray[0] = transition;

        // Double element array with same element
        IInbox.Transition[] memory doubleArray = new IInbox.Transition[](2);
        doubleArray[0] = transition;
        doubleArray[1] = transition;

        bytes32 singleHash = LibHashOptimized.hashTransitions(singleArray);
        bytes32 doubleHash = LibHashOptimized.hashTransitions(doubleArray);

        // Different array lengths should produce different hashes even with same elements
        assertTrue(singleHash != doubleHash, "Array length should affect hash");
    }

    // ---------------------------------------------------------------
    // Fuzz Test: hashTransitionRecord
    // ---------------------------------------------------------------

    function testFuzz_hashTransitionRecord_emptyBonds(
        uint8 span,
        bytes32 transitionHash,
        bytes32 checkpointHash
    )
        public
        pure
    {
        IInbox.TransitionRecord memory record = IInbox.TransitionRecord({
            span: span,
            bondInstructions: new LibBonds.BondInstruction[](0),
            transitionHash: transitionHash,
            checkpointHash: checkpointHash
        });

        bytes26 hash1 = LibHashOptimized.hashTransitionRecord(record);
        bytes26 hash2 = LibHashOptimized.hashTransitionRecord(record);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes26(0), "Hash should not be zero");
    }

    function testFuzz_hashTransitionRecord_singleBond(
        uint8 span,
        bytes32 transitionHash,
        bytes32 checkpointHash,
        uint48 proposalId,
        uint8 bondTypeRaw,
        address payer,
        address receiver
    )
        public
        pure
    {
        // Bound bondType to valid enum range (3 types: 0-2: NONE, PROVABILITY, LIVENESS)
        LibBonds.BondType bondType = LibBonds.BondType(bound(bondTypeRaw, 0, 2));

        LibBonds.BondInstruction[] memory bonds = new LibBonds.BondInstruction[](1);
        bonds[0] = LibBonds.BondInstruction({
            proposalId: proposalId,
            bondType: bondType,
            payer: payer,
            receiver: receiver
        });

        IInbox.TransitionRecord memory record = IInbox.TransitionRecord({
            span: span,
            bondInstructions: bonds,
            transitionHash: transitionHash,
            checkpointHash: checkpointHash
        });

        bytes26 hash1 = LibHashOptimized.hashTransitionRecord(record);
        bytes26 hash2 = LibHashOptimized.hashTransitionRecord(record);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes26(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Fuzz Test: composeTransitionKey
    // ---------------------------------------------------------------

    function testFuzz_composeTransitionKey(
        uint48 proposalId,
        bytes32 parentTransitionHash
    )
        public
        pure
    {
        bytes32 key1 = LibHashOptimized.composeTransitionKey(proposalId, parentTransitionHash);
        bytes32 key2 = LibHashOptimized.composeTransitionKey(proposalId, parentTransitionHash);

        // Key should be deterministic
        assertEq(key1, key2, "Key should be deterministic");

        // Key should not be zero (extremely unlikely)
        assertTrue(key1 != bytes32(0), "Key should not be zero");
    }

    function testFuzz_composeTransitionKey_differentInputs(
        uint48 proposalId1,
        bytes32 parentTransitionHash1,
        uint48 proposalId2,
        bytes32 parentTransitionHash2
    )
        public
        pure
    {
        // Skip if inputs are identical
        vm.assume(proposalId1 != proposalId2 || parentTransitionHash1 != parentTransitionHash2);

        bytes32 key1 = LibHashOptimized.composeTransitionKey(proposalId1, parentTransitionHash1);
        bytes32 key2 = LibHashOptimized.composeTransitionKey(proposalId2, parentTransitionHash2);

        // Different inputs should produce different keys
        assertTrue(key1 != key2, "Different inputs should produce different keys");
    }

    // ---------------------------------------------------------------
    // Property-based tests for collision resistance
    // ---------------------------------------------------------------

    function testFuzz_hashCollisionResistance_checkpoints(
        uint48 blockNumber1,
        bytes32 blockHash1,
        bytes32 stateRoot1,
        uint48 blockNumber2,
        bytes32 blockHash2,
        bytes32 stateRoot2
    )
        public
        pure
    {
        // Ensure we have different inputs
        vm.assume(
            blockNumber1 != blockNumber2 || blockHash1 != blockHash2 || stateRoot1 != stateRoot2
        );

        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber1,
            blockHash: blockHash1,
            stateRoot: stateRoot1
        });

        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber2,
            blockHash: blockHash2,
            stateRoot: stateRoot2
        });

        bytes32 hash1 = LibHashOptimized.hashCheckpoint(checkpoint1);
        bytes32 hash2 = LibHashOptimized.hashCheckpoint(checkpoint2);

        // Should be collision resistant
        assertTrue(hash1 != hash2, "Hash function should be collision resistant");
    }

    function testFuzz_hashConsistency_multipleOperations(
        uint48 proposalId,
        bytes32 parentTransitionHash
    )
        public
        pure
    {
        // Test that calling the same function multiple times gives same result
        bytes32 key1 = LibHashOptimized.composeTransitionKey(proposalId, parentTransitionHash);
        bytes32 key2 = LibHashOptimized.composeTransitionKey(proposalId, parentTransitionHash);
        bytes32 key3 = LibHashOptimized.composeTransitionKey(proposalId, parentTransitionHash);

        assertEq(key1, key2, "Multiple calls should be consistent");
        assertEq(key2, key3, "Multiple calls should be consistent");
        assertEq(key1, key3, "Multiple calls should be consistent");
    }

    // ---------------------------------------------------------------
    // Additional tests from LibHashFuzz.t.sol
    // ---------------------------------------------------------------

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

        bytes32 hash1 = LibHashOptimized.hashDerivation(derivation);
        bytes32 hash2 = LibHashOptimized.hashDerivation(derivation);

        assertEq(hash1, hash2, "Derivation hash should be deterministic");
    }

    function testFuzz_hashBlobHashesArray_Single(bytes32 blobHash) public pure {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = blobHash;

        bytes32 hash1 = LibHashOptimized.hashBlobHashesArray(blobHashes);
        bytes32 hash2 = LibHashOptimized.hashBlobHashesArray(blobHashes);

        assertEq(hash1, hash2, "Blob hashes array hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero for non-empty array");
    }

    function testFuzz_hashBlobHashesArray_Two(bytes32 blobHash1, bytes32 blobHash2) public pure {
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = blobHash1;
        blobHashes[1] = blobHash2;

        bytes32 hash1 = LibHashOptimized.hashBlobHashesArray(blobHashes);
        bytes32 hash2 = LibHashOptimized.hashBlobHashesArray(blobHashes);

        assertEq(hash1, hash2, "Blob hashes array hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero for non-empty array");
    }

    function testFuzz_hashBlobHashesArray_Multiple(bytes32[] memory blobHashes) public pure {
        vm.assume(blobHashes.length > 0 && blobHashes.length <= 100); // Reasonable bounds

        bytes32 hash1 = LibHashOptimized.hashBlobHashesArray(blobHashes);
        bytes32 hash2 = LibHashOptimized.hashBlobHashesArray(blobHashes);

        assertEq(hash1, hash2, "Blob hashes array hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero for non-empty array");
    }

    function testFuzz_hashTransitions_Single(
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

        bytes32 hash1 = LibHashOptimized.hashTransitions(transitions);
        bytes32 hash2 = LibHashOptimized.hashTransitions(transitions);

        assertEq(hash1, hash2, "Transitions array hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero for non-empty array");
    }

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

        bytes32 hash1 = LibHashOptimized.hashProposal(proposal1);
        bytes32 hash2 = LibHashOptimized.hashProposal(proposal2);

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

        bytes32 hash1 = LibHashOptimized.hashBlobHashesArray(array1);
        bytes32 hash2 = LibHashOptimized.hashBlobHashesArray(array2);

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

        bytes32 hash1 = LibHashOptimized.hashCheckpoint(checkpoint1);
        bytes32 hash2 = LibHashOptimized.hashCheckpoint(checkpoint2);

        assertNotEq(hash1, hash2, "Different checkpoints should have different hashes");
    }

    function testFuzz_emptyArraysAlwaysHashToSame() public pure {
        bytes32[] memory emptyArray1 = new bytes32[](0);
        bytes32[] memory emptyArray2 = new bytes32[](0);

        bytes32 hash1 = LibHashOptimized.hashBlobHashesArray(emptyArray1);
        bytes32 hash2 = LibHashOptimized.hashBlobHashesArray(emptyArray2);

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

        bytes32 hash1 = LibHashOptimized.hashBlobHashesArray(largeArray);
        bytes32 hash2 = LibHashOptimized.hashBlobHashesArray(largeArray);

        assertEq(hash1, hash2, "Large arrays should hash deterministically");
        assertNotEq(hash1, bytes32(0), "Large array hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Edge cases and boundary tests
    // ---------------------------------------------------------------

    function testFuzz_hashDerivation_maxBlobHashes(
        uint48 originBlockNumber,
        bytes32 originBlockHash,
        uint8 basefeeSharingPctg,
        bool isForcedInclusion,
        uint24 offset,
        uint48 timestamp
    )
        public
        pure
    {
        // Test with maximum reasonable number of blob hashes (bounded for gas)
        uint256 numBlobs = bound(timestamp, 1, 20); // Use timestamp as seed, bound to reasonable
            // range

        bytes32[] memory blobHashes = new bytes32[](numBlobs);
        for (uint256 i = 0; i < numBlobs; i++) {
            blobHashes[i] = keccak256(abi.encode("blob", i, timestamp));
        }

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: isForcedInclusion,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes,
                offset: offset,
                timestamp: timestamp
            })
        });

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: originBlockNumber,
            originBlockHash: originBlockHash,
            basefeeSharingPctg: basefeeSharingPctg,
            sources: sources
        });

        bytes32 hash1 = LibHashOptimized.hashDerivation(derivation);
        bytes32 hash2 = LibHashOptimized.hashDerivation(derivation);

        // Hash should be deterministic even with many blobs
        assertEq(hash1, hash2, "Hash should be deterministic with many blobs");
        assertTrue(hash1 != bytes32(0), "Hash should not be zero with many blobs");
    }
}
