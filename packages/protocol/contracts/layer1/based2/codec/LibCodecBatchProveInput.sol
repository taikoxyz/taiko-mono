// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibCodecBatchProveInput
/// @notice Library for encoding and decoding BatchProveInput arrays
/// @custom:security-contact security@taiko.xyz
// TODO(dnaiel): implement this library
library LibCodecBatchProveInput {
    /// @notice Encodes an array of BatchProveInput structs into bytes
    /// @param _inputs The array to encode
    /// @return _ The encoded data
    function encode(I.BatchProveInput[] memory _inputs) internal pure returns (bytes memory) {
        return abi.encode(_inputs);
    }

    /// @notice Decodes bytes into an array of BatchProveInput structs
    /// @param _data The encoded data
    /// @return _ The decoded array
    function decode(bytes memory _data) internal pure returns (I.BatchProveInput[] memory) {
        return abi.decode(_data, (I.BatchProveInput[]));
    }

    /// @notice Decodes bytes into prove batches inputs
    /// @param _data The encoded data
    /// @return _ The decoded BatchProveInput array
    function decodeProveBatchesInputs(bytes memory _data)
        internal
        pure
        returns (I.BatchProveInput[] memory)
    {
        return decode(_data);
    }
}
