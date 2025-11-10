// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title AbstractCodecTest
/// @notice Abstract base test for ICodec implementations
/// @dev This allows sharing test cases between CodecSimple and CodecOptimized
abstract contract AbstractCodecTest is Test {
    ICodec internal codec;

    /// @notice Must be implemented by concrete test contracts to provide the codec instance
    function _getCodec() internal virtual returns (ICodec);

    function setUp() public virtual {
        codec = _getCodec();
    }

    /// @notice Get the name of the codec implementation for test output
    function _getCodecName() internal view virtual returns (string memory);

    // ---------------------------------------------------------------
    // Core Structure Hashing Tests
    // ---------------------------------------------------------------

    function test_hashTransition() public view {
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

        bytes32 hash = codec.hashTransition(testTransition);
        assertNotEq(hash, bytes32(0), "Transition hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = codec.hashTransition(testTransition);
        assertEq(hash, hash2, "Transition hash should be deterministic");
    }

    function test_hashCheckpoint() public view {
        ICheckpointStore.Checkpoint memory testCheckpoint = ICheckpointStore.Checkpoint({
            blockNumber: 12_345,
            blockHash: bytes32(uint256(0xabcd)),
            stateRoot: bytes32(uint256(0xdead))
        });

        bytes32 hash = codec.hashCheckpoint(testCheckpoint);
        assertNotEq(hash, bytes32(0), "Checkpoint hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = codec.hashCheckpoint(testCheckpoint);
        assertEq(hash, hash2, "Checkpoint hash should be deterministic");
    }

    function test_hashCoreState() public view {
        IInbox.CoreState memory testCoreState = IInbox.CoreState({
            nextProposalId: 100,
            lastProposalBlockId: 199,
            lastFinalizedProposalId: 99,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: bytes32(uint256(0x3333)),
            bondInstructionsHash: bytes32(uint256(0x4444))
        });

        bytes32 hash = codec.hashCoreState(testCoreState);
        assertNotEq(hash, bytes32(0), "CoreState hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = codec.hashCoreState(testCoreState);
        assertEq(hash, hash2, "CoreState hash should be deterministic");
    }

    function test_hashProposal() public view {
        IInbox.Proposal memory testProposal = IInbox.Proposal({
            id: 42,
            timestamp: 1_000_000,
            endOfSubmissionWindowTimestamp: 2_000_000,
            proposer: address(0x1234567890AbcdEF1234567890aBcdef12345678),
            coreStateHash: bytes32(uint256(0x5555)),
            derivationHash: bytes32(uint256(0x6666))
        });

        bytes32 hash = codec.hashProposal(testProposal);
        assertNotEq(hash, bytes32(0), "Proposal hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = codec.hashProposal(testProposal);
        assertEq(hash, hash2, "Proposal hash should be deterministic");
    }

    function test_hashDerivation() public view {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](2);

        bytes32[] memory blobHashes1 = new bytes32[](1);
        blobHashes1[0] = bytes32(uint256(0x7777));
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes1, offset: 100, timestamp: 3_000_000
            })
        });

        bytes32[] memory blobHashes2 = new bytes32[](2);
        blobHashes2[0] = bytes32(uint256(0x8888));
        blobHashes2[1] = bytes32(uint256(0x9999));
        sources[1] = IInbox.DerivationSource({
            isForcedInclusion: true,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes2, offset: 200, timestamp: 4_000_000
            })
        });

        IInbox.Derivation memory testDerivation = IInbox.Derivation({
            originBlockNumber: 50_000,
            originBlockHash: bytes32(uint256(0xaaaa)),
            basefeeSharingPctg: 10,
            sources: sources
        });

        bytes32 hash = codec.hashDerivation(testDerivation);
        assertNotEq(hash, bytes32(0), "Derivation hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = codec.hashDerivation(testDerivation);
        assertEq(hash, hash2, "Derivation hash should be deterministic");
    }

    function test_hashDerivation_EmptySources() public view {
        IInbox.Derivation memory emptyDerivation = IInbox.Derivation({
            originBlockNumber: 1000,
            originBlockHash: bytes32(uint256(0xfeed)),
            basefeeSharingPctg: 5,
            sources: new IInbox.DerivationSource[](0)
        });

        bytes32 hash = codec.hashDerivation(emptyDerivation);
        assertNotEq(hash, bytes32(0), "Empty derivation hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Array Hashing Tests
    // ---------------------------------------------------------------

    function test_hashTransitionsWithMetadata() public view {
        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: 12_345,
            blockHash: bytes32(uint256(0xabcd)),
            stateRoot: bytes32(uint256(0xdead))
        });

        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: 23_456,
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

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](3);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(0x1111), actualProver: address(0x1111)
        });
        metadata[1] = IInbox.TransitionMetadata({
            designatedProver: address(0x2222), actualProver: address(0x2222)
        });
        metadata[2] = IInbox.TransitionMetadata({
            designatedProver: address(0x3333), actualProver: address(0x3333)
        });
        bytes32 hash = codec.hashTransitionsWithMetadata(transitions, metadata);
        assertNotEq(hash, bytes32(0), "Transitions array hash should not be zero");

        // Verify deterministic hashing
        bytes32 hash2 = codec.hashTransitionsWithMetadata(transitions, metadata);
        assertEq(hash, hash2, "Transitions array hash should be deterministic");
    }

    function test_hashTransitionsWithMetadata_Empty() public view {
        IInbox.Transition[] memory emptyArray = new IInbox.Transition[](0);
        IInbox.TransitionMetadata[] memory emptyMetadata = new IInbox.TransitionMetadata[](0);
        bytes32 hash = codec.hashTransitionsWithMetadata(emptyArray, emptyMetadata);

        // Empty array should hash consistently
        bytes32 hash2 = codec.hashTransitionsWithMetadata(emptyArray, emptyMetadata);
        assertEq(hash, hash2, "Empty transitions array should hash consistently");

        // Should not be zero
        assertNotEq(hash, bytes32(0), "Empty transitions array hash should not be zero");
    }

    function test_hashTransitionsArray_Single() public view {
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

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(0x1111), actualProver: address(0x1111)
        });
        bytes32 hash = codec.hashTransitionsWithMetadata(singleArray, metadata);
        assertNotEq(hash, bytes32(0), "Single transition array should not be zero");
    }

    function test_hashTransitionsArray_Two() public view {
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

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](2);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(0x1111), actualProver: address(0x1111)
        });
        metadata[1] = IInbox.TransitionMetadata({
            designatedProver: address(0x2222), actualProver: address(0x2222)
        });
        bytes32 hash = codec.hashTransitionsWithMetadata(twoArray, metadata);
        assertNotEq(hash, bytes32(0), "Two transitions array should not be zero");
    }

    function test_hashTransitionRecord() public view {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](2);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 10,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111111111111111111111111111111111111111),
            payee: address(0x2222222222222222222222222222222222222222)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 11,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333333333333333333333333333333333333333),
            payee: address(0x4444444444444444444444444444444444444444)
        });

        IInbox.TransitionRecord memory testTransitionRecord = IInbox.TransitionRecord({
            span: 5,
            transitionHash: bytes32(uint256(0xbbbb)),
            checkpointHash: bytes32(uint256(0xcccc)),
            bondInstructions: bondInstructions
        });

        bytes26 hash = codec.hashTransitionRecord(testTransitionRecord);
        assertNotEq(hash, bytes26(0), "TransitionRecord hash should not be zero");

        // Verify deterministic hashing
        bytes26 hash2 = codec.hashTransitionRecord(testTransitionRecord);
        assertEq(hash, hash2, "TransitionRecord hash should be deterministic");
    }

    function test_hashTransitionRecord_EmptyBondInstructions() public view {
        IInbox.TransitionRecord memory emptyRecord = IInbox.TransitionRecord({
            span: 10,
            transitionHash: bytes32(uint256(0x1234)),
            checkpointHash: bytes32(uint256(0x5678)),
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        bytes26 hash = codec.hashTransitionRecord(emptyRecord);
        assertNotEq(hash, bytes26(0), "Empty TransitionRecord hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Collision Resistance Tests
    // ---------------------------------------------------------------

    function test_hashCollisionResistance_DifferentProposals() public view {
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

        bytes32 hash1 = codec.hashProposal(proposal1);
        bytes32 hash2 = codec.hashProposal(proposal2);

        assertNotEq(hash1, hash2, "Different proposals should have different hashes");
    }

    function test_hashCollisionResistance_ArrayLengths() public view {
        // Test that arrays of different lengths produce different hashes
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 12_345,
            blockHash: bytes32(uint256(0xabcd)),
            stateRoot: bytes32(uint256(0xdead))
        });

        IInbox.Transition[] memory array1 = new IInbox.Transition[](1);
        array1[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(0x1234)),
            parentTransitionHash: bytes32(uint256(0x5678)),
            checkpoint: checkpoint
        });

        IInbox.Transition[] memory array2 = new IInbox.Transition[](2);
        array2[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(0x1234)),
            parentTransitionHash: bytes32(uint256(0x5678)),
            checkpoint: checkpoint
        });
        array2[1] = IInbox.Transition({
            proposalHash: bytes32(uint256(0x0)),
            parentTransitionHash: bytes32(uint256(0x0)),
            checkpoint: checkpoint
        });

        IInbox.TransitionMetadata[] memory metadata1 = new IInbox.TransitionMetadata[](1);
        metadata1[0] = IInbox.TransitionMetadata({
            designatedProver: address(0x1111), actualProver: address(0x1111)
        });

        IInbox.TransitionMetadata[] memory metadata2 = new IInbox.TransitionMetadata[](2);
        metadata2[0] = IInbox.TransitionMetadata({
            designatedProver: address(0x1111), actualProver: address(0x1111)
        });
        metadata2[1] = IInbox.TransitionMetadata({
            designatedProver: address(0x2222), actualProver: address(0x2222)
        });

        bytes32 hash1 = codec.hashTransitionsWithMetadata(array1, metadata1);
        bytes32 hash2 = codec.hashTransitionsWithMetadata(array2, metadata2);

        assertNotEq(hash1, hash2, "Arrays with different lengths should have different hashes");
    }

    function test_decodeProveInput_RoundTrip() public view {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 42,
            timestamp: 1_234_567,
            endOfSubmissionWindowTimestamp: 1_234_777,
            proposer: address(0xBEEF),
            coreStateHash: bytes32(uint256(0x1111)),
            derivationHash: bytes32(uint256(0x2222))
        });

        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 9999,
            blockHash: bytes32(uint256(0x3333)),
            stateRoot: bytes32(uint256(0x4444))
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(0x5555)),
            parentTransitionHash: bytes32(uint256(0x6666)),
            checkpoint: checkpoint
        });

        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(0xCAFE), actualProver: address(0xC0FFEE)
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        bytes memory encoded = codec.encodeProveInput(proveInput);
        IInbox.ProveInput memory decoded = codec.decodeProveInput(encoded);

        assertEq(decoded.proposals.length, 1);
        assertEq(decoded.transitions.length, 1);
        assertEq(decoded.metadata.length, 1);

        assertEq(decoded.proposals[0].id, proposals[0].id);
        assertEq(decoded.proposals[0].timestamp, proposals[0].timestamp);
        assertEq(
            decoded.proposals[0].endOfSubmissionWindowTimestamp,
            proposals[0].endOfSubmissionWindowTimestamp
        );
        assertEq(decoded.proposals[0].proposer, proposals[0].proposer);
        assertEq(decoded.proposals[0].coreStateHash, proposals[0].coreStateHash);
        assertEq(decoded.proposals[0].derivationHash, proposals[0].derivationHash);

        assertEq(decoded.transitions[0].proposalHash, transitions[0].proposalHash);
        assertEq(decoded.transitions[0].parentTransitionHash, transitions[0].parentTransitionHash);
        assertEq(decoded.transitions[0].checkpoint.blockNumber, checkpoint.blockNumber);
        assertEq(decoded.transitions[0].checkpoint.blockHash, checkpoint.blockHash);
        assertEq(decoded.transitions[0].checkpoint.stateRoot, checkpoint.stateRoot);

        assertEq(decoded.metadata[0].designatedProver, metadata[0].designatedProver);
        assertEq(decoded.metadata[0].actualProver, metadata[0].actualProver);
    }
}
