// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IInbox.sol";
import "./LibBlobs.sol";
import "src/shared/based/libs/LibBonds.sol";

/// @title LibProposedEventCodec
/// @notice Library for encoding and decoding event data for gas optimization using assembly
/// @dev Array lengths are encoded as uint24 (3 bytes) to support up to 16,777,215 elements while
/// maintaining gas efficiency.
/// This provides a good balance between array size capacity and storage efficiency compared to
/// uint16 (65,535 max) or uint32 (4 bytes).
/// @custom:security-contact security@taiko.xyz
library LibProposedEventCodec {
    // ---------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------

    /// @dev Encodes the proposed event data using simple abi.encode
    /// @param _proposal The proposal to encode
    /// @param _coreState The core state to encode
    /// @return The encoded data as bytes
    function encode(
        IInbox.Proposal memory _proposal,
        IInbox.CoreState memory _coreState
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_proposal, _coreState);
    }

    /// @dev Decodes the proposed event data using simple abi.decode
    /// @param _data The encoded data
    /// @return proposal_ The decoded proposal
    /// @return coreState_ The decoded core state
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.Proposal memory proposal_, IInbox.CoreState memory coreState_)
    {
        (proposal_, coreState_) = abi.decode(_data, (IInbox.Proposal, IInbox.CoreState));
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error INVALID_DATA_LENGTH();
}
