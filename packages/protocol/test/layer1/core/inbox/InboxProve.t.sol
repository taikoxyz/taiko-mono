// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IBondManager } from "src/layer1/core/iface/IBondManager.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract InboxProveTest is InboxTestBase {
    // ---------------------------------------------------------------------
    // Happy paths
    // ---------------------------------------------------------------------
    function test_prove_single() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        _proveWithGas(input, "shasta-prove", "prove_single");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, input.commitment.firstProposalId, "finalized id");
        assertEq(
            state.lastFinalizedBlockHash, input.commitment.transitions[0].blockHash, "checkpoint"
        );
    }

    function test_prove_batch2() public {
        IInbox.ProveInput memory input = _buildBatchInput(2);

        _proveWithGas(input, "shasta-prove", "prove_batch_2");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(
            state.lastFinalizedProposalId, input.commitment.firstProposalId + 1, "finalized id"
        );
        assertEq(
            state.lastFinalizedBlockHash,
            input.commitment.transitions[1].blockHash,
            "checkpoint hash"
        );
    }

    function test_prove_batch3() public {
        IInbox.ProveInput memory input = _buildBatchInput(3);

        _proveWithGas(input, "shasta-prove", "prove_batch_3");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(
            state.lastFinalizedProposalId, input.commitment.firstProposalId + 2, "finalized id"
        );
        assertEq(
            state.lastFinalizedBlockHash,
            input.commitment.transitions[2].blockHash,
            "checkpoint hash"
        );
    }

    function test_prove_batch5() public {
        IInbox.ProveInput memory input = _buildBatchInput(5);

        _proveWithGas(input, "shasta-prove", "prove_batch_5");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(
            state.lastFinalizedProposalId, input.commitment.firstProposalId + 4, "finalized id"
        );
        assertEq(
            state.lastFinalizedBlockHash,
            input.commitment.transitions[4].blockHash,
            "checkpoint hash"
        );
    }

    function test_prove_batch10() public {
        IInbox.ProveInput memory input = _buildBatchInput(10);

        _proveWithGas(input, "shasta-prove", "prove_batch_10");

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(
            state.lastFinalizedProposalId, input.commitment.firstProposalId + 9, "finalized id"
        );
        assertEq(
            state.lastFinalizedBlockHash,
            input.commitment.transitions[9].blockHash,
            "checkpoint hash"
        );
    }

    // ---------------------------------------------------------------------
    // Proof verifier args
    // ---------------------------------------------------------------------
    function test_prove_passesProposalAge_forSingleProposalProofs() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        IInbox.CoreState memory stateBefore = inbox.getCoreState();
        uint48 proposalTimestamp = input.commitment.transitions[0].timestamp;

        vm.warp(uint256(proposalTimestamp) + 123);

        uint48 availableSince = proposalTimestamp > stateBefore.lastFinalizedTimestamp
            ? proposalTimestamp
            : stateBefore.lastFinalizedTimestamp;
        uint256 expectedAge = block.timestamp - uint256(availableSince);
        assertGt(expectedAge, 0, "sanity: expected age should be > 0");

        bytes32 expectedCommitmentHash = codec.hashCommitment(input.commitment);

        vm.expectCall(
            address(verifier),
            abi.encodeCall(
                IProofVerifier.verifyProof, (expectedAge, expectedCommitmentHash, bytes("proof"))
            )
        );
        _prove(input);
    }

    function test_prove_passesZeroProposalAge_forMultiProposalBatches() public {
        IInbox.ProveInput memory input = _buildBatchInput(2);

        bytes32 expectedCommitmentHash = codec.hashCommitment(input.commitment);

        vm.expectCall(
            address(verifier),
            abi.encodeCall(IProofVerifier.verifyProof, (0, expectedCommitmentHash, bytes("proof")))
        );
        _prove(input);
    }

    // ---------------------------------------------------------------------
    // Bounds and validation
    // ---------------------------------------------------------------------
    function test_prove_RevertWhen_EmptyBatch() public {
        IInbox.ProveInput memory emptyInput = _buildInput(
            1, inbox.getCoreState().lastFinalizedBlockHash, new IInbox.Transition[](0), bytes32(0)
        );

        bytes memory encodedInput = codec.encodeProveInput(emptyInput);
        vm.expectRevert(Inbox.EmptyBatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_FirstProposalIdTooLarge() public {
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(payload, proposalTimestamp, keccak256("checkpoint1"));

        IInbox.ProveInput memory input = _buildInput(
            payload.id + 1,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            keccak256("stateRoot")
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.FirstProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_LastProposalIdTooLarge() public {
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(payload, proposalTimestamp, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(payload, proposalTimestamp, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = _buildInputWithCheckpoint(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            uint48(block.number),
            keccak256("stateRoot")
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_ParentBlockHashMismatch() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p2 = _proposeOne();
        uint48 p2Timestamp = uint48(block.timestamp);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(p1, p1Timestamp, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(p2, p2Timestamp, keccak256("checkpoint2"));

        IInbox.ProveInput memory input =
            _buildInput(1, bytes32(uint256(999)), transitions, keccak256("stateRoot"));

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.ParentBlockHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_acceptsProofWithFinalizedPrefix() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p2 = _proposeOne();
        uint48 p2Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p3 = _proposeOne();
        uint48 p3Timestamp = uint48(block.timestamp);

        bytes32 p1Checkpoint = keccak256("checkpoint1");
        {
            IInbox.Transition[] memory firstBatch =
                _transitionArrayFor(p1, p1Timestamp, p1Checkpoint);
            uint48 endBlockNumber1 = uint48(block.number + 123);
            bytes32 endStateRoot1 = keccak256("stateRoot1");
            IInbox.ProveInput memory firstInput = _buildInputWithCheckpoint(
                p1.id,
                inbox.getCoreState().lastFinalizedBlockHash,
                firstBatch,
                endBlockNumber1,
                endStateRoot1
            );
            _prove(firstInput);

            assertEq(inbox.getCoreState().lastFinalizedProposalId, p1.id, "p1 finalized");

            ICheckpointStore.Checkpoint memory checkpoint1 =
                signalService.getCheckpoint(endBlockNumber1);
            assertEq(checkpoint1.blockHash, p1Checkpoint, "checkpoint1 blockHash");
            assertEq(checkpoint1.stateRoot, endStateRoot1, "checkpoint1 stateRoot");
        }

        vm.warp(block.timestamp + 1);

        IInbox.Transition[] memory fullBatch = new IInbox.Transition[](3);
        fullBatch[0] = _transitionFor(p1, p1Timestamp, p1Checkpoint);
        fullBatch[1] = _transitionFor(p2, p2Timestamp, keccak256("checkpoint2"));
        fullBatch[2] = _transitionFor(p3, p3Timestamp, keccak256("checkpoint3"));

        uint48 endBlockNumber2 = uint48(block.number + 456);
        IInbox.ProveInput memory fullInput = _buildInputWithCheckpoint(
            p1.id, bytes32(0), fullBatch, endBlockNumber2, keccak256("stateRoot3")
        );
        _prove(fullInput);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId, p3.id, "finalized id");
        assertEq(state.lastFinalizedBlockHash, fullBatch[2].blockHash, "checkpoint hash");
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint timestamp");

        ICheckpointStore.Checkpoint memory checkpoint2 =
            signalService.getCheckpoint(endBlockNumber2);
        assertEq(checkpoint2.blockHash, fullBatch[2].blockHash, "checkpoint2 blockHash");
        assertEq(checkpoint2.stateRoot, keccak256("stateRoot3"), "checkpoint2 stateRoot");
    }

    function test_prove_RevertWhen_FinalizedPrefixHashMismatch() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p2 = _proposeOne();
        uint48 p2Timestamp = uint48(block.timestamp);

        bytes32 p1Checkpoint = keccak256("checkpoint1");
        IInbox.Transition[] memory firstBatch = _transitionArrayFor(p1, p1Timestamp, p1Checkpoint);

        IInbox.ProveInput memory firstInput = _buildInput(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, firstBatch, keccak256("stateRoot1")
        );
        _prove(firstInput);

        IInbox.Transition[] memory fullBatch = new IInbox.Transition[](2);
        fullBatch[0] = _transitionFor(p1, p1Timestamp, keccak256("wrongCheckpoint"));
        fullBatch[1] = _transitionFor(p2, p2Timestamp, keccak256("checkpoint2"));

        IInbox.ProveInput memory fullInput =
            _buildInput(p1.id, bytes32(0), fullBatch, keccak256("stateRoot2"));

        bytes memory encodedInput = codec.encodeProveInput(fullInput);
        vm.expectRevert(Inbox.ParentBlockHashMismatch.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // ---------------------------------------------------------------------
    // Bond processing
    // ---------------------------------------------------------------------
    function test_prove_processesBond_whenLate() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);
        _advanceBlock();
        ProposedEvent memory p2 = _proposeOne();
        uint48 p2Timestamp = uint48(block.timestamp);

        vm.warp(block.timestamp + config.provingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposer, timestamp: p1Timestamp, blockHash: keccak256("checkpoint1")
        });
        transitions[1] = _transitionFor(p2, p2Timestamp, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = _buildInput(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, transitions, keccak256("stateRoot")
        );

        uint64 proposerBalanceBefore = inbox.getBond(proposer).balance;
        uint64 proverBalanceBefore = inbox.getBond(prover).balance;

        uint64 debited = config.livenessBond;
        uint64 payeeAmount = debited / 2;
        uint64 amountToSlash = debited - payeeAmount;

        vm.expectEmit();
        emit IBondManager.LivenessBondSettled(
            proposer, prover, config.livenessBond, payeeAmount, amountToSlash
        );

        _prove(input);

        assertEq(
            uint256(inbox.getBond(proposer).balance),
            uint256(proposerBalanceBefore - debited),
            "payer debited"
        );
        assertEq(
            uint256(inbox.getBond(prover).balance),
            uint256(proverBalanceBefore + payeeAmount),
            "payee credited"
        );
    }

    function test_prove_noBondChange_withinProvingWindow() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        uint64 proverBalanceBefore = inbox.getBond(prover).balance;
        _prove(input);

        assertEq(
            uint256(inbox.getBond(prover).balance),
            uint256(proverBalanceBefore),
            "no bond change within window"
        );
    }

    function test_prove_processesBond_whenPayerEqualsPayee() public {
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);
        vm.warp(proposalTimestamp + config.provingWindow + 1);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(payload, proposalTimestamp, keccak256("checkpoint"));

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: payload.id,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(payload.id),
                actualProver: proposer,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256("stateRoot"),
                transitions: transitions
            })
        });

        uint64 proposerBalanceBefore = inbox.getBond(proposer).balance;
        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.prank(proposer);
        inbox.prove(encodedInput, bytes("proof"));

        uint64 debited = config.livenessBond;
        uint64 payeeAmount = debited / 2;
        uint64 expectedBalance = proposerBalanceBefore - debited + payeeAmount;

        assertEq(
            uint256(inbox.getBond(proposer).balance),
            uint256(expectedBalance),
            "payer==payee bond split"
        );
    }

    function test_prove_processesBond_whenLate_withPartialBondBelowSlash() public {
        uint64 partialBond = config.livenessBond / 2;
        address payer = proposer;

        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        _reduceBondTo(payer, partialBond);
        _warpPastProvingWindow(proposalTimestamp);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(payload, proposalTimestamp, keccak256("checkpoint"));

        IInbox.ProveInput memory input = _buildInputWithCheckpoint(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            uint48(block.number),
            keccak256("stateRoot")
        );

        uint64 payerBalanceBefore = inbox.getBond(payer).balance;
        uint64 proverBalanceBefore = inbox.getBond(prover).balance;

        uint64 payeeAmount = payerBalanceBefore / 2;
        uint64 slashedAmount = payerBalanceBefore - payeeAmount;

        vm.expectEmit();
        emit IBondManager.LivenessBondSettled(
            payer, prover, config.livenessBond, payeeAmount, slashedAmount
        );

        _prove(input);

        assertEq(uint256(inbox.getBond(payer).balance), 0, "payer debited");
        assertEq(
            uint256(inbox.getBond(prover).balance),
            uint256(proverBalanceBefore + payeeAmount),
            "payee credited"
        );
    }

    function test_prove_processesBond_whenLate_withPartialBondAboveSlash() public {
        uint64 payerBond = (config.livenessBond / 2) + 1;
        address payer = proposer;

        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        _reduceBondTo(payer, payerBond);
        _warpPastProvingWindow(proposalTimestamp);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(payload, proposalTimestamp, keccak256("checkpoint"));

        IInbox.ProveInput memory input = _buildInputWithCheckpoint(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            uint48(block.number),
            keccak256("stateRoot")
        );

        uint64 payerBalanceBefore = inbox.getBond(payer).balance;
        uint64 proverBalanceBefore = inbox.getBond(prover).balance;
        uint64 payeeAmount = payerBalanceBefore / 2;
        uint64 slashedAmount = payerBalanceBefore - payeeAmount;

        vm.expectEmit();
        emit IBondManager.LivenessBondSettled(
            payer, prover, config.livenessBond, payeeAmount, slashedAmount
        );

        _prove(input);

        assertEq(uint256(inbox.getBond(payer).balance), 0, "payer debited");
        assertEq(
            uint256(inbox.getBond(prover).balance),
            uint256(proverBalanceBefore + payeeAmount),
            "payee credited"
        );
    }

    // ---------------------------------------------------------------------
    // Boundary Tests - prove() conditions
    // ---------------------------------------------------------------------
    function test_prove_succeedsWhen_FirstProposalIdAtExactBoundary() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);
        assertEq(input.commitment.firstProposalId, 1, "firstProposalId should be 1");
        assertEq(
            inbox.getCoreState().lastFinalizedProposalId, 0, "lastFinalizedProposalId should be 0"
        );

        _prove(input);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, 1, "should finalize");
    }

    function test_prove_succeedsWhen_LastProposalIdAtExactBoundary() public {
        IInbox.ProveInput memory input = _buildBatchInput(1);

        assertEq(
            inbox.getCoreState().nextProposalId,
            input.commitment.firstProposalId + 1,
            "nextProposalId"
        );

        uint256 lastProposalId =
            input.commitment.firstProposalId + input.commitment.transitions.length - 1;
        assertEq(lastProposalId, 1, "lastProposalId at exact boundary");

        _prove(input);

        assertEq(inbox.getCoreState().lastFinalizedProposalId, 1, "should finalize");
    }

    function test_prove_RevertWhen_LastProposalIdEqualsNextProposalId() public {
        ProposedEvent memory payload = _proposeOne(); // id = 1, nextProposalId = 2
        uint48 proposalTimestamp = uint48(block.timestamp);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(payload, proposalTimestamp, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(payload, proposalTimestamp, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = _buildInput(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            keccak256("stateRoot")
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(Inbox.LastProposalIdTooLarge.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // ---------------------------------------------------------------------
    // Boundary Tests - Bond timing
    // ---------------------------------------------------------------------
    function test_prove_noBondChange_atExactProvingWindowBoundary() public {
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        vm.warp(proposalTimestamp + config.provingWindow);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(payload, proposalTimestamp, keccak256("checkpoint"));

        IInbox.ProveInput memory input = _buildInput(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            keccak256("stateRoot")
        );

        uint64 proposerBalanceBefore = inbox.getBond(proposer).balance;
        uint64 proverBalanceBefore = inbox.getBond(prover).balance;
        _prove(input);

        assertEq(
            uint256(inbox.getBond(proposer).balance),
            uint256(proposerBalanceBefore),
            "payer unchanged at boundary"
        );
        assertEq(
            uint256(inbox.getBond(prover).balance),
            uint256(proverBalanceBefore),
            "payee unchanged at boundary"
        );
    }

    function test_prove_livenessBond_oneSecondPastProvingWindow() public {
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        vm.warp(proposalTimestamp + config.provingWindow + 1);

        IInbox.Transition[] memory transitions =
            _transitionArrayFor(payload, proposalTimestamp, keccak256("checkpoint"));

        IInbox.ProveInput memory input = _buildInput(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            transitions,
            keccak256("stateRoot")
        );

        uint64 proposerBalanceBefore = inbox.getBond(proposer).balance;
        uint64 proverBalanceBefore = inbox.getBond(prover).balance;
        _prove(input);

        uint64 debited = config.livenessBond;
        uint64 amountToSlash = debited / 2;
        uint64 payeeAmount = debited - amountToSlash;

        assertEq(
            uint256(inbox.getBond(proposer).balance),
            uint256(proposerBalanceBefore - debited),
            "payer debited past window"
        );
        assertEq(
            uint256(inbox.getBond(prover).balance),
            uint256(proverBalanceBefore + payeeAmount),
            "payee credited past window"
        );
    }

    // ---------------------------------------------------------------------
    // Checkpoint syncing (prove always saves a checkpoint)
    // ---------------------------------------------------------------------
    function test_prove_savesCheckpoint() public {
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        uint48 endBlockNumber = uint48(block.number + 123);
        bytes32 endStateRoot = keccak256("stateRoot");
        bytes32 blockHash = keccak256("blockHash");

        IInbox.ProveInput memory input = _buildInputWithCheckpoint(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            _transitionArrayFor(payload, proposalTimestamp, blockHash),
            endBlockNumber,
            endStateRoot
        );
        _prove(input);

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastCheckpointTimestamp, uint48(block.timestamp), "checkpoint timestamp");

        ICheckpointStore.Checkpoint memory checkpoint = signalService.getCheckpoint(endBlockNumber);
        assertEq(checkpoint.blockHash, blockHash, "checkpoint blockHash");
        assertEq(checkpoint.stateRoot, endStateRoot, "checkpoint stateRoot");
    }

    function test_prove_RevertWhen_CheckpointBlockHashZero() public {
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        IInbox.ProveInput memory input = _buildInputWithCheckpoint(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            _transitionArrayFor(payload, proposalTimestamp, bytes32(0)),
            uint48(block.number),
            keccak256("stateRoot")
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_prove_RevertWhen_CheckpointMissing() public {
        ProposedEvent memory payload = _proposeOne();
        uint48 proposalTimestamp = uint48(block.timestamp);

        uint48 endBlockNumber = uint48(block.number);
        bytes32 blockHash = keccak256("blockHash");

        IInbox.ProveInput memory input = _buildInputWithCheckpoint(
            payload.id,
            inbox.getCoreState().lastFinalizedBlockHash,
            _transitionArrayFor(payload, proposalTimestamp, blockHash),
            endBlockNumber,
            bytes32(0)
        );

        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.expectRevert(SignalService.SS_INVALID_CHECKPOINT.selector);
        vm.prank(prover);
        inbox.prove(encodedInput, bytes("proof"));
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------
    function _reduceBondTo(address _account, uint64 _targetBalance) internal {
        uint64 balance = inbox.getBond(_account).balance;
        require(balance >= _targetBalance, "target balance too high");

        vm.startPrank(_account);
        inbox.requestWithdrawal();
        vm.stopPrank();

        vm.warp(block.timestamp + config.withdrawalDelay + 1);

        vm.startPrank(_account);
        inbox.withdraw(_account, balance - _targetBalance);
        vm.stopPrank();
    }

    function _warpPastProvingWindow(uint48 _proposalTimestamp) internal {
        uint256 target = uint256(_proposalTimestamp) + config.provingWindow + 1;
        if (block.timestamp < target) {
            vm.warp(target);
        }
    }

    function _buildInput(
        uint48 _firstProposalId,
        bytes32 _parentBlockHash,
        IInbox.Transition[] memory _transitions,
        bytes32 _endStateRoot
    )
        internal
        view
        returns (IInbox.ProveInput memory)
    {
        uint256 lastProposalId = _firstProposalId + _transitions.length - 1;
        return IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: _firstProposalId,
                firstProposalParentBlockHash: _parentBlockHash,
                lastProposalHash: inbox.getProposalHash(lastProposalId),
                actualProver: prover,
                endBlockNumber: uint48(block.number),
                endStateRoot: _endStateRoot,
                transitions: _transitions
            })
        });
    }

    function _buildInputWithCheckpoint(
        uint48 _firstProposalId,
        bytes32 _parentBlockHash,
        IInbox.Transition[] memory _transitions,
        uint48 _endBlockNumber,
        bytes32 _endStateRoot
    )
        internal
        view
        returns (IInbox.ProveInput memory)
    {
        uint256 lastProposalId = _firstProposalId + _transitions.length - 1;
        return IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: _firstProposalId,
                firstProposalParentBlockHash: _parentBlockHash,
                lastProposalHash: inbox.getProposalHash(lastProposalId),
                actualProver: prover,
                endBlockNumber: _endBlockNumber,
                endStateRoot: _endStateRoot,
                transitions: _transitions
            })
        });
    }

    function _transitionArrayFor(
        ProposedEvent memory _payload,
        uint48 _proposalTimestamp,
        bytes32 _blockHash
    )
        internal
        view
        returns (IInbox.Transition[] memory transitions_)
    {
        transitions_ = new IInbox.Transition[](1);
        transitions_[0] = _transitionFor(_payload, _proposalTimestamp, _blockHash);
    }
}
