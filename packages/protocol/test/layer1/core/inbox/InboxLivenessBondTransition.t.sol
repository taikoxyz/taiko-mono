// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";

contract InboxLivenessBondTransitionTest is InboxTestBase {
    function test_prove_refundsPerProposalBond_acrossUpgrade() public {
        uint256 oldBond = inbox.getConfig().livenessBond;

        ProposedEvent memory p1 = _proposeOne();
        uint48 t1 = uint48(block.timestamp);
        _advanceBlock();

        ProposedEvent memory p2 = _proposeOne();
        uint48 t2 = uint48(block.timestamp);
        _advanceBlock();

        uint256 newBond = oldBond + 2 ether;
        _upgradeToLivenessBond(newBond);
        _advanceBlock();

        ProposedEvent memory p3 = _proposeOne();
        uint48 t3 = uint48(block.timestamp);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](3);
        transitions[0] = _transitionFor(p1, t1, prover, oldBond, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(p2, t2, prover, oldBond, keccak256("checkpoint2"));
        transitions[2] = _transitionFor(p3, t3, prover, newBond, keccak256("checkpoint3"));

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: p1.id,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(p3.id),
                actualProver: prover,
                endBlockNumber: 0,
                endStateRoot: bytes32(0),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        uint256 proposerBalanceBefore = bondManager.getBondBalance(proposer);
        uint256 proverBalanceBefore = bondManager.getBondBalance(prover);

        _prove(input);

        assertEq(
            bondManager.getBondBalance(proposer),
            proposerBalanceBefore + (oldBond * 2) + newBond,
            "proposer refund mismatch"
        );
        assertEq(bondManager.getBondBalance(prover), proverBalanceBefore, "prover unchanged");
        assertEq(bondManager.getBondBalance(proposer), INITIAL_BOND, "proposer balance restored");
    }

    function test_prove_slashesUsingPerProposalBond_acrossUpgrade() public {
        uint256 oldBond = inbox.getConfig().livenessBond;

        ProposedEvent memory p1 = _proposeOne();
        uint48 t1 = uint48(block.timestamp);
        _advanceBlock();

        uint256 newBond = oldBond + 2 ether;
        _upgradeToLivenessBond(newBond);
        _advanceBlock();

        ProposedEvent memory p2 = _proposeOne();
        uint48 t2 = uint48(block.timestamp);

        vm.warp(uint256(t1) + config.provingWindow + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(p1, t1, prover, oldBond, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(p2, t2, prover, newBond, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: p1.id,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(p2.id),
                actualProver: prover,
                endBlockNumber: 0,
                endStateRoot: bytes32(0),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        uint256 proposerBalanceBefore = bondManager.getBondBalance(proposer);
        uint256 proverBalanceBefore = bondManager.getBondBalance(prover);

        _prove(input);

        assertEq(
            bondManager.getBondBalance(proposer),
            proposerBalanceBefore + newBond,
            "proposer refund mismatch"
        );
        assertEq(
            bondManager.getBondBalance(prover),
            proverBalanceBefore + oldBond / 2,
            "prover reward mismatch"
        );
        assertEq(bondManager.getBondBalance(proposer), INITIAL_BOND - oldBond, "final balance");
    }

    function test_prove_refundsOldBondWhenNewBondIsZero() public {
        uint256 oldBond = inbox.getConfig().livenessBond;

        ProposedEvent memory p1 = _proposeOne();
        uint48 t1 = uint48(block.timestamp);
        _advanceBlock();

        _upgradeToLivenessBond(0);
        _advanceBlock();

        ProposedEvent memory p2 = _proposeOne();
        uint48 t2 = uint48(block.timestamp);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = _transitionFor(p1, t1, prover, oldBond, keccak256("checkpoint1"));
        transitions[1] = _transitionFor(p2, t2, prover, 0, keccak256("checkpoint2"));

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: p1.id,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(p2.id),
                actualProver: prover,
                endBlockNumber: 0,
                endStateRoot: bytes32(0),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        uint256 proposerBalanceBefore = bondManager.getBondBalance(proposer);
        _prove(input);

        assertEq(
            bondManager.getBondBalance(proposer),
            proposerBalanceBefore + oldBond,
            "proposer refund mismatch"
        );
        assertEq(bondManager.getBondBalance(proposer), INITIAL_BOND, "proposer balance restored");
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _upgradeToLivenessBond(uint256 _newBond) private {
        IInbox.Config memory newConfig = config;
        newConfig.livenessBond = _newBond;
        inbox.upgradeTo(address(new Inbox(newConfig)));
    }
}

