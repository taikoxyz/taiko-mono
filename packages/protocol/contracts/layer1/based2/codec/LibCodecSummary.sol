// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";

/// @title LibCodecSummary
/// @notice Library for encoding and decoding Summary
/// @custom:security-contact security@taiko.xyz
// TODO(dnaiel): implement this library
library LibCodecSummary {
    /// @notice Encodes a Summary struct into bytes
    /// @param _summary The Summary to encode
    /// @return _ The encoded data
    function encode(IInbox.Summary memory _summary) internal pure returns (bytes memory) {
        return abi.encode(_summary);
    }

    /// @notice Decodes bytes into a Summary struct
    /// @param _data The encoded data
    /// @return _ The decoded Summary
    function decode(bytes memory _data) internal pure returns (IInbox.Summary memory) {
        return abi.decode(_data, (IInbox.Summary));
    }
}
