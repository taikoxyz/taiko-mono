// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibPackUnpack as P } from "src/layer1/core/libs/LibPackUnpack.sol";
import { LibUnpackCalldata as PC } from "src/layer1/core/libs/LibUnpackCalldata.sol";
import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";

/// @title LibLookaheadEncoder
/// @notice Library for encoding and decoding lookahead data passed to the lookahead store
/// @custom:security-contact security@taiko.xyz
library LibLookaheadEncoder {
    uint256 internal constant LOOKAHEAD_SLOT_SIZE = 60; // bytes

    function numSlots(bytes calldata _encoded) internal pure returns (uint256) {
        return _encoded.length / LOOKAHEAD_SLOT_SIZE;
    }

    function encodeLookahead(ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots)
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
    /// @dev This expects the encoded lookahead to be from the calldata
    function decodeIndex(
        bytes calldata _encoded,
        uint256 _index
    )
        internal
        pure
        returns (ILookaheadStore.LookaheadSlot memory lookaheadSlot_)
    {
        // Position the pointer at the beginning of the element to be decoded
        uint256 ptr = PC.dataPtr(_encoded);
        ptr += (_index * LOOKAHEAD_SLOT_SIZE);

        (lookaheadSlot_.committer, ptr) = PC.unpackAddress(ptr);
        (lookaheadSlot_.timestamp, ptr) = PC.unpackUint48(ptr);
        (lookaheadSlot_.validatorLeafIndex, ptr) = PC.unpackUint16(ptr);
        (lookaheadSlot_.registrationRoot, ptr) = PC.unpackBytes32(ptr);
    }
}
