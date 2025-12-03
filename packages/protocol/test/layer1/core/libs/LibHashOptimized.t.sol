// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibHashOptimized } from "src/layer1/core/libs/LibHashOptimized.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibHashOptimizedTest
/// @notice Unit tests for LibHashOptimized hashing functions
/// @custom:security-contact security@taiko.xyz
contract LibHashOptimizedTest is Test {
    // ---------------------------------------------------------------
    // Test hashCheckpoint
    // ---------------------------------------------------------------

    function test_hashCheckpoint_simple() public pure {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 1000, blockHash: bytes32(uint256(111)), stateRoot: bytes32(uint256(222))
        });

        bytes32 hash1 = LibHashOptimized.hashCheckpoint(checkpoint);
        bytes32 hash2 = LibHashOptimized.hashCheckpoint(checkpoint);

        assertEq(hash1, hash2, "Hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero");
    }

    function test_hashCheckpoint_different_inputs() public pure {
        ICheckpointStore.Checkpoint memory checkpoint1 = ICheckpointStore.Checkpoint({
            blockNumber: 1000, blockHash: bytes32(uint256(111)), stateRoot: bytes32(uint256(222))
        });

        ICheckpointStore.Checkpoint memory checkpoint2 = ICheckpointStore.Checkpoint({
            blockNumber: 1001, blockHash: bytes32(uint256(111)), stateRoot: bytes32(uint256(222))
        });

        bytes32 hash1 = LibHashOptimized.hashCheckpoint(checkpoint1);
        bytes32 hash2 = LibHashOptimized.hashCheckpoint(checkpoint2);

        assertNotEq(hash1, hash2, "Different inputs should produce different hashes");
    }

    // ---------------------------------------------------------------
    // Test hashCoreState
    // ---------------------------------------------------------------

    function test_hashCoreState_simple() public pure {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            proposalHead: 10,
            proposalHeadContainerBlock: 999,
            finalizationHead: 9,
            synchronizationHead: 8,
            finalizationHeadTransitionHash: bytes27(uint216(555)),
            aggregatedBondInstructionsHash: bytes32(uint256(666))
        });

        bytes32 hash1 = LibHashOptimized.hashCoreState(coreState);
        bytes32 hash2 = LibHashOptimized.hashCoreState(coreState);

        assertEq(hash1, hash2, "Hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero");
    }

    function test_hashCoreState_different_inputs() public pure {
        IInbox.CoreState memory coreState1 = IInbox.CoreState({
            proposalHead: 10,
            proposalHeadContainerBlock: 999,
            finalizationHead: 9,
            synchronizationHead: 8,
            finalizationHeadTransitionHash: bytes27(uint216(555)),
            aggregatedBondInstructionsHash: bytes32(uint256(666))
        });

        IInbox.CoreState memory coreState2 = IInbox.CoreState({
            proposalHead: 11,
            proposalHeadContainerBlock: 999,
            finalizationHead: 9,
            synchronizationHead: 8,
            finalizationHeadTransitionHash: bytes27(uint216(555)),
            aggregatedBondInstructionsHash: bytes32(uint256(666))
        });

        bytes32 hash1 = LibHashOptimized.hashCoreState(coreState1);
        bytes32 hash2 = LibHashOptimized.hashCoreState(coreState2);

        assertNotEq(hash1, hash2, "Different inputs should produce different hashes");
    }

    // ---------------------------------------------------------------
    // Test hashDerivation
    // ---------------------------------------------------------------

    function test_hashDerivation_emptySources() public pure {
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: 18_000_000,
            basefeeSharingPctg: 50,
            originBlockHash: bytes32(uint256(123)),
            sources: new IInbox.DerivationSource[](0)
        });

        bytes32 hash1 = LibHashOptimized.hashDerivation(derivation);
        bytes32 hash2 = LibHashOptimized.hashDerivation(derivation);

        assertEq(hash1, hash2, "Hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero");
    }

    function test_hashDerivation_withSources() public pure {
        bytes32[] memory blobHashes = new bytes32[](2);
        blobHashes[0] = bytes32(uint256(0x1111));
        blobHashes[1] = bytes32(uint256(0x2222));

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: blobHashes, offset: 100, timestamp: 1_700_000_000
            })
        });

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: 18_000_000,
            basefeeSharingPctg: 50,
            originBlockHash: bytes32(uint256(123)),
            sources: sources
        });

        bytes32 hash1 = LibHashOptimized.hashDerivation(derivation);
        bytes32 hash2 = LibHashOptimized.hashDerivation(derivation);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    function test_hashDerivation_multipleSources() public pure {
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](3);

        for (uint256 i = 0; i < 3; i++) {
            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encodePacked("blob", i));

            sources[i] = IInbox.DerivationSource({
                isForcedInclusion: i % 2 == 0,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: uint24(i * 100),
                    timestamp: uint40(1_700_000_000 + i)
                })
            });
        }

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: 18_000_000,
            basefeeSharingPctg: 50,
            originBlockHash: bytes32(uint256(123)),
            sources: sources
        });

        bytes32 hash = LibHashOptimized.hashDerivation(derivation);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Test hashProposal
    // ---------------------------------------------------------------

    function test_hashProposal_simple() public pure {
        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 100,
            timestamp: 1_700_000_000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            proposer: address(0x1234),
            coreStateHash: bytes32(uint256(111)),
            derivationHash: bytes32(uint256(222)),
            parentProposalHash: bytes32(uint256(333))
        });

        bytes32 hash1 = LibHashOptimized.hashProposal(proposal);
        bytes32 hash2 = LibHashOptimized.hashProposal(proposal);

        assertEq(hash1, hash2, "Hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero");
    }

    function test_hashProposal_different_inputs() public pure {
        IInbox.Proposal memory proposal1 = IInbox.Proposal({
            id: 100,
            timestamp: 1_700_000_000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            proposer: address(0x1234),
            coreStateHash: bytes32(uint256(111)),
            derivationHash: bytes32(uint256(222)),
            parentProposalHash: bytes32(uint256(333))
        });

        IInbox.Proposal memory proposal2 = IInbox.Proposal({
            id: 101,
            timestamp: 1_700_000_000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            proposer: address(0x1234),
            coreStateHash: bytes32(uint256(111)),
            derivationHash: bytes32(uint256(222)),
            parentProposalHash: bytes32(uint256(333))
        });

        bytes32 hash1 = LibHashOptimized.hashProposal(proposal1);
        bytes32 hash2 = LibHashOptimized.hashProposal(proposal2);

        assertNotEq(hash1, hash2, "Different inputs should produce different hashes");
    }

    // ---------------------------------------------------------------
    // Test hashTransition
    // ---------------------------------------------------------------

    function test_hashTransition_simple() public pure {
        IInbox.Transition memory transition = IInbox.Transition({
            bondInstructionHash: bytes32(uint256(111)), checkpointHash: bytes32(uint256(222))
        });

        bytes27 hash1 = LibHashOptimized.hashTransition(transition);
        bytes27 hash2 = LibHashOptimized.hashTransition(transition);

        assertEq(hash1, hash2, "Hash should be deterministic");
        assertNotEq(hash1, bytes27(0), "Hash should not be zero");
    }

    function test_hashTransition_truncatedTo27Bytes() public pure {
        IInbox.Transition memory transition = IInbox.Transition({
            bondInstructionHash: bytes32(type(uint256).max),
            checkpointHash: bytes32(type(uint256).max)
        });

        bytes27 hash = LibHashOptimized.hashTransition(transition);
        // The hash should be truncated to 27 bytes
        assertNotEq(hash, bytes27(0), "Truncated hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Test hashBondInstruction
    // ---------------------------------------------------------------

    function test_hashBondInstruction_simple() public pure {
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: 100,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        bytes32 hash1 = LibHashOptimized.hashBondInstruction(instruction);
        bytes32 hash2 = LibHashOptimized.hashBondInstruction(instruction);

        assertEq(hash1, hash2, "Hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero");
    }

    function test_hashBondInstruction_allBondTypes() public pure {
        LibBonds.BondInstruction memory instructionNone = LibBonds.BondInstruction({
            proposalId: 100,
            bondType: LibBonds.BondType.NONE,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        LibBonds.BondInstruction memory instructionProvability = LibBonds.BondInstruction({
            proposalId: 100,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        LibBonds.BondInstruction memory instructionLiveness = LibBonds.BondInstruction({
            proposalId: 100,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        bytes32 hashNone = LibHashOptimized.hashBondInstruction(instructionNone);
        bytes32 hashProvability = LibHashOptimized.hashBondInstruction(instructionProvability);
        bytes32 hashLiveness = LibHashOptimized.hashBondInstruction(instructionLiveness);

        assertNotEq(
            hashNone, hashProvability, "Different bond types should produce different hashes"
        );
        assertNotEq(
            hashProvability, hashLiveness, "Different bond types should produce different hashes"
        );
    }

    // ---------------------------------------------------------------
    // Test hashBondInstructionMessage
    // ---------------------------------------------------------------

    function test_hashBondInstructionMessage_simple() public pure {
        IInbox.BondInstructionMessage memory message = IInbox.BondInstructionMessage({
            firstProposalId: 100,
            lastProposalId: 110,
            aggregatedBondInstructionsHash: bytes32(uint256(777))
        });

        bytes32 hash1 = LibHashOptimized.hashBondInstructionMessage(message);
        bytes32 hash2 = LibHashOptimized.hashBondInstructionMessage(message);

        assertEq(hash1, hash2, "Hash should be deterministic");
        assertNotEq(hash1, bytes32(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Test hashAggregatedBondInstructionsHash
    // ---------------------------------------------------------------

    function test_hashAggregatedBondInstructionsHash_simple() public pure {
        bytes32 aggregatedHash = bytes32(uint256(111));
        bytes32 newInstructionHash = bytes32(uint256(222));

        bytes32 result = LibHashOptimized.hashAggregatedBondInstructionsHash(
            aggregatedHash, newInstructionHash
        );

        assertNotEq(result, bytes32(0), "Result should not be zero");
        assertNotEq(result, aggregatedHash, "Result should differ from input");
    }

    function test_hashAggregatedBondInstructionsHash_chaining() public pure {
        bytes32 initialHash = bytes32(0);
        bytes32 hash1 = bytes32(uint256(111));
        bytes32 hash2 = bytes32(uint256(222));
        bytes32 hash3 = bytes32(uint256(333));

        bytes32 result1 = LibHashOptimized.hashAggregatedBondInstructionsHash(initialHash, hash1);
        bytes32 result2 = LibHashOptimized.hashAggregatedBondInstructionsHash(result1, hash2);
        bytes32 result3 = LibHashOptimized.hashAggregatedBondInstructionsHash(result2, hash3);

        // Each aggregation should produce different results
        assertNotEq(result1, result2);
        assertNotEq(result2, result3);
    }

    // ---------------------------------------------------------------
    // Test hashBlobHashesArray
    // ---------------------------------------------------------------

    function test_hashBlobHashesArray_empty() public pure {
        bytes32[] memory blobHashes = new bytes32[](0);
        bytes32 hash = LibHashOptimized.hashBlobHashesArray(blobHashes);

        // Should return EMPTY_BYTES_HASH
        assertEq(hash, keccak256(""), "Empty array should return keccak256(\"\")");
    }

    function test_hashBlobHashesArray_single() public pure {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = bytes32(uint256(0x1111));

        bytes32 hash1 = LibHashOptimized.hashBlobHashesArray(blobHashes);
        bytes32 hash2 = LibHashOptimized.hashBlobHashesArray(blobHashes);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    function test_hashBlobHashesArray_multiple() public pure {
        bytes32[] memory blobHashes = new bytes32[](3);
        blobHashes[0] = bytes32(uint256(0x1111));
        blobHashes[1] = bytes32(uint256(0x2222));
        blobHashes[2] = bytes32(uint256(0x3333));

        bytes32 hash = LibHashOptimized.hashBlobHashesArray(blobHashes);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Test hashProveInputArray
    // ---------------------------------------------------------------

    function test_hashProveInputArray_empty() public pure {
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](0);
        bytes32 hash = LibHashOptimized.hashProveInputArray(inputs);

        // Should return EMPTY_BYTES_HASH
        assertEq(hash, keccak256(""), "Empty array should return keccak256(\"\")");
    }

    function test_hashProveInputArray_single() public pure {
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);
        inputs[0] = IInbox.ProveInput({
            proposal: IInbox.Proposal({
                id: 100,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 5000,
                blockHash: bytes32(uint256(444)),
                stateRoot: bytes32(uint256(555))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0xAAAA), actualProver: address(0xBBBB)
            }),
            parentTransitionHash: bytes27(uint216(666))
        });

        bytes32 hash1 = LibHashOptimized.hashProveInputArray(inputs);
        bytes32 hash2 = LibHashOptimized.hashProveInputArray(inputs);

        assertEq(hash1, hash2, "Hash should be deterministic");
    }

    function test_hashProveInputArray_multiple() public pure {
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](3);

        for (uint256 i = 0; i < 3; i++) {
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
                    blockNumber: uint40(5000 + i),
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
        assertNotEq(hash, bytes32(0), "Hash should not be zero");
    }

    // ---------------------------------------------------------------
    // Test composeTransitionKey
    // ---------------------------------------------------------------

    function test_composeTransitionKey_simple() public pure {
        uint40 proposalId = 100;
        bytes27 parentTransitionHash = bytes27(uint216(555));

        bytes32 key1 = LibHashOptimized.composeTransitionKey(proposalId, parentTransitionHash);
        bytes32 key2 = LibHashOptimized.composeTransitionKey(proposalId, parentTransitionHash);

        assertEq(key1, key2, "Key should be deterministic");
        assertNotEq(key1, bytes32(0), "Key should not be zero");
    }

    function test_composeTransitionKey_different_inputs() public pure {
        bytes32 key1 = LibHashOptimized.composeTransitionKey(100, bytes27(uint216(555)));
        bytes32 key2 = LibHashOptimized.composeTransitionKey(101, bytes27(uint216(555)));
        bytes32 key3 = LibHashOptimized.composeTransitionKey(100, bytes27(uint216(556)));

        assertNotEq(key1, key2, "Different proposalId should produce different keys");
        assertNotEq(key1, key3, "Different parentTransitionHash should produce different keys");
    }
}
