// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibHashOptimized } from "../libs/LibHashOptimized.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";
import { Inbox } from "./Inbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

import "./InboxOptimized_Layout.sol"; // DO NOT DELETE

/// @title InboxOptimized
/// @notice Inbox variant that uses compact encoders/decoders and optimized hashing.
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized is Inbox {
    constructor(IInbox.Config memory _config) Inbox(_config) { }

    function _encodeProposedEventData(ProposedEventPayload memory _payload)
        internal
        pure
        override
        returns (bytes memory)
    {
        return LibProposedEventEncoder.encode(_payload);
    }

    function _encodeProvedEventData(ProvedEventPayload memory _payload)
        internal
        pure
        override
        returns (bytes memory)
    {
        return LibProvedEventEncoder.encode(_payload);
    }

    function _decodeProposeInput(bytes calldata _data)
        internal
        pure
        override
        returns (ProposeInput memory)
    {
        return LibProposeInputDecoder.decode(_data);
    }

    function _decodeProveInput(bytes calldata _data)
        internal
        pure
        override
        returns (ProveInput memory)
    {
        return LibProveInputDecoder.decode(_data);
    }

    function _hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashCheckpoint(_checkpoint);
    }

    function _hashDerivation(Derivation memory _derivation)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashDerivation(_derivation);
    }

    function _hashProposal(Proposal memory _proposal) internal pure override returns (bytes32) {
        return LibHashOptimized.hashProposal(_proposal);
    }

    function _hashTransition(Transition memory _transition)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashTransition(_transition);
    }

    function _hashTransitions(Transition[] memory _transitions)
        internal
        pure
        override
        returns (bytes32)
    {
        return LibHashOptimized.hashTransitions(_transitions);
    }
}
