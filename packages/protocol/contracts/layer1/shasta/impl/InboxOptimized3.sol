// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized2 } from "./InboxOptimized2.sol";
import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";

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
    // External Functions - Overrides
    // ---------------------------------------------------------------

    /// @notice Decodes proposal input data using optimized decoder
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput struct containing all proposal data
    function decodeProposeInput(bytes calldata _data)
        public
        pure
        override
        returns (ProposeInput memory input_)
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
