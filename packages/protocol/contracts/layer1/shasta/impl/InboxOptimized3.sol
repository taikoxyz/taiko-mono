// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized2 } from "./InboxOptimized2.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";

/// @title InboxOptimized3
/// @notice Inbox optimized, on top of InboxOptimized2, to lower calldata cost.
/// @custom:security-contact security@taiko.xyz
abstract contract InboxOptimized3 is InboxOptimized2 {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() InboxOptimized2() { }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Encodes ProposeInput into a byte array
    /// @param _input The decoded ProposeInput struct containing all proposal data
    function encodeProposeInput(ProposeInput memory _input) external pure returns (bytes memory) {
        return LibProposeInputDecoder.encode(_input);
    }

    /// @notice Encodes ProveInput into a byte array
    /// @param _input The decoded ProveInput struct containing proposals and claims
    function encodeProveInput(ProveInput memory _input) external pure returns (bytes memory) {
        return LibProveInputDecoder.encode(_input);
    }

    /// @notice Encodes ProposedEventPayload into a byte array
    /// @param _payload The decoded ProposedEventPayload struct
    function encodeProposedEventPayload(ProposedEventPayload memory _payload)
        external
        pure
        returns (bytes memory)
    {
        return LibProposedEventEncoder.encode(_payload);
    }

    /// @notice Encodes ProvedEventPayload into a byte array
    /// @param _payload The decoded ProvedEventPayload struct
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

    /// @notice Decodes proposal input data using optimized decoder
    /// @param _data The encoded data
    /// @return _ The decoded ProposeInput struct containing all proposal data
    function decodeProposeInput(bytes calldata _data)
        public
        pure
        override
        returns (ProposeInput memory)
    {
        return LibProposeInputDecoder.decode(_data);
    }

    /// @notice Decodes prove input data using optimized decoder
    /// @param _data The encoded data
    /// @return The decoded ProveInput struct containing proposals and claims
    function decodeProveInput(bytes calldata _data)
        public
        pure
        override
        returns (ProveInput memory)
    {
        return LibProveInputDecoder.decode(_data);
    }
}
