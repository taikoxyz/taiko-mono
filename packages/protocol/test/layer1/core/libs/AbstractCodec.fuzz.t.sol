// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title AbstractCodecFuzzTest
/// @notice Abstract base fuzz test for ICodec implementations
/// @dev This allows sharing fuzz test cases between CodecSimple and CodecOptimized
abstract contract AbstractCodecFuzzTest is Test {
    ICodec internal codec;

    /// @notice Must be implemented by concrete test contracts to provide the codec instance
    function _getCodec() internal virtual returns (ICodec);

    function setUp() public virtual {
        codec = _getCodec();
    }

    // ---------------------------------------------------------------
    // Fuzz Test: hashCheckpoint
    // ---------------------------------------------------------------

    function testFuzz_hashCheckpoint(
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        view
    {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber, blockHash: blockHash, stateRoot: stateRoot
        });

        bytes32 hash1 = codec.hashCheckpoint(checkpoint);
        bytes32 hash2 = codec.hashCheckpoint(checkpoint);

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
        view
    {
        // Skip if inputs are identical
        vm.assume(
            blockNumber1 != blockNumber2 || blockHash1 != blockHash2 || stateRoot1 != stateRoot2
        );

        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber1, blockHash: blockHash1, stateRoot: stateRoot1
        });

        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber2, blockHash: blockHash2, stateRoot: stateRoot2
        });

        bytes32 hash1 = codec.hashCheckpoint(checkpoint1);
        bytes32 hash2 = codec.hashCheckpoint(checkpoint2);

        // Different inputs should produce different hashes
        assertTrue(hash1 != hash2, "Different inputs should produce different hashes");
    }

    // ---------------------------------------------------------------
    // Fuzz Test: hashCoreState
    // ---------------------------------------------------------------

    function testFuzz_hashCoreState(
        uint48 nextProposalId,
        uint48 lastProposalBlockId,
        uint48 lastFinalizedProposalId,
        bytes32 lastFinalizedTransitionHash,
        bytes32 bondInstructionsHash
    )
        public
        view
    {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: nextProposalId,
            lastProposalBlockId: lastProposalBlockId,
            lastFinalizedProposalId: lastFinalizedProposalId,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: lastFinalizedTransitionHash,
            bondInstructionsHash: bondInstructionsHash
        });

        bytes32 hash1 = codec.hashCoreState(coreState);
        bytes32 hash2 = codec.hashCoreState(coreState);

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
        view
    {
        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: id,
            proposer: proposer,
            timestamp: timestamp,
            endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
            coreStateHash: coreStateHash,
            derivationHash: derivationHash
        });

        bytes32 hash1 = codec.hashProposal(proposal);
        bytes32 hash2 = codec.hashProposal(proposal);

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
        view
    {
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: proposalHash,
            parentTransitionHash: parentTransitionHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber, blockHash: blockHash, stateRoot: stateRoot
            })
        });

        bytes32 hash1 = codec.hashTransition(transition);
        bytes32 hash2 = codec.hashTransition(transition);

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
        view
    {
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: originBlockNumber,
            originBlockHash: originBlockHash,
            basefeeSharingPctg: basefeeSharingPctg,
            sources: new IInbox.DerivationSource[](0)
        });

        bytes32 hash1 = codec.hashDerivation(derivation);
        bytes32 hash2 = codec.hashDerivation(derivation);

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
        view
    {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = blobHash;

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: isForcedInclusion,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes, offset: offset, timestamp: timestamp
            })
        });

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: originBlockNumber,
            originBlockHash: originBlockHash,
            basefeeSharingPctg: basefeeSharingPctg,
            sources: sources
        });

        bytes32 hash1 = codec.hashDerivation(derivation);
        bytes32 hash2 = codec.hashDerivation(derivation);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Fuzz Test: hashTransitionsWithMetadata
    // ---------------------------------------------------------------

    function testFuzz_hashTransitionsWithMetadata_single(
        bytes32 proposalHash,
        bytes32 parentTransitionHash,
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        view
    {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposalHash: proposalHash,
            parentTransitionHash: parentTransitionHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber, blockHash: blockHash, stateRoot: stateRoot
            })
        });

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(uint160(uint256(proposalHash) % type(uint160).max)),
            actualProver: address(uint160(uint256(parentTransitionHash) % type(uint160).max))
        });
        bytes32 hash1 = codec.hashTransitionsWithMetadata(transitions, metadata);
        bytes32 hash2 = codec.hashTransitionsWithMetadata(transitions, metadata);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes32(0), "Hash should not be zero");
    }

    function testFuzz_hashTransitionsWithMetadata_lengthMatters(
        bytes32 proposalHash,
        bytes32 parentTransitionHash,
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        view
    {
        // Create single transition
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: proposalHash,
            parentTransitionHash: parentTransitionHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber, blockHash: blockHash, stateRoot: stateRoot
            })
        });

        // Single element array
        IInbox.Transition[] memory singleArray = new IInbox.Transition[](1);
        singleArray[0] = transition;

        // Double element array with same element
        IInbox.Transition[] memory doubleArray = new IInbox.Transition[](2);
        doubleArray[0] = transition;
        doubleArray[1] = transition;

        IInbox.TransitionMetadata[] memory singleMetadata = new IInbox.TransitionMetadata[](1);
        singleMetadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(uint160(uint256(proposalHash) % type(uint160).max)),
            actualProver: address(uint160(uint256(parentTransitionHash) % type(uint160).max))
        });

        IInbox.TransitionMetadata[] memory doubleMetadata = new IInbox.TransitionMetadata[](2);
        doubleMetadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(uint160(uint256(proposalHash) % type(uint160).max)),
            actualProver: address(uint160(uint256(parentTransitionHash) % type(uint160).max))
        });
        doubleMetadata[1] = IInbox.TransitionMetadata({
            designatedProver: address(uint160(uint256(blockHash) % type(uint160).max)),
            actualProver: address(uint160(uint256(stateRoot) % type(uint160).max))
        });

        bytes32 singleHash = codec.hashTransitionsWithMetadata(singleArray, singleMetadata);
        bytes32 doubleHash = codec.hashTransitionsWithMetadata(doubleArray, doubleMetadata);

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
        view
    {
        IInbox.TransitionRecord memory record = IInbox.TransitionRecord({
            span: span,
            bondInstructions: new LibBonds.BondInstruction[](0),
            transitionHash: transitionHash,
            checkpointHash: checkpointHash
        });

        bytes26 hash1 = codec.hashTransitionRecord(record);
        bytes26 hash2 = codec.hashTransitionRecord(record);

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
        view
    {
        // Bound bondType to valid enum range (3 types: 0-2: NONE, PROVABILITY, LIVENESS)
        LibBonds.BondType bondType = LibBonds.BondType(bound(bondTypeRaw, 0, 2));

        LibBonds.BondInstruction[] memory bonds = new LibBonds.BondInstruction[](1);
        bonds[0] = LibBonds.BondInstruction({
            proposalId: proposalId, bondType: bondType, payer: payer, payee: receiver
        });

        IInbox.TransitionRecord memory record = IInbox.TransitionRecord({
            span: span,
            bondInstructions: bonds,
            transitionHash: transitionHash,
            checkpointHash: checkpointHash
        });

        bytes26 hash1 = codec.hashTransitionRecord(record);
        bytes26 hash2 = codec.hashTransitionRecord(record);

        // Hash should be deterministic
        assertEq(hash1, hash2, "Hash should be deterministic");

        // Hash should not be zero (extremely unlikely)
        assertTrue(hash1 != bytes26(0), "Hash should not be zero");
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
        view
    {
        // Ensure we have different inputs
        vm.assume(
            blockNumber1 != blockNumber2 || blockHash1 != blockHash2 || stateRoot1 != stateRoot2
        );

        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber1, blockHash: blockHash1, stateRoot: stateRoot1
        });

        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber2, blockHash: blockHash2, stateRoot: stateRoot2
        });

        bytes32 hash1 = codec.hashCheckpoint(checkpoint1);
        bytes32 hash2 = codec.hashCheckpoint(checkpoint2);

        // Should be collision resistant
        assertTrue(hash1 != hash2, "Hash function should be collision resistant");
    }

    function testFuzz_hashConsistency_multipleOperations(
        uint48 proposalId,
        bytes32 parentTransitionHash
    )
        public
        view
    {
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: bytes32(uint256(proposalId)),
            parentTransitionHash: parentTransitionHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: proposalId,
                blockHash: bytes32(uint256(proposalId)),
                stateRoot: parentTransitionHash
            })
        });

        // Test that calling the same function multiple times gives same result
        bytes32 hash1 = codec.hashTransition(transition);
        bytes32 hash2 = codec.hashTransition(transition);
        bytes32 hash3 = codec.hashTransition(transition);

        assertEq(hash1, hash2, "Multiple calls should be consistent");
        assertEq(hash2, hash3, "Multiple calls should be consistent");
        assertEq(hash1, hash3, "Multiple calls should be consistent");
    }

    function testFuzz_differentProposals_DifferentHashes(
        uint48 id1,
        uint48 id2,
        uint48 timestamp,
        address proposer
    )
        public
        view
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

        bytes32 hash1 = codec.hashProposal(proposal1);
        bytes32 hash2 = codec.hashProposal(proposal2);

        assertNotEq(hash1, hash2, "Different proposals should have different hashes");
    }

    function testFuzz_emptyArraysAlwaysHashToSame() public view {
        IInbox.Transition[] memory emptyArray1 = new IInbox.Transition[](0);
        IInbox.Transition[] memory emptyArray2 = new IInbox.Transition[](0);
        IInbox.TransitionMetadata[] memory emptyMetadata1 = new IInbox.TransitionMetadata[](0);
        IInbox.TransitionMetadata[] memory emptyMetadata2 = new IInbox.TransitionMetadata[](0);

        bytes32 hash1 = codec.hashTransitionsWithMetadata(emptyArray1, emptyMetadata1);
        bytes32 hash2 = codec.hashTransitionsWithMetadata(emptyArray2, emptyMetadata2);

        assertEq(hash1, hash2, "Empty arrays should always hash to the same value");
        assertNotEq(hash1, bytes32(0), "Empty arrays should not hash to zero");
    }
}
