// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
import { IInbox } from "../iface/IInbox.sol";

/// @title InboxCodex
/// @notice Unified codec contract for all Inbox encoder/decoder library functions
/// @dev Provides a single interface to access all LibXXXEncoder and LibXXXDecoder functionality
/// @custom:security-contact security@taiko.xyz
contract InboxCodex {
    // ---------------------------------------------------------------
    // ProposedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProposedEventPayload into bytes using compact encoding
    /// @param _payload The payload to encode
    /// @return encoded_ The encoded bytes
    function encodeProposedEvent(IInbox.ProposedEventPayload memory _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProposedEventEncoder.encode(_payload);
    }

    /// @notice Decodes bytes into a ProposedEventPayload using compact encoding
    /// @param _data The encoded data
    /// @return payload_ The decoded payload
    function decodeProposedEvent(bytes memory _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        return LibProposedEventEncoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProvedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProvedEventPayload into bytes using compact encoding
    /// @param _payload The ProvedEventPayload to encode
    /// @return encoded_ The encoded bytes
    function encodeProvedEvent(IInbox.ProvedEventPayload memory _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProvedEventEncoder.encode(_payload);
    }

    /// @notice Decodes bytes into a ProvedEventPayload using compact encoding
    /// @param _data The bytes to decode
    /// @return payload_ The decoded ProvedEventPayload
    function decodeProvedEvent(bytes memory _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        return LibProvedEventEncoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProposeInputDecoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes propose input data using standard ABI encoding (compatible with all Inbox implementations)
    /// @param _input The ProposeInput to encode
    /// @return encoded_ The encoded data
    function encodeProposeInput(IInbox.ProposeInput memory _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_input);
    }

    /// @notice Decodes propose data using standard ABI decoding
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput
    function decodeProposeInput(bytes memory _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        return abi.decode(_data, (IInbox.ProposeInput));
    }

    /// @notice Encodes propose input data using optimized encoding (for InboxOptimized3+)
    /// @param _input The ProposeInput to encode
    /// @return encoded_ The encoded data
    function encodeProposeInputOptimized(IInbox.ProposeInput memory _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProposeInputDecoder.encode(_input);
    }

    /// @notice Decodes propose data using optimized operations
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput
    function decodeProposeInputOptimized(bytes memory _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        return LibProposeInputDecoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProveInputDecoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes prove input data using standard ABI encoding (compatible with all Inbox implementations)
    /// @param _input The ProveInput to encode
    /// @return encoded_ The encoded data
    function encodeProveInput(IInbox.ProveInput memory _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_input);
    }

    /// @notice Decodes prove input data using standard ABI decoding
    /// @param _data The encoded data
    /// @return input_ The decoded ProveInput
    function decodeProveInput(bytes memory _data)
        external
        pure
        returns (IInbox.ProveInput memory input_)
    {
        return abi.decode(_data, (IInbox.ProveInput));
    }

    /// @notice Encodes prove input data using optimized encoding (for InboxOptimized3+)
    /// @param _input The ProveInput to encode
    /// @return encoded_ The encoded data
    function encodeProveInputOptimized(IInbox.ProveInput memory _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProveInputDecoder.encode(_input);
    }

    /// @notice Decodes prove input data using optimized operations
    /// @param _data The encoded data
    /// @return input_ The decoded ProveInput
    function decodeProveInputOptimized(bytes memory _data)
        external
        pure
        returns (IInbox.ProveInput memory input_)
    {
        return LibProveInputDecoder.decode(_data);
    }
}