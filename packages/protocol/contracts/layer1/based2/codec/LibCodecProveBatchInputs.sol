// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibCodecProveBatchInputs
/// @notice Library for encoding and decoding ProveBatchInput arrays
/// @custom:security-contact security@taiko.xyz
// TODO(dnaiel): implement this library
library LibCodecProveBatchInputs {
    /// @notice Encodes an array of ProveBatchInput structs into bytes
    /// @param _inputs The array to encode
    /// @return _ The encoded data
    function encode(I.ProveBatchInput[] memory _inputs) internal pure returns (bytes memory) {
        return abi.encode(_inputs);
    }

    /// @notice Decodes bytes into an array of ProveBatchInput structs
    /// @param _data The encoded data
    /// @return _ The decoded array
    function decode(bytes memory _data) internal pure returns (I.ProveBatchInput[] memory) {
        return abi.decode(_data, (I.ProveBatchInput[]));
    }

    /// @notice Decodes bytes into prove batches inputs
    /// @param _data The encoded data
    /// @return _ The decoded ProveBatchInput array
    function decodeProveBatchesInputs(bytes memory _data)
        internal
        pure
        returns (I.ProveBatchInput[] memory)
    {
        return decode(_data);
    }
}
