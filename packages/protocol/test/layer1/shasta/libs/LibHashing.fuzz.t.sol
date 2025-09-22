// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibHashing } from "src/layer1/shasta/libs/LibHashing.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";

/// @title LibHashingFuzzTest
/// @notice Comprehensive fuzz testing for LibHashing library functions
contract LibHashingFuzzTest is Test {
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

        bytes32 hash1 = LibHashing.hashCheckpoint(checkpoint);
        bytes32 hash2 = LibHashing.hashCheckpoint(checkpoint);

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

        bytes32 hash1 = LibHashing.hashCheckpoint(checkpoint1);
        bytes32 hash2 = LibHashing.hashCheckpoint(checkpoint2);

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

        bytes32 hash1 = LibHashing.hashCoreState(coreState);
        bytes32 hash2 = LibHashing.hashCoreState(coreState);

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

        bytes32 hash1 = LibHashing.hashProposal(proposal);
        bytes32 hash2 = LibHashing.hashProposal(proposal);

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

        bytes32 hash1 = LibHashing.hashTransition(transition);
        bytes32 hash2 = LibHashing.hashTransition(transition);

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

        bytes32 hash1 = LibHashing.hashDerivation(derivation);
        bytes32 hash2 = LibHashing.hashDerivation(derivation);

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

        bytes32 hash1 = LibHashing.hashDerivation(derivation);
        bytes32 hash2 = LibHashing.hashDerivation(derivation);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Fuzz Test: hashTransitionsArray
    // ---------------------------------------------------------------

    function testFuzz_hashTransitionsArray_empty() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](0);

        bytes32 hash1 = LibHashing.hashTransitionsArray(transitions);
        bytes32 hash2 = LibHashing.hashTransitionsArray(transitions);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Empty array should have consistent hash
        assertEq(hash1, keccak256(""), "Empty array should hash to empty bytes hash");
    }

    function testFuzz_hashTransitionsArray_single(
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

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    function testFuzz_hashTransitionsArray_lengthMatters(
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

        bytes32 singleHash = LibHashing.hashTransitionsArray(singleArray);
        bytes32 doubleHash = LibHashing.hashTransitionsArray(doubleArray);

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

        bytes26 hash1 = LibHashing.hashTransitionRecord(record);
        bytes26 hash2 = LibHashing.hashTransitionRecord(record);

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

        bytes26 hash1 = LibHashing.hashTransitionRecord(record);
        bytes26 hash2 = LibHashing.hashTransitionRecord(record);

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
        bytes32 key1 = LibHashing.composeTransitionKey(proposalId, parentTransitionHash);
        bytes32 key2 = LibHashing.composeTransitionKey(proposalId, parentTransitionHash);

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

        bytes32 key1 = LibHashing.composeTransitionKey(proposalId1, parentTransitionHash1);
        bytes32 key2 = LibHashing.composeTransitionKey(proposalId2, parentTransitionHash2);

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

        bytes32 hash1 = LibHashing.hashCheckpoint(checkpoint1);
        bytes32 hash2 = LibHashing.hashCheckpoint(checkpoint2);

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
        bytes32 key1 = LibHashing.composeTransitionKey(proposalId, parentTransitionHash);
        bytes32 key2 = LibHashing.composeTransitionKey(proposalId, parentTransitionHash);
        bytes32 key3 = LibHashing.composeTransitionKey(proposalId, parentTransitionHash);

        assertEq(key1, key2, "Multiple calls should be consistent");
        assertEq(key2, key3, "Multiple calls should be consistent");
        assertEq(key1, key3, "Multiple calls should be consistent");
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

        bytes32 hash1 = LibHashing.hashDerivation(derivation);
        bytes32 hash2 = LibHashing.hashDerivation(derivation);

        // Hash should be deterministic even with many blobs
        assertEq(hash1, hash2, "Hash should be deterministic with many blobs");
        assertTrue(hash1 != bytes32(0), "Hash should not be zero with many blobs");
    }
}
