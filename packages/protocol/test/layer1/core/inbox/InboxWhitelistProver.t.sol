// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";

contract InboxProverAuctionTest is InboxTestBase {
    address internal alternateProver = David;

    function test_prove_slashesDesignatedProver_whenLateAndDifferentProver() public {
        ProposedEvent memory p1 = _proposeOne();
        uint48 p1Timestamp = uint48(block.timestamp);

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

    // ---------------------------------------------------------------------
    // Helpers (private)
    // ---------------------------------------------------------------------

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
