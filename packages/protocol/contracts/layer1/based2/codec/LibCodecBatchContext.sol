// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";

/// @title LibCodecBatchContext
/// @notice Library for encoding and decoding BatchContext
/// @custom:security-contact security@taiko.xyz
// TODO(dnaiel): implement this library
library LibCodecBatchContext {
    /// @notice Encodes a BatchContext struct into bytes
    /// @param _batchContext The BatchContext to encode
    /// @return _ The encoded data
    /// @custom:encode optimize-gas
    function encode(IInbox.BatchContext memory _batchContext)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_batchContext);
    }

    /// @notice Decodes bytes into a BatchContext struct
    /// @param _data The encoded data
    /// @return _ The decoded BatchContext
    function decode(bytes memory _data) internal pure returns (IInbox.BatchContext memory) {
        return abi.decode(_data, (IInbox.BatchContext));
    }
}
