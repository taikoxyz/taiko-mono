// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibHashing } from "src/layer1/shasta/libs/LibHashing.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { LibBonds } from "src/shared/shasta/libs/LibBonds.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";

contract LibHashingTest is Test {
    function test_hashTransition() public {
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: bytes32(uint256(1)),
            parentTransitionHash: bytes32(uint256(2)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 100,
                blockHash: bytes32(uint256(3)),
                stateRoot: bytes32(uint256(4))
            })
        });

        bytes32 hash = LibHashing.hashTransition(transition);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");

        // Test consistency - same input should give same hash
        bytes32 hash2 = LibHashing.hashTransition(transition);
        assertEq(hash, hash2, "Hash should be deterministic");
    }

    function test_hashCheckpoint() public {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 100,
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2))
        });

        bytes32 hash = LibHashing.hashCheckpoint(checkpoint);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");

        // Test consistency
        bytes32 hash2 = LibHashing.hashCheckpoint(checkpoint);
        assertEq(hash, hash2, "Hash should be deterministic");
    }

    function test_hashCoreState() public {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            nextProposalBlockId: 2,
            lastFinalizedProposalId: 3,
            lastFinalizedTransitionHash: bytes32(uint256(4)),
            bondInstructionsHash: bytes32(uint256(5))
        });

        bytes32 hash = LibHashing.hashCoreState(coreState);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");

        // Test consistency
        bytes32 hash2 = LibHashing.hashCoreState(coreState);
        assertEq(hash, hash2, "Hash should be deterministic");
    }

    function test_hashProposal() public {
        IInbox.Proposal memory proposal = IInbox.Proposal({
            id: 1,
            timestamp: 123_456,
            endOfSubmissionWindowTimestamp: 234_567,
            proposer: address(0x1234),
            coreStateHash: bytes32(uint256(1)),
            derivationHash: bytes32(uint256(2))
        });

        bytes32 hash = LibHashing.hashProposal(proposal);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");

        // Test consistency
        bytes32 hash2 = LibHashing.hashProposal(proposal);
        assertEq(hash, hash2, "Hash should be deterministic");
    }

    function test_hashDerivation() public {
        // Create a derivation with empty sources
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: 100,
            originBlockHash: bytes32(uint256(1)),
            basefeeSharingPctg: 50,
            sources: new IInbox.DerivationSource[](0)
        });

        bytes32 hash = LibHashing.hashDerivation(derivation);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");

        // Test consistency
        bytes32 hash2 = LibHashing.hashDerivation(derivation);
        assertEq(hash, hash2, "Hash should be deterministic");
    }

    function test_hashDerivationWithSources() public {
        // Create derivation with sources
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);

        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = bytes32(uint256(123));

        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({ blobHashes: blobHashes, offset: 0, timestamp: 123_456 })
        });

        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: 100,
            originBlockHash: bytes32(uint256(1)),
            basefeeSharingPctg: 50,
            sources: sources
        });

        bytes32 hash = LibHashing.hashDerivation(derivation);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");

        // Test consistency
        bytes32 hash2 = LibHashing.hashDerivation(derivation);
        assertEq(hash, hash2, "Hash should be deterministic");
    }

    function test_hashTransitionsArray() public {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);

        transitions[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(1)),
            parentTransitionHash: bytes32(uint256(2)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 100,
                blockHash: bytes32(uint256(3)),
                stateRoot: bytes32(uint256(4))
            })
        });

        transitions[1] = IInbox.Transition({
            proposalHash: bytes32(uint256(5)),
            parentTransitionHash: bytes32(uint256(6)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 200,
                blockHash: bytes32(uint256(7)),
                stateRoot: bytes32(uint256(8))
            })
        });

        bytes32 hash = LibHashing.hashTransitionsArray(transitions);
        assertNotEq(hash, bytes32(0), "Hash should not be zero");

        // Test consistency
        bytes32 hash2 = LibHashing.hashTransitionsArray(transitions);
        assertEq(hash, hash2, "Hash should be deterministic");
    }

    function test_hashTransitionRecord() public {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](1);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1234),
            receiver: address(0x5678)
        });

        IInbox.TransitionRecord memory transitionRecord = IInbox.TransitionRecord({
            span: 1,
            bondInstructions: bondInstructions,
            transitionHash: bytes32(uint256(1)),
            checkpointHash: bytes32(uint256(2))
        });

        bytes26 hash = LibHashing.hashTransitionRecord(transitionRecord);
        assertNotEq(hash, bytes26(0), "Hash should not be zero");

        // Test consistency
        bytes26 hash2 = LibHashing.hashTransitionRecord(transitionRecord);
        assertEq(hash, hash2, "Hash should be deterministic");
    }

    function test_composeTransitionKey() public {
        uint48 proposalId = 123;
        bytes32 parentTransitionHash = bytes32(uint256(456));

        bytes32 key = LibHashing.composeTransitionKey(proposalId, parentTransitionHash);
        assertNotEq(key, bytes32(0), "Key should not be zero");

        // Test consistency
        bytes32 key2 = LibHashing.composeTransitionKey(proposalId, parentTransitionHash);
        assertEq(key, key2, "Key should be deterministic");

        // Different inputs should give different keys
        bytes32 key3 = LibHashing.composeTransitionKey(proposalId + 1, parentTransitionHash);
        assertNotEq(key, key3, "Different inputs should give different keys");
    }
}
