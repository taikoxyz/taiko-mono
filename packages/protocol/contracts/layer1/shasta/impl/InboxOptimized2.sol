// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { IInbox } from "../iface/IInbox.sol";
import { InboxOptimized1 } from "./InboxOptimized1.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";

/// @title InboxOptimized2
/// @notice Second optimization layer with merged event and calldata optimizations
/// @dev Key optimizations:
///      - Custom event encoding using LibProposedEventEncoder and LibProvedEventEncoder
///      - Compact binary representation for event data
///      - Reduced calldata size for events
///      - Custom calldata encoding for propose and prove inputs
///      - Compact binary representation using LibProposeInputDecoder and LibProveInputDecoder
///      - Reduced transaction costs through efficient data packing
///      - Maintains all optimizations from InboxOptimized1
/// @dev Gas savings: ~40% reduction in calldata costs for propose/prove operations
/// @dev DEPLOYMENT: REQUIRED to use FOUNDRY_PROFILE=layer1o for deployment. Contract exceeds
///      24KB limit without via_ir optimization. Regular compilation will fail deployment.
///      Example: FOUNDRY_PROFILE=layer1o forge build
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized2 is InboxOptimized1 {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(IInbox.Config memory _config) InboxOptimized1(_config) { }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @notice Encodes proposed event data using optimized format
    /// @dev Overrides base implementation to use custom encoding
    /// @param _payload The ProposedEventPayload to encode
    /// @return Custom-encoded bytes with reduced size
    function _encodeProposedEventData(ProposedEventPayload memory _payload)
        internal
        pure
        virtual
        override
        returns (bytes memory)
    {
        return LibProposedEventEncoder.encode(_payload);
    }

    /// @inheritdoc Inbox
    /// @notice Encodes proved event data using optimized format
    /// @dev Overrides base implementation to use custom encoding
    /// @param _payload The ProvedEventPayload to encode
    /// @return Custom-encoded bytes with reduced size
    function _encodeProvedEventData(ProvedEventPayload memory _payload)
        internal
        pure
        virtual
        override
        returns (bytes memory)
    {
        return LibProvedEventEncoder.encode(_payload);
    }

    /// @inheritdoc Inbox
    /// @notice Decodes custom-encoded proposal input data
    /// @dev Overrides base implementation to use LibProposeInputDecoder
    /// @param _data The custom-encoded propose input data
    /// @return _ The decoded ProposeInput struct
    function _decodeProposeInput(bytes calldata _data)
        internal
        pure
        override
        returns (ProposeInput memory)
    {
        return LibProposeInputDecoder.decode(_data);
    }

    /// @inheritdoc Inbox
    /// @notice Decodes custom-encoded prove input data
    /// @dev Overrides base implementation to use LibProveInputDecoder
    /// @param _data The custom-encoded prove input data
    /// @return The decoded ProveInput struct
    function _decodeProveInput(bytes calldata _data)
        internal
        pure
        override
        returns (ProveInput memory)
    {
        return LibProveInputDecoder.decode(_data);
    }
}
