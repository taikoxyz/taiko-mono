// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProposedEventCodec
/// @notice Compact encoder/decoder for ProposedEventPayload using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProposedEventCodec {
    /// @notice Encodes a ProposedEventPayload into bytes using compact encoding.
    function encode(IInbox.ProposedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        uint256 bufferSize = calculateProposedEventSize(_payload.sources);
        encoded_ = new bytes(bufferSize);

        uint256 ptr = P.dataPtr(encoded_);

        ptr = P.packUint48(ptr, _payload.id);
        ptr = P.packAddress(ptr, _payload.proposer);

        uint256 sourcesLength = _payload.sources.length;
        P.checkArrayLength(sourcesLength);
        ptr = P.packUint16(ptr, uint16(sourcesLength));
        for (uint256 i; i < sourcesLength; ++i) {
            IInbox.DerivationSource memory source = _payload.sources[i];
            ptr = P.packUint8(ptr, source.isForcedInclusion ? 1 : 0);

            uint256 blobHashesLength = source.blobSlice.blobHashes.length;
            P.checkArrayLength(blobHashesLength);
            ptr = P.packUint16(ptr, uint16(blobHashesLength));
            for (uint256 j; j < blobHashesLength; ++j) {
                ptr = P.packBytes32(ptr, source.blobSlice.blobHashes[j]);
            }

            ptr = P.packUint24(ptr, source.blobSlice.offset);
            ptr = P.packUint48(ptr, source.blobSlice.timestamp);
        }
    }

    /// @notice Decodes bytes into a ProposedEventPayload using compact encoding.
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        uint256 ptr = P.dataPtr(_data);

        (payload_.id, ptr) = P.unpackUint48(ptr);
        (payload_.proposer, ptr) = P.unpackAddress(ptr);

        uint16 sourcesLength;
        (sourcesLength, ptr) = P.unpackUint16(ptr);
        payload_.sources = new IInbox.DerivationSource[](sourcesLength);
        for (uint256 i; i < sourcesLength; ++i) {
            uint8 isForcedInclusion;
            (isForcedInclusion, ptr) = P.unpackUint8(ptr);
            payload_.sources[i].isForcedInclusion = isForcedInclusion != 0;

            uint16 blobHashesLength;
            (blobHashesLength, ptr) = P.unpackUint16(ptr);

            payload_.sources[i].blobSlice.blobHashes = new bytes32[](blobHashesLength);
            for (uint256 j; j < blobHashesLength; ++j) {
                (payload_.sources[i].blobSlice.blobHashes[j], ptr) = P.unpackBytes32(ptr);
            }

            (payload_.sources[i].blobSlice.offset, ptr) = P.unpackUint24(ptr);
            (payload_.sources[i].blobSlice.timestamp, ptr) = P.unpackUint48(ptr);
        }
    }

    /// @notice Calculate the exact byte size needed for encoding a ProposedEventPayload.
    function calculateProposedEventSize(IInbox.DerivationSource[] memory _sources)
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size without sources: 28 bytes
            // id(6) + proposer(20) + sources length(2)
            size_ = 28;

            for (uint256 i; i < _sources.length; ++i) {
                size_ += 12 + (_sources[i].blobSlice.blobHashes.length * 32);
            }
        }
    }
}
