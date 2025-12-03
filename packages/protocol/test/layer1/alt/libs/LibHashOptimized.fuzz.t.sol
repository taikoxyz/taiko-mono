// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/alt/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/alt/libs/LibBlobs.sol";
import { LibHashOptimized } from "src/layer1/alt/libs/LibHashOptimized.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibHashOptimizedFuzzTest
/// @notice Fuzz tests for LibHashOptimized hashing functions
/// @custom:security-contact security@taiko.xyz
contract LibHashOptimizedFuzzTest is Test {
    // ---------------------------------------------------------------
    // Fuzz tests for hashCheckpoint
    // ---------------------------------------------------------------

    function testFuzz_hashCheckpoint_deterministic(
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        pure
    {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber, blockHash: blockHash, stateRoot: stateRoot
        });

        bytes32 hash1 = LibHashOptimized.hashCheckpoint(checkpoint);
        bytes32 hash2 = LibHashOptimized.hashCheckpoint(checkpoint);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    function testFuzz_hashCheckpoint_collision_resistant(
        uint48 blockNumber1,
        uint48 blockNumber2,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        pure
    {
        vm.assume(blockNumber1 != blockNumber2);

        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber1, blockHash: blockHash, stateRoot: stateRoot
        });

        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: blockNumber2, blockHash: blockHash, stateRoot: stateRoot
        });

        bytes32 hash1 = LibHashOptimized.hashCheckpoint(checkpoint1);
        bytes32 hash2 = LibHashOptimized.hashCheckpoint(checkpoint2);

        assertNotEq(hash1, hash2, "Different inputs should produce different hashes");
    }

    // ---------------------------------------------------------------
    // Fuzz tests for hashCoreState
    // ---------------------------------------------------------------

    function testFuzz_hashCoreState_deterministic(
        uint40 proposalHead,
        uint40 proposalHeadContainerBlock,
        uint40 finalizationHead,
        uint40 synchronizationHead,
        bytes27 finalizationHeadTransitionHash,
        bytes32 aggregatedBondInstructionsHash
    )
        public
        pure
    {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            proposalHead: proposalHead,
            proposalHeadContainerBlock: proposalHeadContainerBlock,
            finalizationHead: finalizationHead,
            synchronizationHead: synchronizationHead,
            finalizationHeadTransitionHash: finalizationHeadTransitionHash,
            aggregatedBondInstructionsHash: aggregatedBondInstructionsHash
        });

        bytes32 hash1 = LibHashOptimized.hashCoreState(coreState);
        bytes32 hash2 = LibHashOptimized.hashCoreState(coreState);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    function testFuzz_hashCoreState_collision_resistant(
        uint40 proposalHead1,
        uint40 proposalHead2,
        uint40 finalizationHead,
        bytes27 finalizationHeadTransitionHash
    )
        public
        pure
    {
        vm.assume(proposalHead1 != proposalHead2);

        IInbox.CoreState memory coreState1 = IInbox.CoreState({
            proposalHead: proposalHead1,
            proposalHeadContainerBlock: 999,
            finalizationHead: finalizationHead,
            synchronizationHead: 0,
            finalizationHeadTransitionHash: finalizationHeadTransitionHash,
            aggregatedBondInstructionsHash: bytes32(0)
        });

        IInbox.CoreState memory coreState2 = IInbox.CoreState({
            proposalHead: proposalHead2,
            proposalHeadContainerBlock: 999,
            finalizationHead: finalizationHead,
            synchronizationHead: 0,
            finalizationHeadTransitionHash: finalizationHeadTransitionHash,
            aggregatedBondInstructionsHash: bytes32(0)
        });

        bytes32 hash1 = LibHashOptimized.hashCoreState(coreState1);
        bytes32 hash2 = LibHashOptimized.hashCoreState(coreState2);

        assertNotEq(hash1, hash2, "Different inputs should produce different hashes");
    }

    // ---------------------------------------------------------------
    // Fuzz tests for hashDerivation
    // ---------------------------------------------------------------

    function testFuzz_hashDerivation_deterministic(
        uint40 originBlockNumber,
        uint8 basefeeSharingPctg,
        bytes32 originBlockHash
    )
        public
        pure
    {
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: originBlockNumber,
            basefeeSharingPctg: basefeeSharingPctg,
            originBlockHash: originBlockHash,
            sources: new IInbox.DerivationSource[](0)
        });

        bytes32 hash1 = LibHashOptimized.hashDerivation(derivation);
        bytes32 hash2 = LibHashOptimized.hashDerivation(derivation);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    function testFuzz_hashDerivation_withSources(
        uint40 originBlockNumber,
        uint24 offset,
        uint40 timestamp,
        bool isForcedInclusion
    )
        public
        pure
    {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encodePacked("blob", originBlockNumber));

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: isForcedInclusion,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes, offset: offset, timestamp: timestamp
            })
        });

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: originBlockNumber,
            basefeeSharingPctg: 50,
            originBlockHash: keccak256(abi.encodePacked("originBlock")),
            sources: sources
        });

        bytes32 hash1 = LibHashOptimized.hashDerivation(derivation);
        bytes32 hash2 = LibHashOptimized.hashDerivation(derivation);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    // ---------------------------------------------------------------
    // Fuzz tests for hashProposal
    // ---------------------------------------------------------------

    function testFuzz_hashProposal_deterministic(
        uint40 id,
        uint40 timestamp,
        uint40 endOfSubmissionWindowTimestamp,
        address proposer,
        bytes32 coreStateHash,
        bytes32 derivationHash,
        bytes32 parentProposalHash
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
            derivationHash: derivationHash,
            parentProposalHash: parentProposalHash
        });

        bytes32 hash1 = LibHashOptimized.hashProposal(proposal);
        bytes32 hash2 = LibHashOptimized.hashProposal(proposal);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    function testFuzz_hashProposal_collision_resistant(
        uint40 id1,
        uint40 id2,
        address proposer,
        bytes32 coreStateHash
    )
        public
        pure
    {
        vm.assume(id1 != id2);

        IInbox.Proposal memory proposal1 = IInbox.Proposal({
            id: id1,
            timestamp: 1_700_000_000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            proposer: proposer,
            coreStateHash: coreStateHash,
            derivationHash: bytes32(0),
            parentProposalHash: bytes32(0)
        });

        IInbox.Proposal memory proposal2 = IInbox.Proposal({
            id: id2,
            timestamp: 1_700_000_000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            proposer: proposer,
            coreStateHash: coreStateHash,
            derivationHash: bytes32(0),
            parentProposalHash: bytes32(0)
        });

        bytes32 hash1 = LibHashOptimized.hashProposal(proposal1);
        bytes32 hash2 = LibHashOptimized.hashProposal(proposal2);

        assertNotEq(hash1, hash2, "Different IDs should produce different hashes");
    }

    // ---------------------------------------------------------------
    // Fuzz tests for hashTransition
    // ---------------------------------------------------------------

    function testFuzz_hashTransition_deterministic(
        bytes32 bondInstructionHash,
        bytes32 checkpointHash
    )
        public
        pure
    {
        IInbox.Transition memory transition = IInbox.Transition({
            bondInstructionHash: bondInstructionHash, checkpointHash: checkpointHash
        });

        bytes27 hash1 = LibHashOptimized.hashTransition(transition);
        bytes27 hash2 = LibHashOptimized.hashTransition(transition);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    function testFuzz_hashTransition_collision_resistant(
        bytes32 bondInstructionHash1,
        bytes32 bondInstructionHash2,
        bytes32 checkpointHash
    )
        public
        pure
    {
        vm.assume(bondInstructionHash1 != bondInstructionHash2);

        IInbox.Transition memory transition1 = IInbox.Transition({
            bondInstructionHash: bondInstructionHash1, checkpointHash: checkpointHash
        });

        IInbox.Transition memory transition2 = IInbox.Transition({
            bondInstructionHash: bondInstructionHash2, checkpointHash: checkpointHash
        });

        bytes27 hash1 = LibHashOptimized.hashTransition(transition1);
        bytes27 hash2 = LibHashOptimized.hashTransition(transition2);

        assertNotEq(hash1, hash2, "Different inputs should produce different hashes");
    }

    // ---------------------------------------------------------------
    // Fuzz tests for hashBondInstruction
    // ---------------------------------------------------------------

    function testFuzz_hashBondInstruction_deterministic(
        uint48 proposalId,
        uint8 bondTypeRaw,
        address payer,
        address payee
    )
        public
        pure
    {
        bondTypeRaw = uint8(bound(bondTypeRaw, 0, 2));
        LibBonds.BondType bondType = LibBonds.BondType(bondTypeRaw);

        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposalId, bondType: bondType, payer: payer, payee: payee
        });

        bytes32 hash1 = LibHashOptimized.hashBondInstruction(instruction);
        bytes32 hash2 = LibHashOptimized.hashBondInstruction(instruction);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    // ---------------------------------------------------------------
    // Fuzz tests for hashBondInstructionMessage
    // ---------------------------------------------------------------

    function testFuzz_hashBondInstructionMessage_deterministic(
        uint40 startProposalId,
        uint40 endProposalId,
        bytes32 aggregatedBondInstructionsHash
    )
        public
        pure
    {
        IInbox.BondInstructionMessage memory message = IInbox.BondInstructionMessage({
            startProposalId: startProposalId,
            endProposalId: endProposalId,
            aggregatedBondInstructionsHash: aggregatedBondInstructionsHash
        });

        bytes32 hash1 = LibHashOptimized.hashBondInstructionMessage(message);
        bytes32 hash2 = LibHashOptimized.hashBondInstructionMessage(message);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    // ---------------------------------------------------------------
    // Fuzz tests for hashAggregatedBondInstructionsHash
    // ---------------------------------------------------------------

    function testFuzz_hashAggregatedBondInstructionsHash_deterministic(
        bytes32 aggregatedBondInstructionsHash,
        bytes32 bondInstructionHash
    )
        public
        pure
    {
        bytes32 result1 = LibHashOptimized.hashAggregatedBondInstructionsHash(
            aggregatedBondInstructionsHash, bondInstructionHash
        );
        bytes32 result2 = LibHashOptimized.hashAggregatedBondInstructionsHash(
            aggregatedBondInstructionsHash, bondInstructionHash
        );

        assertEq(result1, result2, "Hash should be deterministic");
    }

    function testFuzz_hashAggregatedBondInstructionsHash_chaining(
        bytes32 hash1,
        bytes32 hash2,
        bytes32 hash3
    )
        public
        pure
    {
        bytes32 result1 = LibHashOptimized.hashAggregatedBondInstructionsHash(bytes32(0), hash1);
        bytes32 result2 = LibHashOptimized.hashAggregatedBondInstructionsHash(result1, hash2);
        bytes32 result3 = LibHashOptimized.hashAggregatedBondInstructionsHash(result2, hash3);

        // Each aggregation step should produce different results if inputs differ
        if (hash1 != hash2) {
            assertNotEq(result1, result2);
        }
        if (hash2 != hash3) {
            assertNotEq(result2, result3);
        }
    }

    // ---------------------------------------------------------------
    // Fuzz tests for hashBlobHashesArray
    // ---------------------------------------------------------------

    function testFuzz_hashBlobHashesArray_deterministic(
        bytes32 hash1,
        bytes32 hash2
    )
        public
        pure
    {
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = hash1;
        blobHashes[1] = hash2;

        bytes32 result1 = LibHashOptimized.hashBlobHashesArray(blobHashes);
        bytes32 result2 = LibHashOptimized.hashBlobHashesArray(blobHashes);

        assertEq(result1, result2, "Hash should be deterministic");
    }

    function testFuzz_hashBlobHashesArray_variableLength(uint8 length) public pure {
        length = uint8(bound(length, 0, 10));

        bytes32[] memory blobHashes = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            blobHashes[i] = keccak256(abi.encodePacked("blob", i));
        }

        bytes32 hash = LibHashOptimized.hashBlobHashesArray(blobHashes);

        // Just verify it doesn't revert and produces non-zero output for non-empty arrays
        if (length > 0) {
            assertNotEq(hash, bytes32(0), "Hash should not be zero for non-empty arrays");
        }
    }

    // ---------------------------------------------------------------
    // Fuzz tests for hashProveInputArray
    // ---------------------------------------------------------------

    function testFuzz_hashProveInputArray_variableLength(uint8 length) public pure {
        length = uint8(bound(length, 0, 5));

        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](length);
        for (uint256 i = 0; i < length; i++) {
            inputs[i] = IInbox.ProveInput({
                proposal: IInbox.Proposal({
                    id: uint40(100 + i),
                    timestamp: uint40(1_700_000_000 + i),
                    endOfSubmissionWindowTimestamp: uint40(1_700_000_012 + i),
                    proposer: address(uint160(0x1000 + i)),
                    coreStateHash: keccak256(abi.encodePacked("coreState", i)),
                    derivationHash: keccak256(abi.encodePacked("derivation", i)),
                    parentProposalHash: keccak256(abi.encodePacked("parentProposal", i))
                }),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: uint48(5000 + i),
                    blockHash: keccak256(abi.encodePacked("blockHash", i)),
                    stateRoot: keccak256(abi.encodePacked("stateRoot", i))
                }),
                metadata: IInbox.TransitionMetadata({
                    designatedProver: address(uint160(0xAAAA + i)),
                    actualProver: address(uint160(0xBBBB + i))
                }),
                parentTransitionHash: bytes27(keccak256(abi.encodePacked("parentTransition", i)))
            });
        }

        bytes32 hash = LibHashOptimized.hashProveInputArray(inputs);

        // Just verify it doesn't revert and produces non-zero output for non-empty arrays
        if (length > 0) {
            assertNotEq(hash, bytes32(0), "Hash should not be zero for non-empty arrays");
        }
    }

    // ---------------------------------------------------------------
    // Fuzz tests for composeTransitionKey
    // ---------------------------------------------------------------

    function testFuzz_composeTransitionKey_deterministic(
        uint40 proposalId,
        bytes27 parentTransitionHash
    )
        public
        pure
    {
        bytes32 key1 = LibHashOptimized.composeTransitionKey(proposalId, parentTransitionHash);
        bytes32 key2 = LibHashOptimized.composeTransitionKey(proposalId, parentTransitionHash);

        assertEq(key1, key2, "Key should be deterministic");
    }

    function testFuzz_composeTransitionKey_collision_resistant(
        uint40 proposalId1,
        uint40 proposalId2,
        bytes27 parentTransitionHash
    )
        public
        pure
    {
        vm.assume(proposalId1 != proposalId2);

        bytes32 key1 = LibHashOptimized.composeTransitionKey(proposalId1, parentTransitionHash);
        bytes32 key2 = LibHashOptimized.composeTransitionKey(proposalId2, parentTransitionHash);

        assertNotEq(key1, key2, "Different proposalIds should produce different keys");
    }
}
