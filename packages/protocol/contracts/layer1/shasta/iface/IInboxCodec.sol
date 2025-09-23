// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { IInbox } from "./IInbox.sol";

/// @title IInboxCodec
/// @notice Interface for Inbox encoder/decoder and hashing functions
/// @custom:security-contact security@taiko.xyz
interface IInboxCodec {
    // ---------------------------------------------------------------
    // ProposedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProposedEventPayload into bytes
    /// @param _payload The payload to encode
    /// @return encoded_ The encoded bytes
    function encodeProposedEvent(IInbox.ProposedEventPayload memory _payload)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes bytes into a ProposedEventPayload
    /// @param _data The encoded data
    /// @return payload_ The decoded payload
    function decodeProposedEvent(bytes memory _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_);

    // ---------------------------------------------------------------
    // ProvedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProvedEventPayload into bytes
    /// @param _payload The ProvedEventPayload to encode
    /// @return encoded_ The encoded bytes
    function encodeProvedEvent(IInbox.ProvedEventPayload memory _payload)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes bytes into a ProvedEventPayload
    /// @param _data The bytes to decode
    /// @return payload_ The decoded ProvedEventPayload
    function decodeProvedEvent(bytes memory _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_);

    // ---------------------------------------------------------------
    // ProposeInputDecoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes propose input data
    /// @param _input The ProposeInput to encode
    /// @return encoded_ The encoded data
    function encodeProposeInput(IInbox.ProposeInput memory _input)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes propose data
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput
    function decodeProposeInput(bytes memory _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_);

    // ---------------------------------------------------------------
    // ProveInputDecoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes prove input data
    /// @param _input The ProveInput to encode
    /// @return encoded_ The encoded data
    function encodeProveInput(IInbox.ProveInput memory _input)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes prove input data
    /// @param _data The encoded data
    /// @return input_ The decoded ProveInput
    function decodeProveInput(bytes memory _data)
        external
        pure
        returns (IInbox.ProveInput memory input_);

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Hashing for Checkpoint structs
    /// @param _checkpoint The checkpoint to hash
    /// @return The hash of the checkpoint
    function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        external
        pure
        returns (bytes32);

    /// @notice Hashing for CoreState structs
    /// @param _coreState The core state to hash
    /// @return The hash of the core state
    function hashCoreState(IInbox.CoreState memory _coreState) external pure returns (bytes32);

    /// @notice Hashing for Derivation structs
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivation(IInbox.Derivation memory _derivation) external pure returns (bytes32);

    /// @notice Hashing for Proposal structs
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal memory _proposal) external pure returns (bytes32);

    /// @notice Hashing for Transition structs
    /// @param _transition The transition to hash
    /// @return The hash of the transition
    function hashTransition(IInbox.Transition memory _transition) external pure returns (bytes32);

    /// @notice Hashing for TransitionRecord structs
    /// @param _transitionRecord The transition record to hash
    /// @return The hash truncated to bytes26 for storage optimization
    function hashTransitionRecord(IInbox.TransitionRecord memory _transitionRecord)
        external
        pure
        returns (bytes26);

    /// @notice Hashing for arrays of Transitions
    /// @param _transitions The transitions array to hash
    /// @return The hash of the transitions array
    function hashTransitionsArray(IInbox.Transition[] memory _transitions)
        external
        pure
        returns (bytes32);
}