// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimizedBase, InboxSimpleBase, InboxTestBase } from "./common/InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

abstract contract InboxGasBenchBase is InboxTestBase {
    function _suiteName() internal pure virtual returns (string memory);

    /// forge-config: default.isolate = true
    function test_gas_propose_single() external {
        _setBlobHashes(2);
        IInbox.ProposeInput memory input = _defaultProposeInput();

        vm.prank(proposer);
        vm.startSnapshotGas("shasta-propose", string.concat("propose_single_", _suiteName()));
        inbox.propose(bytes(""), _encodeProposeInput(input));
        vm.stopSnapshotGas();
    }

    /// forge-config: default.isolate = true
    function test_gas_prove_single() external {
        _setBlobHashes(3);
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(bytes32(uint256(1)));
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: _hashProposal(proposed.proposal),
            parentTransitionHash: inbox.getState().lastFinalizedTransitionHash,
            checkpoint: checkpoint
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            metadata: _metadata(prover, prover),
            checkpoint: checkpoint
        });

        vm.prank(prover);
        vm.startSnapshotGas("shasta-prove", string.concat("prove_single_", _suiteName()));
        inbox.prove(_encodeProveInput(proveInput), bytes(""));
        vm.stopSnapshotGas();
    }

    /// forge-config: default.isolate = true
    function test_gas_finalize_single() external {
        _setBlobHashes(3);
        IInbox.ProposedEventPayload memory proposed = _proposeOne();

        ICheckpointStore.Checkpoint memory checkpoint = _checkpoint(bytes32(uint256(1)));
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: _hashProposal(proposed.proposal),
            parentTransitionHash: inbox.getState().lastFinalizedTransitionHash,
            checkpoint: checkpoint
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(proposed.proposal),
            transitions: _transitions(transition),
            metadata: _metadata(prover, prover),
            checkpoint: checkpoint
        });

        vm.prank(prover);
        vm.startSnapshotGas("shasta-finalize", string.concat("finalize_single_", _suiteName()));
        inbox.prove(_encodeProveInput(proveInput), bytes(""));
        vm.stopSnapshotGas();
    }

    /// forge-config: default.isolate = true
    function test_gas_prove_batch3() external {
        _setBlobHashes(3);
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p3 = _proposeOne();

        IInbox.Transition memory t1 = _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)));
        IInbox.Transition memory t2 = _transitionFor(p2, _hashTransition(t1), bytes32(uint256(2)));
        IInbox.Transition memory t3 = _transitionFor(p3, _hashTransition(t2), bytes32(uint256(3)));

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal, p2.proposal, p3.proposal),
            transitions: _transitions(t1, t2, t3),
            metadata: _metadata(prover, prover, prover, prover, prover, prover),
            checkpoint: t3.checkpoint
        });

        vm.prank(prover);
        vm.startSnapshotGas("shasta-prove", string.concat("prove_consecutive_3_", _suiteName()));
        inbox.prove(_encodeProveInput(proveInput), bytes(""));
        vm.stopSnapshotGas();
    }

    /// forge-config: default.isolate = true
    function test_gas_prove_batch5() external {
        _setBlobHashes(5);
        IInbox.ProposedEventPayload memory p1 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p2 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p3 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p4 = _proposeOne();
        _advanceBlock();
        IInbox.ProposedEventPayload memory p5 = _proposeOne();

        IInbox.Transition memory t1 = _transitionFor(p1, inbox.getState().lastFinalizedTransitionHash, bytes32(uint256(1)));
        IInbox.Transition memory t2 = _transitionFor(p2, _hashTransition(t1), bytes32(uint256(2)));
        IInbox.Transition memory t3 = _transitionFor(p3, _hashTransition(t2), bytes32(uint256(3)));
        IInbox.Transition memory t4 = _transitionFor(p4, _hashTransition(t3), bytes32(uint256(4)));
        IInbox.Transition memory t5 = _transitionFor(p5, _hashTransition(t4), bytes32(uint256(5)));

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: _proposals(p1.proposal, p2.proposal, p3.proposal, p4.proposal, p5.proposal),
            transitions: _transitions(t1, t2, t3, t4, t5),
            metadata: _metadata(
                prover,
                prover,
                prover,
                prover,
                prover,
                prover,
                prover,
                prover,
                prover,
                prover
            ),
            checkpoint: t5.checkpoint
        });

        vm.prank(prover);
        vm.startSnapshotGas("shasta-prove", string.concat("prove_consecutive_3_", _suiteName()));
        inbox.prove(_encodeProveInput(proveInput), bytes(""));
        vm.stopSnapshotGas();
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _proposeOne() internal returns (IInbox.ProposedEventPayload memory payload_) {
        payload_ = _proposeAndDecode(_defaultProposeInput());
    }

    function _checkpoint(bytes32 _stateRoot) internal view returns (ICheckpointStore.Checkpoint memory) {
        return ICheckpointStore.Checkpoint({
            blockNumber: uint48(block.number),
            blockHash: blockhash(block.number - 1),
            stateRoot: _stateRoot
        });
    }

    function _transitionFor(
        IInbox.ProposedEventPayload memory _proposal,
        bytes32 _parentTransitionHash,
        bytes32 _stateRoot
    )
        internal
        view
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposalHash: _hashProposal(_proposal.proposal),
            parentTransitionHash: _parentTransitionHash,
            checkpoint: _checkpoint(_stateRoot)
        });
    }

    function _advanceBlock() internal {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }
}

contract InboxGasBench is InboxGasBenchBase, InboxSimpleBase {
    function _suiteName() internal pure override returns (string memory) {
        return "Inbox";
    }
}

contract InboxOptimizedGasBench is InboxGasBenchBase, InboxOptimizedBase {
    function _suiteName() internal pure override returns (string memory) {
        return "InboxOptimized";
    }

    function _isOptimized() internal view override(InboxOptimizedBase, InboxTestBase) returns (bool) {
        return true;
    }
}
