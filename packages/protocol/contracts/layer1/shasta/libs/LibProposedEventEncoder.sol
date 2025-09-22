// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";

/// @title LibProposedEventEncoder
/// @notice Temporary stub library for ProposedEventPayload encoding
/// @dev This is a simplified version that uses abi.encode until the full library is updated
///      to match the new multi-source derivation structure
/// @custom:security-contact security@taiko.xyz
library LibProposedEventEncoder {
    /// @notice Encodes proposed event data using ABI encoding
    /// @param _payload The ProposedEventPayload to encode
    /// @return The encoded data
    function encode(IInbox.ProposedEventPayload memory _payload)
        external
        pure
        returns (bytes memory)
    {
        return abi.encode(_payload);
    }

    /// @notice Decodes proposed event data using ABI decoding
    /// @param _data The encoded data
    /// @return The decoded ProposedEventPayload
    function decode(bytes memory _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory)
    {
        return abi.decode(_data, (IInbox.ProposedEventPayload));
    }
}
