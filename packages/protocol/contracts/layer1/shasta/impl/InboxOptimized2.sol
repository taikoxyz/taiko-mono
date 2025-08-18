// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./InboxOptimized1.sol";
import "../libs/LibProposedEventEncoder.sol";
import "../libs/LibProvedEventEncoder.sol";

/// @title InboxOptimized
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
    /// @return proposal_ The decoded proposal
    /// @return coreState_ The decoded core state
    function decodeProposedEventData(bytes memory _data)
        external
        pure
        returns (Proposal memory proposal_, CoreState memory coreState_)
    {
        return LibProposedEventEncoder.decode(_data);
    }

    /// @dev Decodes the prove event data that was encoded
    /// @param _data The encoded data
    /// @return claimRecord_ The decoded claim record
    function decodeProveEventData(bytes memory _data)
        external
        pure
        returns (ClaimRecord memory claimRecord_)
    {
        return LibProvedEventEncoder.decode(_data);
    }

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @dev Encodes the proposed event data for gas optimization
    /// @param _proposal The proposal to encode
    /// @param _coreState The core state to encode
    /// @return The encoded data
    function encodeProposalCoreState(
        Proposal memory _proposal,
        CoreState memory _coreState
    )
        public
        pure
        override
        returns (bytes memory)
    {
        return LibProposedEventEncoder.encode(_proposal, _coreState);
    }

    /// @dev Encodes the proved event data for gas optimization using compact encoding
    /// @param _claimRecord The claim record to encode
    /// @return The encoded data
    function encodeClaimRecord(ClaimRecord memory _claimRecord)
        public
        pure
        override
        returns (bytes memory)
    {
        return LibProvedEventEncoder.encode(_claimRecord);
    }
}
