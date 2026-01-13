// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibTransitionCodec
/// @notice Shared transition encode/decode helpers to avoid duplication across codecs.
/// @custom:security-contact security@taiko.xyz
library LibTransitionCodec {
    /// @dev Transition size: 20 (designatedProver) + 6 (timestamp) + 32 (blockHash) = 58 bytes
    uint256 internal constant TRANSITION_SIZE = 58;

    function encodeTransition(
        uint256 _ptr,
        IInbox.Transition memory _transition
    )
        internal
        pure
        returns (uint256 newPtr_)
    {
        newPtr_ = P.packAddress(_ptr, _transition.designatedProver);
        newPtr_ = P.packUint48(newPtr_, _transition.timestamp);
        newPtr_ = P.packBytes32(newPtr_, _transition.blockHash);
    }

    function decodeTransition(uint256 _ptr)
        internal
        pure
        returns (IInbox.Transition memory transition_, uint256 newPtr_)
    {
        (transition_.designatedProver, newPtr_) = P.unpackAddress(_ptr);
        (transition_.timestamp, newPtr_) = P.unpackUint48(newPtr_);
        (transition_.blockHash, newPtr_) = P.unpackBytes32(newPtr_);
    }
}
