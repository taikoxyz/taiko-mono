// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";

/// @title LibProvedEventEncoder
/// @notice Temporary stub library for ProvedEventPayload encoding
/// @dev This is a simplified version that uses abi.encode until the full library is updated
///      to match the new multi-source derivation structure
/// @custom:security-contact security@taiko.xyz
library LibProvedEventEncoder {
    /// @notice Encodes proved event data using ABI encoding
    /// @param _payload The ProvedEventPayload to encode
    /// @return The encoded data
    function encode(IInbox.ProvedEventPayload memory _payload)
        external
        pure
        returns (bytes memory)
    {
        return abi.encode(_payload);
    }

    /// @notice Decodes proved event data using ABI decoding
    /// @param _data The encoded data
    /// @return The decoded ProvedEventPayload
    function decode(bytes memory _data) external pure returns (IInbox.ProvedEventPayload memory) {
        return abi.decode(_data, (IInbox.ProvedEventPayload));
    }
}
