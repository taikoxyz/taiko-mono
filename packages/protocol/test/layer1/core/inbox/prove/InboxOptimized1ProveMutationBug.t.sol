// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title InboxOptimized1ProveMutationBugTest
/// @notice Test to verify the fix for the input mutation bug in InboxOptimized1
/// @dev The bug was: _setAggregatedTransitionRecordHashAndDeadline mutated input.transitions[_firstIndex].checkpoint
///      BEFORE _hashTransitionsWithMetadata was called, causing hash mismatch between prover and contract.
///      The fix: compute aggregatedProvingHash BEFORE calling _buildAndSaveTransitionRecords.
contract InboxOptimized1ProveMutationBugTest is InboxTestHelper {
    function setUp() public virtual override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }

    /// @notice Verifies that prove() succeeds with consecutive proposals after the fix
    /// @dev Before the fix, this would have caused a hash mismatch because:
    ///      1. Contract would mutate transitions[0].checkpoint during aggregation
    ///      2. Then compute hash with mutated data
    ///      3. Prover's hash (using original data) wouldn't match
    ///      After the fix, hash is computed BEFORE any mutation, so it matches.
    function test_prove_consecutiveProposals_hashMatchesAfterFix() public {
        address currentProposer = _selectProposer(Bob);

        // Create 3 consecutive proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](3);
        proposals[0] = _proposeAndGetProposal(currentProposer);

        for (uint256 i = 1; i < 3; i++) {
            vm.warp(block.timestamp + 12);
            proposals[i] = _proposeConsecutiveProposal(proposals[i - 1], currentProposer);
        }

        // Build transitions with DISTINCT checkpoints for each proposal
        // This is critical - if all checkpoints were identical, the mutation wouldn't matter
        IInbox.Transition[] memory transitions = new IInbox.Transition[](3);
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](3);

        bytes32 parentHash = _getGenesisTransitionHash();

        for (uint256 i = 0; i < 3; i++) {
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: uint48(1000 + i * 100), // Different for each: 1000, 1100, 1200
                blockHash: bytes32(uint256(0xaaaa + i)),
                stateRoot: bytes32(uint256(0xbbbb + i))
            });

            transitions[i] = IInbox.Transition({
                proposalHash: _codec().hashProposal(proposals[i]),
                parentTransitionHash: parentHash,
                checkpoint: checkpoint
            });

            metadata[i] = IInbox.TransitionMetadata({
                designatedProver: Alice,
                actualProver: Alice
            });

            parentHash = keccak256(abi.encode(transitions[i]));
        }

        // Verify checkpoints are different (test setup validation)
        assertTrue(
            transitions[0].checkpoint.blockNumber != transitions[2].checkpoint.blockNumber,
            "Test setup error: checkpoints should be different"
        );

        // Create prove input and call prove - this should succeed after the fix
        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions,
            metadata: metadata
        });

        bytes memory proveData = _codec().encodeProveInput(input);
        bytes memory proof = abi.encode("valid_proof");

        // This should NOT revert after the fix
        // Before the fix, a real verifier would reject due to hash mismatch
        vm.prank(Carol);
        inbox.prove(proveData, proof);

        // If we get here without reverting, the prove succeeded
        // Verify transition record was stored for the first proposal
        (, bytes26 recordHash) =
            inbox.getTransitionRecordHash(proposals[0].id, _getGenesisTransitionHash());
        assertTrue(recordHash != bytes26(0), "Transition record should be stored");
    }

    /// @notice Verifies that prove() succeeds with 2 consecutive proposals (minimal aggregation case)
    function test_prove_twoConsecutiveProposals_hashMatchesAfterFix() public {
        address currentProposer = _selectProposer(Bob);

        // Create 2 consecutive proposals (minimal case for aggregation)
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = _proposeAndGetProposal(currentProposer);
        vm.warp(block.timestamp + 12);
        proposals[1] = _proposeConsecutiveProposal(proposals[0], currentProposer);

        // Build transitions with DISTINCT checkpoints
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
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: Alice,
            actualProver: Alice
        });

        parentHash = keccak256(abi.encode(transitions[0]));

        // Second transition with checkpoint B (different!)
        transitions[1] = IInbox.Transition({
            proposalHash: _codec().hashProposal(proposals[1]),
            parentTransitionHash: parentHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 2000, // Different!
                blockHash: bytes32(uint256(0xCCCC)), // Different!
                stateRoot: bytes32(uint256(0xDDDD)) // Different!
            })
        });
        metadata[1] = IInbox.TransitionMetadata({
            designatedProver: Alice,
            actualProver: Alice
        });

        // Create prove input and call prove
        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions,
            metadata: metadata
        });

        bytes memory proveData = _codec().encodeProveInput(input);
        bytes memory proof = abi.encode("valid_proof");

        // This should succeed after the fix
        vm.prank(Carol);
        inbox.prove(proveData, proof);

        // Verify transition record was stored
        (, bytes26 recordHash) =
            inbox.getTransitionRecordHash(proposals[0].id, _getGenesisTransitionHash());
        assertTrue(recordHash != bytes26(0), "Transition record should be stored");
    }

    /// @notice Unit test demonstrating that checkpoint mutation DOES change the hash
    /// @dev This test shows WHY the bug was a problem - mutating checkpoint changes hash
    function test_unit_checkpointMutationChangesHash() public {
        address currentProposer = _selectProposer(Bob);

        // Create 2 proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = _proposeAndGetProposal(currentProposer);
        vm.warp(block.timestamp + 12);
        proposals[1] = _proposeConsecutiveProposal(proposals[0], currentProposer);

        // Build transitions with DISTINCT checkpoints
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
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: Alice,
            actualProver: Alice
        });

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
        metadata[1] = IInbox.TransitionMetadata({
            designatedProver: Alice,
            actualProver: Alice
        });

        // Hash with ORIGINAL transitions (what prover computes)
        bytes32 originalHash = _codec().hashTransitionsWithMetadata(transitions, metadata);

        // Now mutate like the bug did: transitions[0].checkpoint = transitions[1].checkpoint
        transitions[0].checkpoint = transitions[1].checkpoint;

        // Hash with MUTATED transitions
        bytes32 mutatedHash = _codec().hashTransitionsWithMetadata(transitions, metadata);

        // These MUST be different - this proves the mutation affects the hash
        assertTrue(
            originalHash != mutatedHash,
            "Mutation should change hash - this proves the bug was real"
        );
    }

    // ---------------------------------------------------------------
    // Helper functions
    // ---------------------------------------------------------------

    function _proposeAndGetProposal(address proposer) internal returns (IInbox.Proposal memory) {
        _setupBlobHashes();

        if (block.number < 2) {
            vm.roll(2);
        }
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        vm.prank(proposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayload(1, 1, 0, proposer);

        return expectedPayload.proposal;
    }

    function _proposeConsecutiveProposal(
        IInbox.Proposal memory _parent,
        address proposer
    )
        internal
        returns (IInbox.Proposal memory)
    {
        uint48 expectedLastBlockId;
        if (_parent.id == 0) {
            expectedLastBlockId = 1;
            vm.roll(2);
        } else {
            vm.roll(block.number + 1);
            expectedLastBlockId = uint48(block.number - 1);
        }

        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: _parent.id + 1,
            lastProposalBlockId: expectedLastBlockId,
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _parent;

        bytes memory proposeData = _codec().encodeProposeInput(
            _createProposeInputWithCustomParams(
                0,
                _createBlobRef(0, 1, 0),
                parentProposals,
                coreState
            )
        );

        vm.prank(proposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayload(_parent.id + 1, 1, 0, proposer);

        return expectedPayload.proposal;
    }
}
