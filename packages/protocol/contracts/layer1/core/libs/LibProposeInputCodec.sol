// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProposeInputCodec
/// @notice Compact encoder/decoder for propose inputs using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProposeInputCodec {
    /// @notice Encodes propose data using compact packing.
    function encode(IInbox.ProposeInput memory _input)
        internal
        pure
        returns (bytes memory encoded_)
    {
        encoded_ = new bytes(14);
        uint256 ptr = P.dataPtr(encoded_);
        ptr = P.packUint48(ptr, _input.deadline);
        ptr = P.packUint16(ptr, _input.blobReference.blobStartIndex);
        ptr = P.packUint16(ptr, _input.blobReference.numBlobs);
        ptr = P.packUint24(ptr, _input.blobReference.offset);
        ptr = P.packUint8(ptr, _input.numForcedInclusions);
    }

    /// @notice Decodes propose data using compact packing.
    function decode(bytes memory _data) internal pure returns (IInbox.ProposeInput memory input_) {
        uint256 ptr = P.dataPtr(_data);
        (input_.deadline, ptr) = P.unpackUint48(ptr);
        (input_.blobReference.blobStartIndex, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.numBlobs, ptr) = P.unpackUint16(ptr);
        (input_.blobReference.offset, ptr) = P.unpackUint24(ptr);
        (input_.numForcedInclusions, ptr) = P.unpackUint8(ptr);
    }
}
