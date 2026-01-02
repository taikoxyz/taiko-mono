// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "./IInbox.sol";

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
    // ProposalCodec Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a proposal (without the id field) for event emission
    /// @param _proposal The Proposal to encode
    /// @return encoded_ The encoded data (excludes proposal id)
    function encodeProposal(IInbox.Proposal calldata _proposal)
        external
        pure
        returns (bytes memory encoded_);

    /// @notice Decodes proposal data (without the id field)
    /// @param _data The encoded data
    /// @return proposal_ The decoded Proposal (id will be 0, should be set separately)
    /// @dev Reverts on malformed or truncated input data
    function decodeProposal(bytes calldata _data)
        external
        pure
        returns (IInbox.Proposal memory proposal_);

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

    /// @notice Hashing for Proposal structs
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal calldata _proposal) external pure returns (bytes32);

    /// @notice Hashing for commitment data
    /// @param _commitment The commitment data to hash
    /// @return The hash of the commitment
    function hashCommitment(IInbox.Commitment calldata _commitment) external pure returns (bytes32);
}
