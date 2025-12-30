// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

contract RejectingReceiver {
    receive() external payable {
        revert("nope");
    }
}

/// @title InboxProverAuctionTest
/// @notice Tests for ProverAuction integration with Inbox
contract InboxProverAuctionTest is InboxTestBase {
    address internal alternateProver = David;

    function setUp() public override {
        super.setUp();
        vm.deal(alternateProver, 100 ether);
    }

    // ---------------------------------------------------------------
    // Propose: Designated Prover Selection Tests
    // ---------------------------------------------------------------

    function test_propose_usesAuctionProver_whenNotSelfProving() public {
        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = false;

        ProposedEvent memory payload = _proposeAndDecode(input);

        assertEq(payload.designatedProver, prover, "designatedProver from auction");
        assertEq(payload.feeInGwei, 0, "feeInGwei is 0 (mock returns 0)");
    }

    function test_propose_usesProposerAsProver_whenSelfProving() public {
        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = true;

        ProposedEvent memory payload = _proposeAndDecode(input);

        assertEq(payload.designatedProver, proposer, "designatedProver is proposer");
        assertEq(payload.feeInGwei, 0, "feeInGwei is 0 for self-proving");
    }

    function test_propose_RevertWhen_SelfProvingWithInsufficientBond() public {
        proverAuction.setBondOk(false);

        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = true;

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.InsufficientBondForSelfProving.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
    }

    function test_propose_RevertWhen_NoActiveAuctionProver() public {
        proverAuction.setCurrentProver(address(0));

        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = false;

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.NoActiveAuctionProver.selector);
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
    }

    // ---------------------------------------------------------------
    // Propose: Prover Fee Payment Tests
    // ---------------------------------------------------------------

    function test_propose_paysProverFee() public {
        uint32 feeInGwei = 1_000_000; // 0.001 ETH
        proverAuction.setCurrentFeeInGwei(feeInGwei);

        uint256 proverBalanceBefore = prover.balance;
        uint256 proposerBalanceBefore = proposer.balance;
        uint256 feeWei = uint256(feeInGwei) * 1 gwei;

        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = false;

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.prank(proposer);
        inbox.propose{ value: feeWei }(bytes(""), encodedInput);

        assertEq(prover.balance, proverBalanceBefore + feeWei, "prover received fee");
        assertEq(proposer.balance, proposerBalanceBefore - feeWei, "proposer paid fee");
    }

    function test_propose_refundsExcessFee() public {
        uint32 feeInGwei = 1_000_000; // 0.001 ETH
        proverAuction.setCurrentFeeInGwei(feeInGwei);

        uint256 feeWei = uint256(feeInGwei) * 1 gwei;
        uint256 excessWei = 0.5 ether;
        uint256 proposerBalanceBefore = proposer.balance;

        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = false;

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.prank(proposer);
        inbox.propose{ value: feeWei + excessWei }(bytes(""), encodedInput);

        // Proposer should only lose feeWei, excess should be refunded
        assertEq(proposer.balance, proposerBalanceBefore - feeWei, "excess refunded");
    }

    function test_propose_RevertWhen_ProverFeeNotPaid() public {
        uint32 feeInGwei = 1_000_000; // 0.001 ETH
        proverAuction.setCurrentFeeInGwei(feeInGwei);

        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = false;

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.ProverFeeNotPaid.selector);
        vm.prank(proposer);
        inbox.propose{ value: 0 }(bytes(""), encodedInput); // No fee sent
    }

    function test_propose_RevertWhen_ProverFeePartiallyPaid() public {
        uint32 feeInGwei = 1_000_000; // 0.001 ETH
        proverAuction.setCurrentFeeInGwei(feeInGwei);

        uint256 feeWei = uint256(feeInGwei) * 1 gwei;

        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = false;

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.expectRevert(Inbox.ProverFeeNotPaid.selector);
        vm.prank(proposer);
        inbox.propose{ value: feeWei - 1 }(bytes(""), encodedInput); // 1 wei short
    }

    function test_propose_noFeeRequired_whenSelfProving() public {
        uint32 feeInGwei = 1_000_000; // 0.001 ETH
        proverAuction.setCurrentFeeInGwei(feeInGwei);

        uint256 proposerBalanceBefore = proposer.balance;

        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = true;

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.prank(proposer);
        inbox.propose{ value: 0 }(bytes(""), encodedInput);

        // No fee should be deducted for self-proving
        assertEq(proposer.balance, proposerBalanceBefore, "no fee for self-proving");
    }

    function test_propose_noFeeRequired_whenFeeIsZero() public {
        proverAuction.setCurrentFeeInGwei(0);

        uint256 proposerBalanceBefore = proposer.balance;

        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = false;

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.prank(proposer);
        inbox.propose{ value: 0 }(bytes(""), encodedInput);

        assertEq(proposer.balance, proposerBalanceBefore, "no fee when zero");
    }

    function test_propose_refundsFee_whenProverRejectsEther() public {
        RejectingReceiver rejector = new RejectingReceiver();
        proverAuction.setCurrentProver(address(rejector));
        proverAuction.setCurrentFeeInGwei(1_000_000); // 0.001 ETH

        uint256 feeWei = 1_000_000 * 1 gwei;
        uint256 proposerBalanceBefore = proposer.balance;

        _setBlobHashes(3);
        IInbox.ProposeInput memory input = _defaultProposeInput();
        input.isSelfProving = false;

        bytes memory encodedInput = codec.encodeProposeInput(input);

        vm.prank(proposer);
        inbox.propose{ value: feeWei }(bytes(""), encodedInput);

        assertEq(proposer.balance, proposerBalanceBefore, "fee refunded on reject");
    }

    // ---------------------------------------------------------------
    // Prove: Slashing Tests
    // ---------------------------------------------------------------

    function test_prove_slashesDesignatedProver_whenLateAndDifferentProver() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);

        // Warp past the proving window + maxProofSubmissionDelay
        vm.warp(block.timestamp + config.provingWindow + config.maxProofSubmissionDelay + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposer,
            designatedProver: proverAuction.currentProver(),
            timestamp: p1Timestamp,
            blockHash: keccak256("checkpoint1")
        });

        IInbox.ProveInput memory input = _buildInputWithProver(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, transitions, alternateProver
        );

        _proveAs(alternateProver, input);

        assertEq(proverAuction.lastSlashedProver(), transitions[0].designatedProver, "slashed");
        assertEq(proverAuction.lastSlashRecipient(), alternateProver, "rewarded");
    }

    function test_prove_doesNotSlash_whenOnTime() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);

        // Don't warp - prove immediately (on time)

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposer,
            designatedProver: proverAuction.currentProver(),
            timestamp: p1Timestamp,
            blockHash: keccak256("checkpoint1")
        });

        IInbox.ProveInput memory input = _buildInputWithProver(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, transitions, alternateProver
        );

        _proveAs(alternateProver, input);

        assertEq(proverAuction.lastSlashedProver(), address(0), "not slashed");
        assertEq(proverAuction.lastSlashRecipient(), address(0), "no reward");
    }

    function test_prove_slashes_whenLateAndSameProver() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);

        vm.warp(block.timestamp + config.provingWindow + config.maxProofSubmissionDelay + 1);

        address designatedProver = proverAuction.currentProver();

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposer,
            designatedProver: designatedProver,
            timestamp: p1Timestamp,
            blockHash: keccak256("checkpoint1")
        });

        // Actual prover is the same as designated prover
        IInbox.ProveInput memory input = _buildInputWithProver(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, transitions, designatedProver
        );

        _proveAs(designatedProver, input);

        assertEq(proverAuction.lastSlashedProver(), designatedProver, "slashed even when same prover");
        assertEq(proverAuction.lastSlashRecipient(), designatedProver, "rewarded same prover");
    }

    function test_prove_doesNotSlash_whenAtExactDeadline() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);

        // Warp to exactly the deadline (provingWindow)
        vm.warp(p1Timestamp + config.provingWindow);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposer,
            designatedProver: proverAuction.currentProver(),
            timestamp: p1Timestamp,
            blockHash: keccak256("checkpoint1")
        });

        IInbox.ProveInput memory input = _buildInputWithProver(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, transitions, alternateProver
        );

        _proveAs(alternateProver, input);

        assertEq(proverAuction.lastSlashedProver(), address(0), "not slashed at exact deadline");
    }

    function test_prove_slashes_whenOneSecondPastDeadline() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);

        // Warp to one second past the deadline
        vm.warp(p1Timestamp + config.provingWindow + config.maxProofSubmissionDelay + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: p1.proposer,
            designatedProver: proverAuction.currentProver(),
            timestamp: p1Timestamp,
            blockHash: keccak256("checkpoint1")
        });

        IInbox.ProveInput memory input = _buildInputWithProver(
            p1.id, inbox.getCoreState().lastFinalizedBlockHash, transitions, alternateProver
        );

        _proveAs(alternateProver, input);

        assertEq(
            proverAuction.lastSlashedProver(),
            transitions[0].designatedProver,
            "slashed 1s past deadline"
        );
    }

    // ---------------------------------------------------------------
    // Helpers (private)
    // ---------------------------------------------------------------

    function _proveAs(address _proverAddr, IInbox.ProveInput memory _input) private {
        bytes memory encodedInput = codec.encodeProveInput(_input);
        vm.prank(_proverAddr);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function _buildInputWithProver(
        uint48 _firstProposalId,
        bytes32 _parentBlockHash,
        IInbox.Transition[] memory _transitions,
        address _actualProver
    )
        private
        view
        returns (IInbox.ProveInput memory)
    {
        uint256 lastProposalId = _firstProposalId + _transitions.length - 1;
        return IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: _firstProposalId,
                firstProposalParentBlockHash: _parentBlockHash,
                lastProposalHash: inbox.getProposalHash(lastProposalId),
                actualProver: _actualProver,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256(abi.encode("stateRoot")),
                transitions: _transitions
            }),
            forceCheckpointSync: false
        });
    }
}
