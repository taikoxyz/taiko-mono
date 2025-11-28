// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { AbstractProveTest } from "./AbstractProve.t.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title InboxOptimized1AggregatedProvingHashBugFixTest
/// @notice Tests verifying the fix for the input mutation bug in InboxOptimized1
/// @dev The bug: _setAggregatedTransitionRecordHashAndDeadline mutated input.transitions[_firstIndex].checkpoint
///      BEFORE _hashTransitionsWithMetadata was called, causing hash mismatch between prover and contract.
///      The fix: compute aggregatedProvingHash BEFORE calling _buildAndSaveTransitionRecords.
contract InboxOptimized1AggregatedProvingHashBugFixTest is AbstractProveTest {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }

    function _getExpectedAggregationBehavior(
        uint256 proposalCount,
        bool consecutive
    )
        internal
        pure
        override
        returns (uint256 expectedEvents, uint256 expectedMaxSpan)
    {
        if (consecutive) {
            return (1, proposalCount);
        } else {
            return (proposalCount, 1);
        }
    }

    /// @notice Verifies prove() succeeds with 3 consecutive proposals using distinct checkpoints
    /// @dev Before the fix, this would cause hash mismatch because:
    ///      1. Contract mutated transitions[0].checkpoint during aggregation
    ///      2. Then computed hash with mutated data
    ///      3. Prover's hash (using original data) wouldn't match
    ///      After the fix, hash is computed BEFORE any mutation.
    function test_prove_consecutiveProposals_withDistinctCheckpoints() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(3);

        // Build transitions with DISTINCT checkpoints for each proposal
        // This is critical - if all checkpoints were identical, the mutation wouldn't matter
        IInbox.Transition[] memory transitions = new IInbox.Transition[](3);
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](3);

        bytes32 parentHash = _getGenesisTransitionHash();

        for (uint256 i = 0; i < 3; i++) {
            transitions[i] = IInbox.Transition({
                proposalHash: _codec().hashProposal(proposals[i]),
                parentTransitionHash: parentHash,
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: uint48(1000 + i * 100), // Different: 1000, 1100, 1200
                    blockHash: bytes32(uint256(0xaaaa + i)),
                    stateRoot: bytes32(uint256(0xbbbb + i))
                })
            });
            metadata[i] = _createMetadataForTransition(Alice, Alice);
            parentHash = keccak256(abi.encode(transitions[i]));
        }

        // Verify checkpoints are different (test setup validation)
        assertTrue(
            transitions[0].checkpoint.blockNumber != transitions[2].checkpoint.blockNumber,
            "Test setup error: checkpoints should be different"
        );

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions,
            metadata: metadata
        });

        bytes memory proveData = _codec().encodeProveInput(input);
        bytes memory proof = _createValidProof();

        // This should succeed after the fix
        vm.prank(currentProver);
        inbox.prove(proveData, proof);

        // Verify transition record was stored
        (, bytes26 recordHash) =
            inbox.getTransitionRecordHash(proposals[0].id, _getGenesisTransitionHash());
        assertTrue(recordHash != bytes26(0), "Transition record should be stored");
    }

    /// @notice Verifies prove() succeeds with 2 consecutive proposals (minimal aggregation case)
    function test_prove_twoConsecutiveProposals_withDistinctCheckpoints() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(2);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](2);

        bytes32 parentHash = _getGenesisTransitionHash();

        // First transition with checkpoint A
        transitions[0] = IInbox.Transition({
            proposalHash: _codec().hashProposal(proposals[0]),
            parentTransitionHash: parentHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 1000,
                blockHash: bytes32(uint256(0xAAAA)),
                stateRoot: bytes32(uint256(0xBBBB))
            })
        });
        metadata[0] = _createMetadataForTransition(Alice, Alice);

        parentHash = keccak256(abi.encode(transitions[0]));

        // Second transition with checkpoint B (different!)
        transitions[1] = IInbox.Transition({
            proposalHash: _codec().hashProposal(proposals[1]),
            parentTransitionHash: parentHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 2000,
                blockHash: bytes32(uint256(0xCCCC)),
                stateRoot: bytes32(uint256(0xDDDD))
            })
        });
        metadata[1] = _createMetadataForTransition(Alice, Alice);

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions,
            metadata: metadata
        });

        bytes memory proveData = _codec().encodeProveInput(input);
        bytes memory proof = _createValidProof();

        vm.prank(currentProver);
        inbox.prove(proveData, proof);

        (, bytes26 recordHash) =
            inbox.getTransitionRecordHash(proposals[0].id, _getGenesisTransitionHash());
        assertTrue(recordHash != bytes26(0), "Transition record should be stored");
    }

    /// @notice Unit test demonstrating that checkpoint mutation DOES change the hash
    /// @dev This test shows WHY the bug was a problem - mutating checkpoint changes hash
    function test_unit_checkpointMutationChangesHash() public {
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(2);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](2);

        bytes32 parentHash = _getGenesisTransitionHash();

        transitions[0] = IInbox.Transition({
            proposalHash: _codec().hashProposal(proposals[0]),
            parentTransitionHash: parentHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 1000,
                blockHash: bytes32(uint256(0xAAAA)),
                stateRoot: bytes32(uint256(0xBBBB))
            })
        });
        metadata[0] = _createMetadataForTransition(Alice, Alice);

        parentHash = keccak256(abi.encode(transitions[0]));

        transitions[1] = IInbox.Transition({
            proposalHash: _codec().hashProposal(proposals[1]),
            parentTransitionHash: parentHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 2000,
                blockHash: bytes32(uint256(0xCCCC)),
                stateRoot: bytes32(uint256(0xDDDD))
            })
        });
        metadata[1] = _createMetadataForTransition(Alice, Alice);

        // Hash with ORIGINAL transitions (what prover computes)
        bytes32 originalHash = _codec().hashTransitionsWithMetadata(transitions, metadata);

        // Mutate like the bug did: transitions[0].checkpoint = transitions[1].checkpoint
        transitions[0].checkpoint = transitions[1].checkpoint;

        // Hash with MUTATED transitions
        bytes32 mutatedHash = _codec().hashTransitionsWithMetadata(transitions, metadata);

        // These MUST be different - proves the mutation affects the hash
        assertTrue(
            originalHash != mutatedHash,
            "Mutation should change hash - this proves the bug was real"
        );
    }
}
