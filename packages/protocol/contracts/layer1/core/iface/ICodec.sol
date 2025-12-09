// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "./IInbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

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
    // ProposedEventCodec Functions
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
    // ProvedEventCodec Functions
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
    // ProposeInputCodec Functions
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
    // ProveInputCodec Functions
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

    /// @notice Hashing for Derivation structs
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivation(IInbox.Derivation calldata _derivation) external pure returns (bytes32);

    /// @notice Hashing for Proposal structs
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal calldata _proposal) external pure returns (bytes32);

    /// @notice Hashing for BondInstruction structs
    /// @param _bondInstruction The bond instruction to hash
    /// @return The hash of the bond instruction
    function hashBondInstruction(LibBonds.BondInstruction calldata _bondInstruction)
        external
        pure
        returns (bytes32);

    /// @notice Hashing for ProveInput structs
    /// @param _input The prove input to hash
    /// @return The hash of the prove input
    function hashProveInput(IInbox.ProveInput calldata _input) external pure returns (bytes32);
}
