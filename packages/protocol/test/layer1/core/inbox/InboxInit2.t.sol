// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

contract InboxInit2Test is InboxTestBase {
    function test_init2_ResetsCoreState() public {
        uint48 lastFinalizedProposalId = 0;
        bytes32 lastFinalizedBlockHash = keccak256("trustedBlockHash");

        vm.warp(4567);

        // nextProposalId and lastProposalBlockId are preserved from the existing core state.
        IInbox.CoreState memory beforeState = inbox.getCoreState();

        vm.expectEmit(false, false, false, true, address(inbox));
        emit IInbox.StateRecovered(
            beforeState.nextProposalId, lastFinalizedProposalId, lastFinalizedBlockHash
        );

        inbox.init2(lastFinalizedProposalId, lastFinalizedBlockHash);

        IInbox.CoreState memory state = inbox.getCoreState();
        // Preserved fields.
        assertEq(state.nextProposalId, beforeState.nextProposalId);
        assertEq(state.lastProposalBlockId, beforeState.lastProposalBlockId);
        // Reset fields.
        assertEq(state.lastFinalizedProposalId, lastFinalizedProposalId);
        assertEq(state.lastFinalizedTimestamp, uint48(block.timestamp));
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp));
        assertEq(state.lastFinalizedBlockHash, lastFinalizedBlockHash);
    }

    function test_init2_ProofMustLinkToRecoveredBlockHash() public {
        _advanceBlock();
        ProposedEvent memory proposal = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);
        bytes32 proposalHash = inbox.getProposalHash(proposal.id);

        bytes32 recoveredBlockHash = keccak256("trustedBlockHash");
        bytes32 forgedBlockHash = inbox.getCoreState().lastFinalizedBlockHash;
        assertNotEq(forgedBlockHash, recoveredBlockHash);

        inbox.init2(0, recoveredBlockHash);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = _transitionFor(proposal, proposalTimestamp, keccak256("canonicalBlock"));

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: proposal.id,
                firstProposalParentBlockHash: forgedBlockHash,
                lastProposalHash: proposalHash,
                actualProver: prover,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256("stateRoot"),
                transitions: transitions
            })
        });

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.prank(prover);
        vm.expectRevert(Inbox.ParentBlockHashMismatch.selector);
        inbox.prove(encodedInput, bytes("proof"));

        input.commitment.firstProposalParentBlockHash = recoveredBlockHash;
        _prove(input);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, proposal.id);
        assertEq(state.lastFinalizedBlockHash, transitions[0].blockHash);
    }

    function test_init2_RevertWhen_ProxyAlreadyAtVersion2() public {
        vm.store(address(inbox), bytes32(0), bytes32(uint256(2)));

        vm.expectRevert();
        inbox.init2(0, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_CallerNotOwner() public {
        vm.expectRevert();
        vm.prank(Alice);
        inbox.init2(8, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_InboxNotActivated() public {
        // A freshly deployed (but not activated) inbox has nextProposalId == 0, so recovery must
        // revert on the "inbox must be activated" check.
        Inbox freshInbox = _deployInbox();
        assertEq(freshInbox.getCoreState().nextProposalId, 0);

        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        freshInbox.init2(0, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_LastFinalizedProposalIdTooHigh() public {
        // _lastFinalizedProposalId must be strictly less than nextProposalId.
        uint48 npid = inbox.getCoreState().nextProposalId;

        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(npid, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_UnfinalizedRangeExceedsRingBuffer() public {
        // After activation nextProposalId is only 1, so force it to ringBufferSize (100) via storage
        // to exercise the unfinalized-range check. _coreState lives at slot 252 with nextProposalId
        // packed in the lowest 48 bits, so storing 100 there sets nextProposalId=100 and zeroes the
        // other packed fields (acceptable for this revert-only test).
        vm.store(address(inbox), bytes32(uint256(252)), bytes32(uint256(100)));
        assertEq(inbox.getCoreState().nextProposalId, 100);

        // 100 - 0 == 100 is NOT < ringBufferSize (100), so recovery reverts.
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(0, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_LastFinalizedBlockHashZero() public {
        // Passes checks #2 and #3 but fails the non-zero block hash check.
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(0, bytes32(0));
    }

    function test_init2_RevertWhen_CalledTwice() public {
        inbox.init2(0, keccak256("trustedBlockHash"));

        vm.expectRevert();
        inbox.init2(0, keccak256("anotherTrustedBlockHash"));
    }
}
