// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";

/// @title InboxOptimized2
/// @notice Second optimization layer focusing on event emission gas reduction
/// @dev Key optimizations:
///      - Custom event encoding using LibProposedEventEncoder and LibProvedEventEncoder
///      - Compact binary representation for event data
///      - Reduced calldata size for events
///      - Builds on top of base Inbox (which now includes transition aggregation optimizations)
/// @dev Gas savings: ~30% reduction in event emission costs compared to standard ABI encoding
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimized2 is Inbox {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() Inbox() { }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Decodes custom-encoded proposed event data
    /// @dev Uses LibProposedEventEncoder for efficient decoding
    /// @param _data The custom-encoded event data
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
    /// @param _data The custom-encoded event data
    /// @return _ The decoded ProvedEventPayload struct
    function decodeProvedEventData(bytes memory _data)
        external
        pure
        returns (ProvedEventPayload memory)
    {
        return LibProvedEventEncoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // Public Functions
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
