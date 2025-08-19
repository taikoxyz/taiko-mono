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
    /// @return payload_ The decoded proposed event payload
    function decodeProposedEventData(bytes memory _data)
        external
        pure
        returns (ProposedEventPayload memory payload_)
    {
        return LibProposedEventEncoder.decode(_data);
    }

    /// @dev Decodes the prove event data that was encoded
    /// @param _data The encoded data
    /// @return payload_ The decoded proved event payload
    function decodeProvedEventData(bytes memory _data)
        external
        pure
        returns (ProvedEventPayload memory payload_)
    {
        return LibProvedEventEncoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @dev Encodes the proposed event data for gas optimization
    /// @param _proposal The proposal to encode
    /// @param _derivation The derivation data to encode
    /// @param _coreState The core state to encode
    /// @return The encoded data
    function encodeProposedEventData(
        Proposal memory _proposal,
        Derivation memory _derivation,
        CoreState memory _coreState
    )
        public
        pure
        override
        returns (bytes memory)
    {
        ProposedEventPayload memory payload = ProposedEventPayload({
            proposal: _proposal,
            derivation: _derivation,
            coreState: _coreState
        });
        return LibProposedEventEncoder.encode(payload);
    }

    /// @dev Encodes the proved event data for gas optimization using compact encoding
    /// @param _claimRecord The claim record to encode
    /// @return The encoded data
    function encodeProveEventData(ClaimRecord memory _claimRecord)
        public
        pure
        override
        returns (bytes memory)
    {
        // Note: ProvedEventPayload requires proposalId and claim data which are not available
        // in this context. This function signature is inherited from the base Inbox contract
        // which only passes ClaimRecord. The base implementation uses abi.encode.
        // For full optimization, the base contract would need to be modified.
        return abi.encode(_claimRecord);
    }
}
