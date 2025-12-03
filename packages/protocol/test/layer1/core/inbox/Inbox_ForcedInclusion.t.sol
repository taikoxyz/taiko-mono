// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

import { InboxTestHelper } from "./common/InboxTestHelper.sol";

/// @title InboxForcedInclusionTest
/// @notice Tests for Inbox forced inclusion functionality
/// @custom:security-contact security@taiko.xyz
contract InboxForcedInclusionTest is InboxTestHelper {
    // ---------------------------------------------------------------
    // Save Forced Inclusion Tests
    // ---------------------------------------------------------------

    function test_saveForcedInclusion_success() public {
        // First need a proposal so saveForcedInclusion can work
        _proposeAndGetPayload();

        _setupBlobHashes();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);

        uint64 fee = inbox.getCurrentForcedInclusionFee();

        vm.deal(David, 1 ether);
        vm.expectEmit(false, false, false, false);
        emit IForcedInclusionStore
            .ForcedInclusionSaved(IForcedInclusionStore.ForcedInclusion({
                feeInGwei: uint64(fee),
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: new bytes32[](0), offset: 0, timestamp: 0 }) }));

        vm.prank(David);
        inbox.saveForcedInclusion{ value: fee * 1 gwei }(blobRef);

        // Verify forced inclusion was saved
        (uint40 head, uint40 tail,) = inbox.getForcedInclusionState();
        assertEq(tail - head, 1, "Should have one pending forced inclusion");
    }

    function test_saveForcedInclusion_refundsExcessPayment() public {
        _proposeAndGetPayload();

        _setupBlobHashes();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);

        uint64 fee = inbox.getCurrentForcedInclusionFee();
        uint256 overpayment = (fee + 1000) * 1 gwei;

        vm.deal(David, 1 ether);
        uint256 balanceBefore = David.balance;

        vm.prank(David);
        inbox.saveForcedInclusion{ value: overpayment }(blobRef);

        uint256 balanceAfter = David.balance;
        assertEq(
            balanceBefore - balanceAfter, fee * 1 gwei, "Only fee should be deducted, rest refunded"
        );
    }

    function test_saveForcedInclusion_RevertWhen_NoProposal() public {
        // Deploy fresh inbox without any proposals
        Inbox freshInbox = _deployInbox(_createDefaultConfig());
        vm.prank(owner);
        freshInbox.activate(GENESIS_BLOCK_HASH);

        _setupBlobHashes();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);

        vm.deal(David, 1 ether);
        vm.expectRevert(Inbox.NoProposalExists.selector);
        vm.prank(David);
        freshInbox.saveForcedInclusion{ value: 0.01 ether }(blobRef);
    }

    // ---------------------------------------------------------------
    // Dynamic Fee Tests
    // ---------------------------------------------------------------

    function test_getCurrentForcedInclusionFee_baseCase() public view {
        uint64 fee = inbox.getCurrentForcedInclusionFee();
        assertEq(fee, DEFAULT_FORCED_INCLUSION_FEE_IN_GWEI, "Base fee should match config");
    }

    function test_getCurrentForcedInclusionFee_increasesWithQueue() public {
        _proposeAndGetPayload();

        uint64 baseFee = inbox.getCurrentForcedInclusionFee();

        // Add forced inclusions to increase queue
        for (uint256 i = 0; i < 50; i++) {
            _setupBlobHashes();
            LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);

            uint64 currentFee = inbox.getCurrentForcedInclusionFee();
            vm.deal(address(uint160(i + 1000)), 1 ether);
            vm.prank(address(uint160(i + 1000)));
            inbox.saveForcedInclusion{ value: currentFee * 1 gwei }(blobRef);
        }

        uint64 feeAfter = inbox.getCurrentForcedInclusionFee();
        assertGt(feeAfter, baseFee, "Fee should increase with queue size");
    }

    // ---------------------------------------------------------------
    // Forced Inclusion Consumption Tests
    // ---------------------------------------------------------------

    function test_propose_consumesForcedInclusions() public {
        // First proposal
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Add forced inclusion
        _setupBlobHashes();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);
        uint64 fee = inbox.getCurrentForcedInclusionFee();

        vm.deal(David, 1 ether);
        vm.prank(David);
        inbox.saveForcedInclusion{ value: fee * 1 gwei }(blobRef);

        (uint40 headBefore, uint40 tailBefore,) = inbox.getForcedInclusionState();
        assertEq(tailBefore - headBefore, 1, "Should have one pending");

        // Propose with forced inclusion
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](1);
        headProposalAndProof[0] = payload.proposal;

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload.coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 }),
            numForcedInclusions: 1
        });

        bytes memory proposeData = codex.encodeProposeInput(input);

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        (uint40 headAfter, uint40 tailAfter,) = inbox.getForcedInclusionState();
        assertEq(tailAfter - headAfter, 0, "Forced inclusion should be consumed");
    }

    function test_propose_RevertWhen_ForcedInclusionDue_andNotProcessed() public {
        // First proposal
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Add forced inclusion
        _setupBlobHashes();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);
        uint64 fee = inbox.getCurrentForcedInclusionFee();

        vm.deal(David, 1 ether);
        vm.prank(David);
        inbox.saveForcedInclusion{ value: fee * 1 gwei }(blobRef);

        // Wait for forced inclusion to become due
        vm.warp(block.timestamp + DEFAULT_FORCED_INCLUSION_DELAY + 1);

        // Try to propose without processing forced inclusion
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](1);
        headProposalAndProof[0] = payload.proposal;

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload.coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 }),
            numForcedInclusions: 0 // Not processing forced inclusion
        });

        bytes memory proposeData = codex.encodeProposeInput(input);

        vm.expectRevert(Inbox.UnprocessedForcedInclusionIsDue.selector);
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);
    }

    // ---------------------------------------------------------------
    // Permissionless Proposal Tests
    // ---------------------------------------------------------------

    function test_propose_becomesPermissionless_whenForcedInclusionOld() public {
        // First proposal
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Add forced inclusion
        _setupBlobHashes();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);
        uint64 fee = inbox.getCurrentForcedInclusionFee();

        vm.deal(David, 1 ether);
        vm.prank(David);
        inbox.saveForcedInclusion{ value: fee * 1 gwei }(blobRef);

        // Wait for permissionless period (delay * multiplier)
        uint256 permissionlessTime =
            uint256(DEFAULT_FORCED_INCLUSION_DELAY) * DEFAULT_PERMISSIONLESS_INCLUSION_MULTIPLIER;
        vm.warp(block.timestamp + permissionlessTime + 1);

        // Now anyone can propose (even non-whitelisted Emma)
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](1);
        headProposalAndProof[0] = payload.proposal;

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload.coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 }),
            numForcedInclusions: 1 // Must still process the forced inclusion
        });

        bytes memory proposeData = codex.encodeProposeInput(input);

        // Emma is not whitelisted but should be able to propose
        vm.prank(Emma);
        inbox.propose(bytes(""), proposeData);

        // Verify proposal was created
        bytes32 proposalHash = inbox.getProposalHash(2);
        assertTrue(proposalHash != bytes32(0), "Permissionless proposal should succeed");
    }

    // ---------------------------------------------------------------
    // Fee Transfer Tests
    // ---------------------------------------------------------------

    function test_propose_transfersForcedInclusionFees() public {
        IInbox.ProposedEventPayload memory payload = _proposeAndGetPayload();

        // Add forced inclusion
        _setupBlobHashes();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);
        uint64 fee = inbox.getCurrentForcedInclusionFee();

        vm.deal(David, 1 ether);
        vm.prank(David);
        inbox.saveForcedInclusion{ value: fee * 1 gwei }(blobRef);

        // Proposer balance before
        uint256 proposerBalanceBefore = currentProposer.balance;

        // Propose with forced inclusion
        _setupBlobHashes();
        _rollOneBlock();

        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](1);
        headProposalAndProof[0] = payload.proposal;

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: payload.coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 }),
            numForcedInclusions: 1
        });

        bytes memory proposeData = codex.encodeProposeInput(input);

        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        uint256 proposerBalanceAfter = currentProposer.balance;
        assertEq(
            proposerBalanceAfter - proposerBalanceBefore,
            fee * 1 gwei,
            "Proposer should receive forced inclusion fee"
        );
    }

    // ---------------------------------------------------------------
    // Getter Tests
    // ---------------------------------------------------------------

    function test_getForcedInclusions() public {
        _proposeAndGetPayload();

        // Add multiple forced inclusions
        for (uint256 i = 0; i < 3; i++) {
            _setupBlobHashes();
            LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);
            uint64 fee = inbox.getCurrentForcedInclusionFee();

            vm.deal(address(uint160(i + 2000)), 1 ether);
            vm.prank(address(uint160(i + 2000)));
            inbox.saveForcedInclusion{ value: fee * 1 gwei }(blobRef);
        }

        IForcedInclusionStore.ForcedInclusion[] memory inclusions = inbox.getForcedInclusions(0, 10);
        assertEq(inclusions.length, 3, "Should return 3 forced inclusions");
    }

    function test_getForcedInclusionState() public {
        _proposeAndGetPayload();

        (uint40 head, uint40 tail, uint40 lastProcessedAt) = inbox.getForcedInclusionState();
        assertEq(head, 0, "Initial head should be 0");
        assertEq(tail, 0, "Initial tail should be 0");

        // Add forced inclusion
        _setupBlobHashes();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);
        uint64 fee = inbox.getCurrentForcedInclusionFee();

        vm.deal(David, 1 ether);
        vm.prank(David);
        inbox.saveForcedInclusion{ value: fee * 1 gwei }(blobRef);

        (head, tail, lastProcessedAt) = inbox.getForcedInclusionState();
        assertEq(head, 0, "Head should still be 0");
        assertEq(tail, 1, "Tail should be 1");
    }
}
