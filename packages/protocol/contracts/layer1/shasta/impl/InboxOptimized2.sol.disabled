// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { IInbox } from "../iface/IInbox.sol";
import { InboxOptimized1 } from "./InboxOptimized1.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";

/// @title InboxOptimized2
/// @notice Second optimization layer focusing on event emission optimization
/// @dev Key optimizations:
///      - Custom event encoding using LibProposedEventEncoder and LibProvedEventEncoder
///      - Compact binary representation for event data
///      - Reduced calldata size for events
///      - Maintains all optimizations from InboxOptimized1
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
}
