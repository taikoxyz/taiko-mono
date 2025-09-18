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
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Decodes custom-encoded proposed event data
    /// @dev Uses LibProposedEventEncoder for efficient decoding
    /// @param _data The custom-encoded event data in compact binary format
    /// @return _ The decoded ProposedEventPayload struct
    function decodeProposedEventData(bytes memory _data)
        external
        pure
        returns (ProposedEventPayload memory)
    {
        return LibProposedEventEncoder.decode(_data);
    }

    /// @notice Decodes custom-encoded proved event data
    /// @dev Uses LibProvedEventEncoder for efficient decoding
    /// @param _data The custom-encoded event data in compact binary format
    /// @return _ The decoded ProvedEventPayload struct
    function decodeProvedEventData(bytes memory _data)
        external
        pure
        returns (ProvedEventPayload memory)
    {
        return LibProvedEventEncoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // Public Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @notice Encodes proposed event data using optimized format
    /// @dev Overrides base implementation to use custom encoding
    /// @param _payload The ProposedEventPayload to encode
    /// @return Custom-encoded bytes with reduced size
    function encodeProposedEventData(ProposedEventPayload memory _payload)
        public
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
    function encodeProvedEventData(ProvedEventPayload memory _payload)
        public
        pure
        virtual
        override
        returns (bytes memory)
    {
        return LibProvedEventEncoder.encode(_payload);
    }
}
