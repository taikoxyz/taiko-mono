// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IInboxCodec } from "../iface/IInboxCodec.sol";
import { LibHashing } from "../libs/LibHashing.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";

/// @title InboxOptimized2Codec
/// @notice Codec contract for InboxOptimized2 with optimized encoder/decoder and hashing library
/// functions
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized2Codec is IInboxCodec {
    // ---------------------------------------------------------------
    // ProposedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInboxCodec
    function encodeProposedEvent(IInbox.ProposedEventPayload memory _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProposedEventEncoder.encode(_payload);
    }

    /// @inheritdoc IInboxCodec
    function decodeProposedEvent(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        return LibProposedEventEncoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProvedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInboxCodec
    function encodeProvedEvent(IInbox.ProvedEventPayload memory _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProvedEventEncoder.encode(_payload);
    }

    /// @inheritdoc IInboxCodec
    function decodeProvedEvent(bytes calldata _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        return LibProvedEventEncoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProposeInputDecoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInboxCodec
    function encodeProposeInput(IInbox.ProposeInput memory _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProposeInputDecoder.encode(_input);
    }

    /// @inheritdoc IInboxCodec
    function decodeProposeInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        return LibProposeInputDecoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProveInputDecoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInboxCodec
    function encodeProveInput(IInbox.ProveInput memory _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProveInputDecoder.encode(_input);
    }

    /// @inheritdoc IInboxCodec
    function decodeProveInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProveInput memory input_)
    {
        return LibProveInputDecoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // LibHashing Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInboxCodec
    function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        external
        pure
        returns (bytes32)
    {
        return LibHashing.hashCheckpoint(_checkpoint);
    }

    /// @inheritdoc IInboxCodec
    function hashCoreState(IInbox.CoreState memory _coreState) external pure returns (bytes32) {
        return LibHashing.hashCoreState(_coreState);
    }

    /// @inheritdoc IInboxCodec
    function hashDerivation(IInbox.Derivation memory _derivation) external pure returns (bytes32) {
        return LibHashing.hashDerivation(_derivation);
    }

    /// @inheritdoc IInboxCodec
    function hashProposal(IInbox.Proposal memory _proposal) external pure returns (bytes32) {
        return LibHashing.hashProposal(_proposal);
    }

    /// @inheritdoc IInboxCodec
    function hashTransition(IInbox.Transition memory _transition) external pure returns (bytes32) {
        return LibHashing.hashTransition(_transition);
    }

    /// @inheritdoc IInboxCodec
    function hashTransitionRecord(IInbox.TransitionRecord memory _transitionRecord)
        external
        pure
        returns (bytes26)
    {
        return LibHashing.hashTransitionRecord(_transitionRecord);
    }

    /// @inheritdoc IInboxCodec
    function hashTransitionsArray(IInbox.Transition[] memory _transitions)
        external
        pure
        returns (bytes32)
    {
        return LibHashing.hashTransitionsArray(_transitions);
    }
}
