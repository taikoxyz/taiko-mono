// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IInboxCodec } from "../iface/IInboxCodec.sol";

/// @title InboxCodec
/// @notice Codec contract for standard Inbox with abi.encode/decode and keccak256 hashing
/// functions
/// @dev This implementation matches the encoding/decoding/hashing methods used in Inbox.sol
/// @custom:security-contact security@taiko.xyz
contract InboxCodec is IInboxCodec {
    // ---------------------------------------------------------------
    // ProposedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInboxCodec
    function encodeProposedEvent(IInbox.ProposedEventPayload memory _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_payload);
    }

    /// @inheritdoc IInboxCodec
    function decodeProposedEvent(bytes memory _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        return abi.decode(_data, (IInbox.ProposedEventPayload));
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
        return abi.encode(_payload);
    }

    /// @inheritdoc IInboxCodec
    function decodeProvedEvent(bytes memory _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        return abi.decode(_data, (IInbox.ProvedEventPayload));
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
        return abi.encode(_input);
    }

    /// @inheritdoc IInboxCodec
    function decodeProposeInput(bytes memory _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        return abi.decode(_data, (IInbox.ProposeInput));
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
        return abi.encode(_input);
    }

    /// @inheritdoc IInboxCodec
    function decodeProveInput(bytes memory _data)
        external
        pure
        returns (IInbox.ProveInput memory input_)
    {
        return abi.decode(_data, (IInbox.ProveInput));
    }

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInboxCodec
    function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_checkpoint));
    }

    /// @inheritdoc IInboxCodec
    function hashCoreState(IInbox.CoreState memory _coreState) external pure returns (bytes32) {
        return keccak256(abi.encode(_coreState));
    }

    /// @inheritdoc IInboxCodec
    function hashDerivation(IInbox.Derivation memory _derivation) external pure returns (bytes32) {
        return keccak256(abi.encode(_derivation));
    }

    /// @inheritdoc IInboxCodec
    function hashProposal(IInbox.Proposal memory _proposal) external pure returns (bytes32) {
        return keccak256(abi.encode(_proposal));
    }

    /// @inheritdoc IInboxCodec
    function hashTransition(IInbox.Transition memory _transition) external pure returns (bytes32) {
        return keccak256(abi.encode(_transition));
    }

    /// @inheritdoc IInboxCodec
    function hashTransitionRecord(IInbox.TransitionRecord memory _transitionRecord)
        external
        pure
        returns (bytes26)
    {
        return bytes26(keccak256(abi.encode(_transitionRecord)));
    }

    /// @inheritdoc IInboxCodec
    function hashTransitionsArray(IInbox.Transition[] memory _transitions)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_transitions));
    }
}