// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized1 } from "./InboxOptimized1.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";

/// @title InboxOptimized2
/// @notice Inbox optimized, on top of InboxOptimized1, to lower event emission cost.
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimized2 is InboxOptimized1 {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() InboxOptimized1() { }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @dev Decodes the proposed event data that was encoded
    /// @param _data The encoded data
    /// @return _ The decoded proposed event payload
    function decodeProposedEventData(bytes memory _data)
        external
        pure
        returns (ProposedEventPayload memory)
    {
        return LibProposedEventEncoder.decode(_data);
    }

    /// @dev Decodes the prove event data that was encoded
    /// @param _data The encoded data
    /// @return _ The decoded proved event payload
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

    /// @dev Encodes the proposed event data
    /// @param _payload The ProposedEventPayload object
    /// @return The encoded data
    function encodeProposedEventData(ProposedEventPayload memory _payload)
        public
        pure
        virtual
        override
        returns (bytes memory)
    {
        return LibProposedEventEncoder.encode(_payload);
    }

    /// @dev Encodes the proved event data
    /// @param _paylaod The ProvedEventPayload object
    /// @return The encoded data
    function encodeProvedEventData(ProvedEventPayload memory _paylaod)
        public
        pure
        virtual
        override
        returns (bytes memory)
    {
        return LibProvedEventEncoder.encode(_paylaod);
    }
}
