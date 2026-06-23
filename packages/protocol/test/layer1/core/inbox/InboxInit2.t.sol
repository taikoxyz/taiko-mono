// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

contract InboxInit2Test is InboxTestBase {
    function test_init2_ResetsCoreState() public {
        uint48 nextProposalId = 1;
        uint48 lastProposalBlockId = 0;
        uint48 lastFinalizedProposalId = 0;
        bytes32 lastFinalizedBlockHash = keccak256("trustedBlockHash");

        vm.warp(4567);

        vm.expectEmit(false, false, false, true, address(inbox));
        emit IInbox.StateRecovered(nextProposalId, lastFinalizedProposalId, lastFinalizedBlockHash);

        inbox.init2(
            nextProposalId, lastProposalBlockId, lastFinalizedProposalId, lastFinalizedBlockHash
        );

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.nextProposalId, nextProposalId);
        assertEq(state.lastProposalBlockId, lastProposalBlockId);
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

        inbox.init2(2, 0, 0, recoveredBlockHash);

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
        inbox.init2(1, 0, 0, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_CallerNotOwner() public {
        vm.expectRevert();
        vm.prank(Alice);
        inbox.init2(10, 1234, 8, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_NextProposalIdIsZero() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(0, 1234, 0, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_LastFinalizedProposalIdTooHigh() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(10, 1234, 10, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_NextProposalIdExceedsCurrentState() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(2, 0, 0, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_LastProposalBlockIdInFuture() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(1, uint48(block.number + 1), 0, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_UnfinalizedRangeExceedsRingBuffer() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(101, 1234, 1, keccak256("trustedBlockHash"));
    }

    function test_init2_RevertWhen_LastFinalizedBlockHashZero() public {
        vm.expectRevert(Inbox.InvalidRecoveryState.selector);
        inbox.init2(10, 1234, 8, bytes32(0));
    }

    function test_init2_RevertWhen_CalledTwice() public {
        inbox.init2(1, 0, 0, keccak256("trustedBlockHash"));

        vm.expectRevert();
        inbox.init2(1, 0, 0, keccak256("anotherTrustedBlockHash"));
    }
}
