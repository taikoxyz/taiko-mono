// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { TestInboxOptimized2 } from "../implementations/TestInboxOptimized2.sol";
import { AbstractInitTest } from "./AbstractInit.t.sol";
import { LibProposedEventEncoder } from "src/layer1/core/libs/LibProposedEventEncoder.sol";
import { LibHashOptimized } from "src/layer1/core/libs/LibHashOptimized.sol";

contract InboxOptimized2Init is AbstractInitTest {
    function _deployImplementation() internal override returns (Inbox) {
        return new TestInboxOptimized2(
            address(codec),
            address(bondToken),
            address(checkpointManager),
            address(proofVerifier),
            address(proposerChecker)
        );
    }

    function _decodeEvent(bytes memory data)
        internal
        view
        override
        returns (IInbox.ProposedEventPayload memory)
    {
        return LibProposedEventEncoder.decode(data);
    }

    function _expectedTransitionHash(bytes32 genesisHash) internal view override returns (bytes32) {
        IInbox.Transition memory transition;
        transition.checkpoint.blockHash = genesisHash;
        return LibHashOptimized.hashTransition(transition);
    }

    function _expectedProposalHash(IInbox.Proposal memory proposal)
        internal
        view
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashProposal(proposal);
    }
}
