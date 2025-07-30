// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";

/// @title LibCodecBatchContext
/// @notice Library for encoding and decoding BatchContext
/// @custom:security-contact security@taiko.xyz
library LibCodecBatchContext {
    /// @notice Encodes a BatchContext struct into bytes
    /// @param _batchContexts The array of BatchContext to encode
    /// @return _ The encoded data
    /// @custom:encode optimize-gas
    function encode(IInbox.BatchContext[] memory _batchContexts)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_batchContexts);
    }

    /// @notice Decodes bytes into a BatchContext struct
    /// @param _data The encoded data
    /// @return _ The decoded BatchContext array
    function decode(bytes memory _data) internal pure returns (IInbox.BatchContext[] memory) {
        return abi.decode(_data, (IInbox.BatchContext[]));
    }
}
