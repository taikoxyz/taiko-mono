// SPDX-License-Identifier: MIT
/// @custom:security-contact security@taiko.xyz
pragma solidity ^0.8.24;

import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibBlobs } from "contracts/layer1/shasta/libs/LibBlobs.sol";
import { LibBonds } from "contracts/shared/based/libs/LibBonds.sol";
import { InboxTestSetup } from "../common/InboxTestSetup.sol";
import { BlobTestUtils } from "../common/BlobTestUtils.sol";
import { console2 } from "forge-std/src/console2.sol";
import { Vm } from "forge-std/src/Vm.sol";

// Import errors from Inbox implementation
import "contracts/layer1/shasta/impl/Inbox.sol";

/// @title AbstractProveTest
/// @notice All prove tests for Inbox implementations
abstract contract AbstractProveTest is InboxTestSetup, BlobTestUtils {
    
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    address internal currentProposer = Bob;
    address internal currentProver = Carol;

    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        super.setUp();

        // Select a proposer for creating proposals to prove
        currentProposer = _selectProposer(Bob);
    }

    // ---------------------------------------------------------------
    // Main prove tests with gas snapshot
    // ---------------------------------------------------------------

    /// forge-config: default.isolate = true
    function test_prove_singleProposal() public {
        // First create a proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();
        
        // Create prove input for this proposal
        bytes memory proveData = _createProveInput(proposal);
        bytes memory proof = _createValidProof();
        
        // Build expected event data
        IInbox.ProvedEventPayload memory expectedPayload = _buildExpectedProvedPayload(
            proposal.id,
            _createTransitionForProposal(proposal)
        );
        
        // Expect the Proved event
        vm.expectEmit();
        emit IInbox.Proved(inbox.encodeProvedEventData(expectedPayload));
        
        vm.startPrank(currentProver);
        // Act: Submit the proof
        vm.startSnapshotGas(
            "shasta-prove", 
            string.concat("prove_single_proposal_", getTestContractName())
        );
        inbox.prove(proveData, proof);
        vm.stopSnapshotGas();
        vm.stopPrank();
        
        // Assert: Verify transition record is stored
        bytes32 transitionRecordHash = inbox.getTransitionRecordHash(
            proposal.id, 
            _getGenesisTransitionHash()
        );
        assertTrue(transitionRecordHash != bytes32(0), "Transition record should be stored");
    }

    // ---------------------------------------------------------------
    // Validation tests
    // ---------------------------------------------------------------

    function test_prove_RevertWhen_EmptyProposals() public {
        // Create empty ProveInput
        IInbox.ProveInput memory input;
        bytes memory proveData = inbox.encodeProveInput(input);
        bytes memory proof = _createValidProof();
        
        // Should revert with EmptyProposals
        vm.expectRevert(EmptyProposals.selector);
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
    }

    function test_prove_RevertWhen_InconsistentParams() public virtual {
        // Create ProveInput with mismatched array lengths
        IInbox.ProveInput memory input;
        input.proposals = new IInbox.Proposal[](2);
        input.transitions = new IInbox.Transition[](1); // Mismatch!
        
        bytes memory proveData = inbox.encodeProveInput(input);
        bytes memory proof = _createValidProof();
        
        // Should revert with InconsistentParams
        vm.expectRevert(InconsistentParams.selector);
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
    }

    function test_prove_RevertWhen_ProposalNotFound() public {
        // Create a fake proposal that doesn't exist on-chain
        IInbox.Proposal memory fakeProposal = IInbox.Proposal({
            id: 999,
            proposer: Alice,
            timestamp: uint48(block.timestamp),
            coreStateHash: keccak256("fake"),
            derivationHash: keccak256("fake")
        });
        
        bytes memory proveData = _createProveInput(fakeProposal);
        bytes memory proof = _createValidProof();
        
        // Should revert because proposal doesn't exist
        vm.expectRevert();
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
    }

    function test_prove_withCustomDesignatedProver() public {
        // Create a proposal
        IInbox.Proposal memory proposal = _proposeAndGetProposal();
        
        // Create transition with different designated prover
        IInbox.Transition memory transition = _createTransitionForProposal(proposal);
        transition.designatedProver = Alice; // Different from currentProver
        
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = transition;
        
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = proposal;
        
        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions
        });
        
        bytes memory proveData = inbox.encodeProveInput(input);
        bytes memory proof = _createValidProof();
        
        // Should succeed with any designated prover
        vm.prank(currentProver);
        inbox.prove(proveData, proof);
        
        // Verify transition record was stored
        bytes32 transitionRecordHash = inbox.getTransitionRecordHash(
            proposal.id, 
            _getGenesisTransitionHash()
        );
        assertTrue(transitionRecordHash != bytes32(0), "Transition record should be stored");
    }
    // ---------------------------------------------------------------
    // Helper functions for prove input creation
    // ---------------------------------------------------------------

    function _proposeAndGetProposal() internal returns (IInbox.Proposal memory) {
        _setupBlobHashes();
        
        // Create and submit proposal
        bytes memory proposeData = _createFirstProposeInput();
        
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
        
        // Build and return the expected proposal
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(
            1, 1, 0, currentProposer
        );
        
        return expectedPayload.proposal;
    }

    function _proposeConsecutiveProposal(IInbox.Proposal memory _parent) internal returns (IInbox.Proposal memory) {
        // Build state for consecutive proposal
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: _parent.id + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });
        
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _parent;
        
        bytes memory proposeData = _createProposeInputWithCustomParams(
            0, // no deadline
            _createBlobRef(0, 1, 0),
            parentProposals,
            coreState
        );
        
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
        
        // Build and return the expected proposal
        IInbox.ProposedEventPayload memory expectedPayload = _buildExpectedProposedPayload(
            _parent.id + 1, 1, 0, currentProposer
        );
        
        return expectedPayload.proposal;
    }

    function _createProveInput(IInbox.Proposal memory _proposal) internal view returns (bytes memory) {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = _proposal;
        return _createProveInputForProposals(proposals);
    }

    function _createProveInputForProposals(IInbox.Proposal[] memory _proposals) internal view returns (bytes memory) {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](_proposals.length);
        
        bytes32 parentTransitionHash = _getGenesisTransitionHash();
        
        for (uint256 i = 0; i < _proposals.length; i++) {
            transitions[i] = _createTransitionForProposal(_proposals[i]);
            transitions[i].parentTransitionHash = parentTransitionHash;
            
            // Update parent hash for next iteration
            parentTransitionHash = keccak256(abi.encode(transitions[i]));
        }
        
        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: _proposals,
            transitions: transitions
        });
        
        return inbox.encodeProveInput(input);
    }

    function _createTransitionForProposal(IInbox.Proposal memory _proposal) internal view returns (IInbox.Transition memory) {
        return IInbox.Transition({
            proposalHash: keccak256(abi.encode(_proposal)),
            parentTransitionHash: _getGenesisTransitionHash(),
            endBlockMiniHeader: IInbox.BlockMiniHeader({
                number: uint48(block.number),
                hash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(200))
            }),
            designatedProver: currentProver,
            actualProver: currentProver
        });
    }

    function _buildExpectedProvedPayload(
        uint48 _proposalId,
        IInbox.Transition memory _transition
    ) internal pure returns (IInbox.ProvedEventPayload memory) {
        // Build transition record
        IInbox.TransitionRecord memory transitionRecord = IInbox.TransitionRecord({
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0),
            transitionHash: keccak256(abi.encode(_transition)),
            endBlockMiniHeaderHash: keccak256(abi.encode(_transition.endBlockMiniHeader))
        });
        
        return IInbox.ProvedEventPayload({
            proposalId: _proposalId,
            transition: _transition,
            transitionRecord: transitionRecord
        });
    }

    function _createValidProof() internal pure returns (bytes memory) {
        // MockProofVerifier always accepts, so return any non-empty proof
        return abi.encode("valid_proof");
    }

    // Helper function needed from propose tests
    function _createProposeInputWithCustomParams(
        uint48 _deadline,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.Proposal[] memory _parentProposals,
        IInbox.CoreState memory _coreState
    ) internal view returns (bytes memory) {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: _deadline,
            coreState: _coreState,
            parentProposals: _parentProposals,
            blobReference: _blobRef,
            endBlockMiniHeader: IInbox.BlockMiniHeader({
                number: uint48(block.number),
                hash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(100))
            }),
            transitionRecords: new IInbox.TransitionRecord[](0)
        });
        
        return inbox.encodeProposeInput(input);
    }

    function _createFirstProposeInput() internal view returns (bytes memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);
        
        IInbox.ProposeInput memory input;
        input.coreState = coreState;
        input.parentProposals = parentProposals;
        input.blobReference = blobRef;
        
        return inbox.encodeProposeInput(input);
    }

    // ---------------------------------------------------------------
    // Abstract Functions
    // ---------------------------------------------------------------

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    ) internal virtual override returns (Inbox);

    /// @dev Returns the name of the test contract for snapshot identification
    function getTestContractName() internal pure virtual returns (string memory);
}