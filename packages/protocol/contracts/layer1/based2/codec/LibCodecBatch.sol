// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibCodecBatch
/// @notice Library for encoding and decoding Batch arrays
/// @custom:security-contact security@taiko.xyz
// TODO(dnaiel): implement this library
library LibCodecBatch {
    /// @notice Encodes an array of Batch structs into bytes
    /// @param _batches The array to encode
    /// @return _ The encoded data
    function encode(I.Batch[] memory _batches) internal pure returns (bytes memory) {
        return abi.encode(_batches);
    }

    /// @notice Decodes bytes into an array of Batch structs
    /// @param _data The encoded data
    /// @return _ The decoded array
    function decode(bytes memory _data) internal pure returns (I.Batch[] memory) {
        return abi.decode(_data, (I.Batch[]));
    }
}
