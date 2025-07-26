// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibCodecTransitionMeta
/// @notice Library for encoding and decoding TransitionMeta arrays
/// @custom:security-contact security@taiko.xyz
// TODO(dnaiel): implement this library
library LibCodecTransitionMeta {
    /// @notice Encodes an array of TransitionMeta structs into bytes
    /// @param _transitionMetas The array to encode
    /// @return _ The encoded data
    function encode(I.TransitionMeta[] memory _transitionMetas)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_transitionMetas);
    }

    /// @notice Decodes bytes into an array of TransitionMeta structs
    /// @param _data The encoded data
    /// @return _ The decoded array
    function decode(bytes memory _data) internal pure returns (I.TransitionMeta[] memory) {
        return abi.decode(_data, (I.TransitionMeta[]));
    }
}
