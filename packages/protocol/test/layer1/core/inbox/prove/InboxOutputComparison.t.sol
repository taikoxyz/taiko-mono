// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxDeployer } from "../deployers/InboxDeployer.sol";
import { InboxOptimized1Deployer } from "../deployers/InboxOptimized1Deployer.sol";
import { InboxTestHelper } from "../common/InboxTestHelper.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title InboxOutputComparisonBase
/// @notice Base test for comparing ProvedEventPayload outputs
abstract contract InboxOutputComparisonBase is InboxTestHelper {
    address internal currentProposer = Bob;
    address internal currentProver = Carol;

    function setUp() public virtual override {
        super.setUp();
        currentProposer = _selectProposer(Bob);

        // Activate the inbox
        vm.prank(owner);
        inbox.activate(GENESIS_BLOCK_HASH);
    }

    /// @dev Test: Propose 4 proposals, prove with chained checkpoints, then finalize
    /// forge-config: default.isolate = true
    function test_fourProposalsWithChainedCheckpoints() public {
        console2.log("\n=== Testing 4 Proposals with Chained Checkpoints ===");
        console2.log("Implementation:", inboxContractName);
        console2.log("");

        // Use deterministic block and timestamp for consistency across both implementations
        uint256 startBlock = 100;
        uint256 startTimestamp = 1000;
        vm.roll(startBlock);
        vm.warp(startTimestamp);

        // Step 1: Propose 4 proposals
        console2.log("Step 1: Proposing 4 proposals");
        IInbox.Proposal[] memory proposals = _createConsecutiveProposals(4);

        for (uint256 i = 0; i < proposals.length; i++) {
            console2.log("  Proposal", i + 1, "ID:", proposals[i].id);
        }

        // Step 2: Prove all 4 proposals in a single batch prove call with chained checkpoints
        console2.log("\nStep 2: Proving 4 proposals in batch with chained checkpoints");
        IInbox.ProvedEventPayload[] memory payloads = _proveBatchWithDeterministicCheckpoints(proposals);

        // Step 3: Print payload details for comparison
        console2.log("\n=== ProvedEventPayload Details ===");
        console2.log("Total Proved events emitted:", payloads.length);
        console2.log("");
        _printPayloadDetails(payloads);

        console2.log("\n=== Test Complete ===\n");
    }

    /// @notice Prove all proposals in a single batch with deterministic chained checkpoints
    /// @dev Uses fixed checkpoint data to ensure identical results across implementations
    function _proveBatchWithDeterministicCheckpoints(IInbox.Proposal[] memory _proposals)
        internal
        returns (IInbox.ProvedEventPayload[] memory payloads)
    {
        // Use deterministic checkpoint data - same for all test runs
        bytes32[4] memory checkpointBlockHashes = [
            bytes32(uint256(0x1111111111111111111111111111111111111111111111111111111111111111)),
            bytes32(uint256(0x2222222222222222222222222222222222222222222222222222222222222222)),
            bytes32(uint256(0x3333333333333333333333333333333333333333333333333333333333333333)),
            bytes32(uint256(0x4444444444444444444444444444444444444444444444444444444444444444))
        ];

        bytes32[4] memory checkpointStateRoots = [
            bytes32(uint256(0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)),
            bytes32(uint256(0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb)),
            bytes32(uint256(0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc)),
            bytes32(uint256(0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd))
        ];

        // Build all transitions with chained parent hashes
        IInbox.Transition[] memory transitions = new IInbox.Transition[](_proposals.length);
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](_proposals.length);

        bytes32 parentTransitionHash = _getGenesisTransitionHash();

        for (uint256 i = 0; i < _proposals.length; i++) {
            // Create deterministic checkpoint for this proposal
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: uint48(1000 + i), // Fixed block numbers: 1000, 1001, 1002, 1003
                blockHash: checkpointBlockHashes[i],
                stateRoot: checkpointStateRoots[i]
            });

            // Create transition that chains to previous
            transitions[i] = IInbox.Transition({
                proposalHash: _codec().hashProposal(_proposals[i]),
                parentTransitionHash: parentTransitionHash,
                checkpoint: checkpoint
            });

            metadata[i] = IInbox.TransitionMetadata({
                designatedProver: currentProver,
                actualProver: currentProver
            });

            // Update parent hash for next iteration (chain transitions)
            parentTransitionHash = _codec().hashTransition(transitions[i]);
        }

        // Build single prove input with all proposals
        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: _proposals,
            transitions: transitions,
            metadata: metadata
        });

        bytes memory proveData = _codec().encodeProveInput(input);
        bytes memory proof = abi.encode("valid_proof");

        // Record logs to capture all Proved events
        vm.recordLogs();

        vm.prank(currentProver);
        inbox.prove(proveData, proof);

        console2.log("  Batch prove completed for", _proposals.length, "proposals");

        // Extract all payloads from logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        payloads = _extractAllProvedEventPayloads(logs);

        console2.log("  Extracted", payloads.length, "ProvedEventPayload objects");

        return payloads;
    }

    /// @notice Extract all ProvedEventPayload objects from recorded logs
    /// @dev Handles multiple Proved events emitted in a batch prove call
    function _extractAllProvedEventPayloads(Vm.Log[] memory _logs)
        internal
        view
        returns (IInbox.ProvedEventPayload[] memory payloads)
    {
        // Count Proved events first
        uint256 provedEventCount = 0;
        for (uint256 i = 0; i < _logs.length; i++) {
            if (_logs[i].topics[0] == keccak256("Proved(bytes)")) {
                provedEventCount++;
            }
        }

        require(provedEventCount > 0, "No Proved events found");

        // Extract all payloads
        payloads = new IInbox.ProvedEventPayload[](provedEventCount);
        uint256 payloadIndex = 0;

        for (uint256 i = 0; i < _logs.length; i++) {
            if (_logs[i].topics[0] == keccak256("Proved(bytes)")) {
                bytes memory eventData = _logs[i].data;
                // Event data is already ABI encoded, need to decode the outer wrapper first
                bytes memory innerData = abi.decode(eventData, (bytes));
                payloads[payloadIndex] = _codec().decodeProvedEvent(innerData);
                payloadIndex++;
            }
        }

        return payloads;
    }

    /// @notice Print detailed payload information for comparison
    function _printPayloadDetails(IInbox.ProvedEventPayload[] memory _payloads) internal pure {
        for (uint256 i = 0; i < _payloads.length; i++) {
            IInbox.ProvedEventPayload memory p = _payloads[i];

            console2.log("================================================================================");
            console2.log("PAYLOAD", i + 1);
            console2.log("================================================================================");
            console2.log("");

            console2.log("  Proposal ID:                     ", p.proposalId);
            console2.log("");

            console2.log("  TRANSITION:");
            console2.log("    proposalHash:                  ", uint256(p.transition.proposalHash));
            console2.log("    parentTransitionHash:          ", uint256(p.transition.parentTransitionHash));
            console2.log("");
            console2.log("    Checkpoint:");
            console2.log("      blockNumber:                 ", p.transition.checkpoint.blockNumber);
            console2.log("      blockHash:                   ", uint256(p.transition.checkpoint.blockHash));
            console2.log("      stateRoot:                   ", uint256(p.transition.checkpoint.stateRoot));
            console2.log("");

            console2.log("  TRANSITION RECORD:");
            console2.log("    span:                          ", p.transitionRecord.span);
            console2.log("    transitionHash:                ", uint256(p.transitionRecord.transitionHash));
            console2.log("    checkpointHash:                ", uint256(p.transitionRecord.checkpointHash));
            console2.log("    bondInstructions.length:       ", p.transitionRecord.bondInstructions.length);
            console2.log("");

            console2.log("  METADATA:");
            console2.log("    designatedProver:              ", p.metadata.designatedProver);
            console2.log("    actualProver:                  ", p.metadata.actualProver);
            console2.log("");
        }
        console2.log("================================================================================");
    }

    function _createConsecutiveProposals(uint8 count)
        internal
        returns (IInbox.Proposal[] memory proposals)
    {
        proposals = new IInbox.Proposal[](count);

        // Setup blobs once for all proposals
        _setupBlobHashes();

        for (uint256 i = 0; i < count; i++) {
            if (i == 0) {
                proposals[i] = _proposeAndGetProposal();
            } else {
                // Advance by fixed time interval for determinism
                vm.warp(block.timestamp + 12);
                proposals[i] = _proposeConsecutiveProposal(proposals[i - 1]);
            }
        }
    }

    function _proposeAndGetProposal() internal returns (IInbox.Proposal memory) {
        // Don't setup blobs again - already done in _createConsecutiveProposals

        if (block.number < 2) {
            vm.roll(2);
        }
        bytes memory proposeData = _codec().encodeProposeInput(_createFirstProposeInput());

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayload(1, 1, 0, currentProposer);

        return expectedPayload.proposal;
    }

    function _proposeConsecutiveProposal(IInbox.Proposal memory _parent)
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

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        IInbox.ProposedEventPayload memory expectedPayload =
            _buildExpectedProposedPayload(_parent.id + 1, 1, 0, currentProposer);

        return expectedPayload.proposal;
    }
}

/// @title InboxOutputComparisonStandard
/// @notice Test for standard Inbox implementation
contract InboxOutputComparisonStandard is InboxOutputComparisonBase {
    function setUp() public override {
        setDeployer(new InboxDeployer());
        super.setUp();
    }
}

/// @title InboxOutputComparisonOptimized1
/// @notice Test for InboxOptimized1 implementation
contract InboxOutputComparisonOptimized1 is InboxOutputComparisonBase {
    function setUp() public override {
        setDeployer(new InboxOptimized1Deployer());
        super.setUp();
    }
}
