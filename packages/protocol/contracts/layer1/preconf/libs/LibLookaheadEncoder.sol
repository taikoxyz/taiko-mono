// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";
import { LibPackUnpack as P } from "src/layer1/shasta/libs/LibPackUnpack.sol";

/// @title LibProposeInputDecoder
/// @notice Library for encoding and decoding lookahead data passed to the lookahead store
/// @custom:security-contact security@taiko.xyz
library LibLookaheadEncoder {
    uint256 internal constant LOOKAHEAD_SLOT_SIZE = 60; // bytes

    function numSlots(bytes memory _encoded) internal pure returns (uint256) {
        return _encoded.length / LOOKAHEAD_SLOT_SIZE;
    }

    function encode(ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots)
        internal
        pure
        returns (bytes memory encoded_)
    {
        encoded_ = new bytes(_lookaheadSlots.length * LOOKAHEAD_SLOT_SIZE);

        uint256 ptr = P.dataPtr(encoded_);
        for (uint256 i; i < _lookaheadSlots.length; ++i) {
            ptr = P.packAddress(ptr, _lookaheadSlots[i].committer);
            ptr = P.packUint48(ptr, _lookaheadSlots[i].timestamp);
            ptr = P.packUint16(ptr, _lookaheadSlots[i].validatorLeafIndex);
            ptr = P.packBytes32(ptr, _lookaheadSlots[i].registrationRoot);
        }
    }

    /// @dev Assumes that `_index` is never out of bounds
    function decodeIndex(bytes memory _encoded, uint256 _index)
        internal
        pure
        returns (ILookaheadStore.LookaheadSlot memory lookaheadSlot_)
    {
        // Position the pointer at the beginning of the element to be decoded
        uint256 ptr = P.dataPtr(_encoded);
        ptr += (_index * LOOKAHEAD_SLOT_SIZE);

        (lookaheadSlot_.committer, ptr) = P.unpackAddress(ptr);
        (lookaheadSlot_.timestamp, ptr) = P.unpackUint48(ptr);
        (lookaheadSlot_.validatorLeafIndex, ptr) = P.unpackUint16(ptr);
        (lookaheadSlot_.registrationRoot, ptr) = P.unpackBytes32(ptr);
    }
}
