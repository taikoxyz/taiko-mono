// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { IInbox } from "../iface/IInbox.sol";
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
/// @dev DEPLOYMENT: REQUIRED to use FOUNDRY_PROFILE=layer1o for deployment. Contract exceeds
///      24KB limit without via_ir optimization. Regular compilation will fail deployment.
///      Example: FOUNDRY_PROFILE=layer1o forge build
/// contracts/layer1/shasta/impl/InboxOptimized3.sol
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized3 is InboxOptimized2 {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(IInbox.Config memory _config) InboxOptimized2(_config) { }

    // ---------------------------------------------------------------
    // Internal Functions - Overrides
    // ---------------------------------------------------------------

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
