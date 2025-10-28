// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestInboxOptimized2 } from "../implementations/TestInboxOptimized2.sol";
import { AbstractInitTest } from "./AbstractInit.t.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibHashOptimized } from "src/layer1/core/libs/LibHashOptimized.sol";
import { LibProposedEventEncoder } from "src/layer1/core/libs/LibProposedEventEncoder.sol";

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
        pure
        override
        returns (IInbox.ProposedEventPayload memory)
    {
        return LibProposedEventEncoder.decode(data);
    }

    function _expectedTransitionHash(bytes32 genesisHash) internal pure override returns (bytes32) {
        IInbox.Transition memory transition;
        transition.checkpoint.blockHash = genesisHash;
        return LibHashOptimized.hashTransition(transition);
    }

    function _expectedProposalHash(IInbox.Proposal memory proposal)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashProposal(proposal);
    }
}
