// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { InboxOptimized2 } from "./InboxOptimized2.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";

/// @title InboxOptimized3
/// @notice Third optimization layer focusing on calldata cost reduction
/// @dev Key optimizations:
///      - Custom calldata encoding for propose and prove inputs
///      - Compact binary representation using LibProposeInputDecoder and LibProveInputDecoder
///      - Reduced transaction costs through efficient data packing
///      - Maintains all optimizations from InboxOptimized1 and InboxOptimized2
/// @dev Gas savings: ~40% reduction in calldata costs for propose/prove operations
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimized3 is InboxOptimized2 {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        uint64 _inclusionDelay,
        uint64 _feeInGwei
    )
        InboxOptimized2(_inclusionDelay, _feeInGwei)
    { }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Encodes ProposeInput using optimized binary format
    /// @dev Reduces calldata size by ~35% compared to standard ABI encoding
    /// @param _input The ProposeInput struct to encode
    function encodeProposeInput(ProposeInput memory _input)
        external
        pure
        override
        returns (bytes memory)
    {
        return LibProposeInputDecoder.encode(_input);
    }

    /// @notice Encodes ProveInput using optimized binary format
    /// @dev Reduces calldata size by ~40% compared to standard ABI encoding
    /// @param _input The ProveInput struct to encode
    function encodeProveInput(ProveInput memory _input)
        external
        pure
        override
        returns (bytes memory)
    {
        return LibProveInputDecoder.encode(_input);
    }

    /// @notice Encodes ProposedEventPayload for efficient event emission
    /// @dev Uses LibProposedEventEncoder for compact representation
    /// @param _payload The ProposedEventPayload to encode
    function encodeProposedEventPayload(ProposedEventPayload memory _payload)
        external
        pure
        returns (bytes memory)
    {
        return LibProposedEventEncoder.encode(_payload);
    }

    /// @notice Encodes ProvedEventPayload for efficient event emission
    /// @dev Uses LibProvedEventEncoder for compact representation
    /// @param _payload The ProvedEventPayload to encode
    function encodeProvedEventPayload(ProvedEventPayload memory _payload)
        external
        pure
        returns (bytes memory)
    {
        return LibProvedEventEncoder.encode(_payload);
    }

    // ---------------------------------------------------------------
    // Public Functions - Overrides
    // ---------------------------------------------------------------

    /// @inheritdoc Inbox
    /// @notice Decodes custom-encoded proposal input data
    /// @dev Overrides base implementation to use LibProposeInputDecoder
    /// @param _data The custom-encoded propose input data
    /// @return _ The decoded ProposeInput struct with all proposal parameters
    function decodeProposeInput(bytes calldata _data)
        public
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
    /// @return The decoded ProveInput struct with proposals and transitions arrays
    function decodeProveInput(bytes calldata _data)
        public
        pure
        override
        returns (ProveInput memory)
    {
        return LibProveInputDecoder.decode(_data);
    }
}
