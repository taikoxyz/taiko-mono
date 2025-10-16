// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICodec } from "../iface/ICodec.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibHashOptimized } from "../libs/LibHashOptimized.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title CodecOptimized
/// @notice Codec contract wrapping LibHashOptimized for optimized hashing
/// @custom:security-contact security@taiko.xyz
contract CodecOptimized is ICodec {
    // ---------------------------------------------------------------
    // ProposedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function encodeProposedEvent(IInbox.ProposedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProposedEventEncoder.encode(_payload);
    }

    /// @inheritdoc ICodec
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

    /// @inheritdoc ICodec
    function encodeProvedEvent(IInbox.ProvedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProvedEventEncoder.encode(_payload);
    }

    /// @inheritdoc ICodec
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

    /// @inheritdoc ICodec
    function encodeProposeInput(IInbox.ProposeInput calldata _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProposeInputDecoder.encode(_input);
    }

    /// @inheritdoc ICodec
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

    /// @inheritdoc ICodec
    function encodeProveInput(IInbox.ProveInput calldata _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProveInputDecoder.encode(_input);
    }

    /// @inheritdoc ICodec
    function decodeProveInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProveInput memory input_)
    {
        return LibProveInputDecoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function hashCheckpoint(ICheckpointStore.Checkpoint calldata _checkpoint)
        external
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashCheckpoint(_checkpoint);
    }

    /// @inheritdoc ICodec
    function hashCoreState(IInbox.CoreState calldata _coreState) external pure returns (bytes32) {
        return LibHashOptimized.hashCoreState(_coreState);
    }

    /// @inheritdoc ICodec
    function hashDerivation(IInbox.Derivation calldata _derivation)
        external
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashDerivation(_derivation);
    }

    /// @inheritdoc ICodec
    function hashProposal(IInbox.Proposal calldata _proposal) external pure returns (bytes32) {
        return LibHashOptimized.hashProposal(_proposal);
    }

    /// @inheritdoc ICodec
    function hashTransition(IInbox.Transition calldata _transition)
        external
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashTransition(_transition);
    }

    /// @inheritdoc ICodec
    function hashTransitionRecord(IInbox.TransitionRecord calldata _transitionRecord)
        external
        pure
        returns (bytes26)
    {
        return LibHashOptimized.hashTransitionRecord(_transitionRecord);
    }

    /// @inheritdoc ICodec
    function hashTransitionsWithMetadata(
        IInbox.Transition[] calldata _transitions,
        IInbox.TransitionMetadata[] calldata _metadata
    )
        external
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashTransitionsWithMetadata(_transitions, _metadata);
    }
}
