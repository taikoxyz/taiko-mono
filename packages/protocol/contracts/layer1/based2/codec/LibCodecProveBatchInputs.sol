// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";

/// @title LibCodecProveBatchInputs
/// @notice Library for encoding and decoding ProveBatchInput arrays
/// @custom:security-contact security@taiko.xyz
library LibCodecProveBatchInputs {
    /// @notice Encodes an array of ProveBatchInput structs into bytes
    /// @param _proveBatchInputs The array to encode
    /// @return _ The encoded data
    function encode(IInbox.ProveBatchInput[] memory _proveBatchInputs)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_proveBatchInputs);
    }

    /// @notice Decodes bytes into an array of ProveBatchInput structs
    /// @param _data The encoded data
    /// @return _ The decoded array
    /// @custom:encode optimize-gas
    function decode(bytes memory _data) internal pure returns (IInbox.ProveBatchInput[] memory) {
        return abi.decode(_data, (IInbox.ProveBatchInput[]));
    }
}
