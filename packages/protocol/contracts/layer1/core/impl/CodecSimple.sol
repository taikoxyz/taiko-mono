// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICodec } from "../iface/ICodec.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibHashSimple } from "../libs/LibHashSimple.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title CodecSimple
/// @notice Codec contract wrapping LibHashSimple for basic hashing
/// @custom:security-contact security@taiko.xyz
contract CodecSimple is ICodec {
    // ---------------------------------------------------------------
    // ProposedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function encodeProposedEvent(IInbox.ProposedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_payload);
    }

    /// @inheritdoc ICodec
    function decodeProposedEvent(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        return abi.decode(_data, (IInbox.ProposedEventPayload));
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
        return abi.encode(_payload);
    }

    /// @inheritdoc ICodec
    function decodeProvedEvent(bytes calldata _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        return abi.decode(_data, (IInbox.ProvedEventPayload));
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
        return abi.encode(_input);
    }

    /// @inheritdoc ICodec
    function decodeProposeInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        return abi.decode(_data, (IInbox.ProposeInput));
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
        return abi.encode(_input);
    }

    /// @inheritdoc ICodec
    function decodeProveInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProveInput memory input_)
    {
        return abi.decode(_data, (IInbox.ProveInput));
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
        return LibHashSimple.hashCheckpoint(_checkpoint);
    }

    /// @inheritdoc ICodec
    function hashCoreState(IInbox.CoreState calldata _coreState) external pure returns (bytes32) {
        return LibHashSimple.hashCoreState(_coreState);
    }

    /// @inheritdoc ICodec
    function hashDerivation(IInbox.Derivation calldata _derivation)
        external
        pure
        returns (bytes32)
    {
        return LibHashSimple.hashDerivation(_derivation);
    }

    /// @inheritdoc ICodec
    function hashProposal(IInbox.Proposal calldata _proposal) external pure returns (bytes32) {
        return LibHashSimple.hashProposal(_proposal);
    }

    /// @inheritdoc ICodec
    function hashTransition(IInbox.Transition calldata _transition)
        external
        pure
        returns (bytes32)
    {
        return LibHashSimple.hashTransition(_transition);
    }

    /// @inheritdoc ICodec
    function hashTransitionRecord(IInbox.TransitionRecord calldata _transitionRecord)
        external
        pure
        returns (bytes26)
    {
        return LibHashSimple.hashTransitionRecord(_transitionRecord);
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
        return LibHashSimple.hashTransitionsWithMetadata(_transitions, _metadata);
    }
}
