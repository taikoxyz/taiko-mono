// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibHashingOptimized } from "src/layer1/shasta/libs/LibHashingOptimized.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";

/// @title LibHashingOptimizedTest
/// @notice Comprehensive test suite for LibHashingOptimized library
contract LibHashingOptimizedTest is Test {
    function setUp() public { }

    // ---------------------------------------------------------------
    // Core Structure Hashing Tests
    // ---------------------------------------------------------------

    function test_hashTransition() public pure {
        ICheckpointStore.Checkpoint memory testCheckpoint = ICheckpointStore.Checkpoint({
            blockNumber: 12_345,
            blockHash: bytes32(uint256(0xabcd)),
            stateRoot: bytes32(uint256(0xdead))
        });

        IInbox.Transition memory testTransition = IInbox.Transition({
            proposalHash: bytes32(uint256(0x1111)),
            parentTransitionHash: bytes32(uint256(0x2222)),
            checkpoint: testCheckpoint
        });

        bytes32 hash = LibHashingOptimized.hashTransition(testTransition);
        assertNotEq(hash, bytes32(0), "Transition hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = LibHashingOptimized.hashTransition(testTransition);
        assertEq(hash, hash2, "Transition hash should be deterministic");
    }

    function test_hashCheckpoint() public pure {
        ICheckpointStore.Checkpoint memory testCheckpoint = ICheckpointStore.Checkpoint({
            blockNumber: 12_345,
            blockHash: bytes32(uint256(0xabcd)),
            stateRoot: bytes32(uint256(0xdead))
        });

        bytes32 hash = LibHashingOptimized.hashCheckpoint(testCheckpoint);
        assertNotEq(hash, bytes32(0), "Checkpoint hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = LibHashingOptimized.hashCheckpoint(testCheckpoint);
        assertEq(hash, hash2, "Checkpoint hash should be deterministic");
    }

    function test_hashCoreState() public pure {
        IInbox.CoreState memory testCoreState = IInbox.CoreState({
            nextProposalId: 100,
            nextProposalBlockId: 200,
            lastFinalizedProposalId: 99,
            lastFinalizedTransitionHash: bytes32(uint256(0x3333)),
            bondInstructionsHash: bytes32(uint256(0x4444))
        });

        bytes32 hash = LibHashingOptimized.hashCoreState(testCoreState);
        assertNotEq(hash, bytes32(0), "CoreState hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = LibHashingOptimized.hashCoreState(testCoreState);
        assertEq(hash, hash2, "CoreState hash should be deterministic");
    }

    function test_hashProposal() public pure {
        IInbox.Proposal memory testProposal = IInbox.Proposal({
            id: 42,
            timestamp: 1_000_000,
            endOfSubmissionWindowTimestamp: 2_000_000,
            proposer: address(0x1234567890AbcdEF1234567890aBcdef12345678),
            coreStateHash: bytes32(uint256(0x5555)),
            derivationHash: bytes32(uint256(0x6666))
        });

        bytes32 hash = LibHashingOptimized.hashProposal(testProposal);
        assertNotEq(hash, bytes32(0), "Proposal hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = LibHashingOptimized.hashProposal(testProposal);
        assertEq(hash, hash2, "Proposal hash should be deterministic");
    }

    function test_hashDerivation() public pure {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](2);

        bytes32[] memory blobHashes1 = new bytes32[](1);
        blobHashes1[0] = bytes32(uint256(0x7777));
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes1, offset: 100, timestamp: 3_000_000 })
        });

        bytes32[] memory blobHashes2 = new bytes32[](2);
        blobHashes2[0] = bytes32(uint256(0x8888));
        blobHashes2[1] = bytes32(uint256(0x9999));
        sources[1] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes2, offset: 200, timestamp: 4_000_000 })
        });

        IInbox.Derivation memory testDerivation = IInbox.Derivation({
            originBlockNumber: 50_000,
            originBlockHash: bytes32(uint256(0xaaaa)),
            basefeeSharingPctg: 10,
            sources: sources
        });

        bytes32 hash = LibHashingOptimized.hashDerivation(testDerivation);
        assertNotEq(hash, bytes32(0), "Derivation hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = LibHashingOptimized.hashDerivation(testDerivation);
        assertEq(hash, hash2, "Derivation hash should be deterministic");
    }

    function test_hashDerivation_EmptySources() public pure {
        IInbox.Derivation memory emptyDerivation = IInbox.Derivation({
            originBlockNumber: 1000,
            originBlockHash: bytes32(uint256(0xfeed)),
            basefeeSharingPctg: 5,
            sources: new IInbox.DerivationSource[](0)
        });

        bytes32 hash = LibHashingOptimized.hashDerivation(emptyDerivation);
        assertNotEq(hash, bytes32(0), "Empty derivation hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Array Hashing Tests
    // ---------------------------------------------------------------

    function test_hashBlobHashesArray() public pure {
        bytes32[] memory testBlobHashes = new bytes32[](3);
        testBlobHashes[0] = bytes32(uint256(0xddd1));
        testBlobHashes[1] = bytes32(uint256(0xddd2));
        testBlobHashes[2] = bytes32(uint256(0xddd3));

        bytes32 hash = LibHashingOptimized.hashBlobHashesArray(testBlobHashes);
        assertNotEq(hash, bytes32(0), "Blob hashes array hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = LibHashingOptimized.hashBlobHashesArray(testBlobHashes);
        assertEq(hash, hash2, "Blob hashes array hash should be deterministic");
    }

    function test_hashBlobHashesArray_Empty() public pure {
        bytes32[] memory emptyArray = new bytes32[](0);
        bytes32 hash = LibHashingOptimized.hashBlobHashesArray(emptyArray);
        assertEq(hash, keccak256(""), "Empty blob hashes array should hash to empty bytes hash");
    }

    function test_hashBlobHashesArray_Single() public pure {
        bytes32[] memory singleArray = new bytes32[](1);
        singleArray[0] = bytes32(uint256(0x1234));

        bytes32 hash = LibHashingOptimized.hashBlobHashesArray(singleArray);
        assertNotEq(hash, bytes32(0), "Single blob hash array should not be zero");
    }

    function test_hashBlobHashesArray_Two() public pure {
        bytes32[] memory twoArray = new bytes32[](2);
        twoArray[0] = bytes32(uint256(0x1234));
        twoArray[1] = bytes32(uint256(0x5678));

        bytes32 hash = LibHashingOptimized.hashBlobHashesArray(twoArray);
        assertNotEq(hash, bytes32(0), "Two blob hashes array should not be zero");
    }

    function test_hashTransitions() public pure {
        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: 12_345,
            blockHash: bytes32(uint256(0xabcd)),
            stateRoot: bytes32(uint256(0xdead))
        });

        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: 99_999,
            blockHash: bytes32(uint256(0xeeee)),
            stateRoot: bytes32(uint256(0xffff))
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](3);
        transitions[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(0x1111)),
            parentTransitionHash: bytes32(uint256(0x2222)),
            checkpoint: checkpoint1
        });
        transitions[1] = IInbox.Transition({
            proposalHash: bytes32(uint256(0xaaaa)),
            parentTransitionHash: bytes32(uint256(0xbbbb)),
            checkpoint: checkpoint1
        });
        transitions[2] = IInbox.Transition({
            proposalHash: bytes32(uint256(0xcccc)),
            parentTransitionHash: bytes32(uint256(0xdddd)),
            checkpoint: checkpoint2
        });

        bytes32 hash = LibHashingOptimized.hashTransitions(transitions);
        assertNotEq(hash, bytes32(0), "Transitions array hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = LibHashingOptimized.hashTransitions(transitions);
        assertEq(hash, hash2, "Transitions array hash should be deterministic");
    }

    function test_hashTransitions_Empty() public pure {
        IInbox.Transition[] memory emptyArray = new IInbox.Transition[](0);
        bytes32 hash = LibHashingOptimized.hashTransitions(emptyArray);
        assertEq(hash, keccak256(""), "Empty transitions array should hash to empty bytes hash");
    }

    function test_hashTransitions_Single() public pure {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 12_345,
            blockHash: bytes32(uint256(0xabcd)),
            stateRoot: bytes32(uint256(0xdead))
        });

        IInbox.Transition[] memory singleArray = new IInbox.Transition[](1);
        singleArray[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(0x1111)),
            parentTransitionHash: bytes32(uint256(0x2222)),
            checkpoint: checkpoint
        });

        bytes32 hash = LibHashingOptimized.hashTransitions(singleArray);
        assertNotEq(hash, bytes32(0), "Single transition array should not be zero");
    }

    function test_hashTransitions_Two() public pure {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 12_345,
            blockHash: bytes32(uint256(0xabcd)),
            stateRoot: bytes32(uint256(0xdead))
        });

        IInbox.Transition[] memory twoArray = new IInbox.Transition[](2);
        twoArray[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(0x1111)),
            parentTransitionHash: bytes32(uint256(0x2222)),
            checkpoint: checkpoint
        });
        twoArray[1] = IInbox.Transition({
            proposalHash: bytes32(uint256(0xfeed)),
            parentTransitionHash: bytes32(uint256(0xbeef)),
            checkpoint: checkpoint
        });

        bytes32 hash = LibHashingOptimized.hashTransitions(twoArray);
        assertNotEq(hash, bytes32(0), "Two transitions array should not be zero");
    }

    function test_hashTransitionRecord() public pure {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](2);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 10,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111111111111111111111111111111111111111),
            receiver: address(0x2222222222222222222222222222222222222222)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 11,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333333333333333333333333333333333333333),
            receiver: address(0x4444444444444444444444444444444444444444)
        });

        IInbox.TransitionRecord memory testTransitionRecord = IInbox.TransitionRecord({
            span: 5,
            transitionHash: bytes32(uint256(0xbbbb)),
            checkpointHash: bytes32(uint256(0xcccc)),
            bondInstructions: bondInstructions
        });

        bytes26 hash = LibHashingOptimized.hashTransitionRecord(testTransitionRecord);
        assertNotEq(hash, bytes26(0), "TransitionRecord hash should not be zero");

        // Verify deterministic hashing
        bytes26 hash2 = LibHashingOptimized.hashTransitionRecord(testTransitionRecord);
        assertEq(hash, hash2, "TransitionRecord hash should be deterministic");
    }

    function test_hashTransitionRecord_EmptyBondInstructions() public pure {
        IInbox.TransitionRecord memory emptyRecord = IInbox.TransitionRecord({
            span: 10,
            transitionHash: bytes32(uint256(0x1234)),
            checkpointHash: bytes32(uint256(0x5678)),
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        bytes26 hash = LibHashingOptimized.hashTransitionRecord(emptyRecord);
        assertNotEq(hash, bytes26(0), "Empty TransitionRecord hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Utility Function Tests
    // ---------------------------------------------------------------

    function test_composeTransitionKey() public pure {
        uint48 proposalId = 12_345;
        bytes32 parentHash = bytes32(uint256(0xabcdef));

        bytes32 key = LibHashingOptimized.composeTransitionKey(proposalId, parentHash);
        assertNotEq(key, bytes32(0), "Composite key should not be zero");

        // Verify deterministic key generation
        bytes32 key2 = LibHashingOptimized.composeTransitionKey(proposalId, parentHash);
        assertEq(key, key2, "Composite key should be deterministic");
    }

    // ---------------------------------------------------------------
    // Collision Resistance Tests
    // ---------------------------------------------------------------

    function test_hashCollisionResistance_DifferentProposals() public pure {
        IInbox.Proposal memory proposal1 = IInbox.Proposal({
            id: 1,
            timestamp: 1000,
            endOfSubmissionWindowTimestamp: 2000,
            proposer: address(0x1),
            coreStateHash: bytes32(uint256(0x1)),
            derivationHash: bytes32(uint256(0x1))
        });

        IInbox.Proposal memory proposal2 = IInbox.Proposal({
            id: 2, // Different ID
            timestamp: 1000,
            endOfSubmissionWindowTimestamp: 2000,
            proposer: address(0x1),
            coreStateHash: bytes32(uint256(0x1)),
            derivationHash: bytes32(uint256(0x1))
        });

        bytes32 hash1 = LibHashingOptimized.hashProposal(proposal1);
        bytes32 hash2 = LibHashingOptimized.hashProposal(proposal2);

        assertNotEq(hash1, hash2, "Different proposals should have different hashes");
    }

    function test_hashCollisionResistance_ArrayLengths() public pure {
        // Test that arrays of different lengths produce different hashes
        bytes32[] memory array1 = new bytes32[](1);
        array1[0] = bytes32(uint256(0x1234));

        bytes32[] memory array2 = new bytes32[](2);
        array2[0] = bytes32(uint256(0x1234));
        array2[1] = bytes32(uint256(0x0)); // Adding zero element

        bytes32 hash1 = LibHashingOptimized.hashBlobHashesArray(array1);
        bytes32 hash2 = LibHashingOptimized.hashBlobHashesArray(array2);

        assertNotEq(hash1, hash2, "Arrays with different lengths should have different hashes");
    }
}
