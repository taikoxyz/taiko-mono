// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "./IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title ICodec
/// @notice Interface for Inbox encoder/decoder and hashing functions
/// @dev Input validation assumptions:
/// - All decode functions may revert on malformed input data
/// - Array inputs should be bounded to prevent excessive gas usage
/// - Struct fields are not validated for business logic constraints
/// - Hash functions assume well-formed input structures
/// @dev Compatibility warning:
/// - Different codec implementations produce INCOMPATIBLE encoded outputs and hashes for the same
/// inputs
/// - Codec implementations cannot be used interchangeably
/// - System upgrades between codec types require careful migration planning
/// @custom:security-contact security@taiko.xyz
interface ICodec {
    // ---------------------------------------------------------------
    // ProposedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProposedEventPayload into bytes
    /// @param _payload The payload to encode
    /// @return encoded_ The encoded bytes
    function encodeProposedEvent(IInbox.ProposedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes bytes into a ProposedEventPayload
    /// @param _data The encoded data
    /// @return payload_ The decoded payload
    /// @dev Reverts on malformed or truncated input data
    function decodeProposedEvent(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_);

    // ---------------------------------------------------------------
    // ProvedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProvedEventPayload into bytes
    /// @param _payload The ProvedEventPayload to encode
    /// @return encoded_ The encoded bytes
    function encodeProvedEvent(IInbox.ProvedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes bytes into a ProvedEventPayload
    /// @param _data The bytes to decode
    /// @return payload_ The decoded ProvedEventPayload
    /// @dev Reverts on malformed or truncated input data
    function decodeProvedEvent(bytes calldata _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_);

    // ---------------------------------------------------------------
    // ProposeInputDecoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes propose input data
    /// @param _input The ProposeInput to encode
    /// @return encoded_ The encoded data
    function encodeProposeInput(IInbox.ProposeInput calldata _input)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes propose data
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput
    /// @dev Reverts on malformed or truncated input data
    function decodeProposeInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_);

    // ---------------------------------------------------------------
    // ProveInputDecoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes prove input data
    /// @param _input The ProveInput to encode
    /// @return encoded_ The encoded data
    function encodeProveInput(IInbox.ProveInput calldata _input)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes prove input data
    /// @param _data The encoded data
    /// @return input_ The decoded ProveInput
    /// @dev Reverts on malformed or truncated input data
    function decodeProveInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProveInput memory input_);

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Hashing for Checkpoint structs
    /// @param _checkpoint The checkpoint to hash
    /// @return The hash of the checkpoint
    function hashCheckpoint(ICheckpointStore.Checkpoint calldata _checkpoint)
        external
        pure
        returns (bytes32);

    /// @notice Hashing for CoreState structs
    /// @param _coreState The core state to hash
    /// @return The hash of the core state
    function hashCoreState(IInbox.CoreState calldata _coreState) external pure returns (bytes32);

    /// @notice Hashing for Derivation structs
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivation(IInbox.Derivation calldata _derivation) external pure returns (bytes32);

    /// @notice Hashing for Proposal structs
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal calldata _proposal) external pure returns (bytes32);

    /// @notice Hashing for Transition structs
    /// @param _transition The transition to hash
    /// @return The hash of the transition
    function hashTransition(IInbox.Transition calldata _transition) external pure returns (bytes32);

    /// @notice Hashing for TransitionRecord structs
    /// @param _transitionRecord The transition record to hash
    /// @return The hash truncated to bytes26 for storage optimization
    /// @dev Truncation to bytes26 reduces collision resistance compared to full bytes32
    function hashTransitionRecord(IInbox.TransitionRecord calldata _transitionRecord)
        external
        pure
        returns (bytes26);

    /// @notice Hashing for arrays of Transitions
    /// @param _transitions The transitions array to hash
    /// @param _metadata The metadata array to hash
    /// @return The hash of the transitions array
    /// @dev Large arrays may cause excessive gas usage or out-of-gas errors
    function hashTransitionsWithMetadata(
        IInbox.Transition[] calldata _transitions,
        IInbox.TransitionMetadata[] calldata _metadata
    )
        external
        pure
        returns (bytes32);
}
