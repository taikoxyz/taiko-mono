// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProposedEventEncoder
/// @notice Compact encoder/decoder for ProposedEventPayload using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProposedEventEncoder {
    /// @notice Encodes a ProposedEventPayload into bytes using compact encoding.
    function encode(IInbox.ProposedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        uint256 bufferSize = calculateProposedEventSize(_payload.derivation.sources);
        encoded_ = new bytes(bufferSize);

        uint256 ptr = P.dataPtr(encoded_);

        ptr = P.packUint48(ptr, _payload.proposal.id);
        ptr = P.packAddress(ptr, _payload.proposal.proposer);
        ptr = P.packUint48(ptr, _payload.proposal.timestamp);
        ptr = P.packUint48(ptr, _payload.proposal.endOfSubmissionWindowTimestamp);

        ptr = P.packUint48(ptr, _payload.derivation.originBlockNumber);
        ptr = P.packBytes32(ptr, _payload.derivation.originBlockHash);
        ptr = P.packUint8(ptr, _payload.derivation.basefeeSharingPctg);

        uint256 sourcesLength = _payload.derivation.sources.length;
        P.checkArrayLength(sourcesLength);
        ptr = P.packUint16(ptr, uint16(sourcesLength));
        for (uint256 i; i < sourcesLength; ++i) {
            IInbox.DerivationSource memory source = _payload.derivation.sources[i];
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

        ptr = P.packBytes32(ptr, _payload.proposal.derivationHash);
    }

    /// @notice Decodes bytes into a ProposedEventPayload using compact encoding.
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        uint256 ptr = P.dataPtr(_data);

        (payload_.proposal.id, ptr) = P.unpackUint48(ptr);
        (payload_.proposal.proposer, ptr) = P.unpackAddress(ptr);
        (payload_.proposal.timestamp, ptr) = P.unpackUint48(ptr);
        (payload_.proposal.endOfSubmissionWindowTimestamp, ptr) = P.unpackUint48(ptr);

        (payload_.derivation.originBlockNumber, ptr) = P.unpackUint48(ptr);
        (payload_.derivation.originBlockHash, ptr) = P.unpackBytes32(ptr);
        (payload_.derivation.basefeeSharingPctg, ptr) = P.unpackUint8(ptr);

        uint16 sourcesLength;
        (sourcesLength, ptr) = P.unpackUint16(ptr);
        payload_.derivation.sources = new IInbox.DerivationSource[](sourcesLength);
        for (uint256 i; i < sourcesLength; ++i) {
            uint8 isForcedInclusion;
            (isForcedInclusion, ptr) = P.unpackUint8(ptr);
            payload_.derivation.sources[i].isForcedInclusion = isForcedInclusion != 0;

            uint16 blobHashesLength;
            (blobHashesLength, ptr) = P.unpackUint16(ptr);

            payload_.derivation.sources[i].blobSlice.blobHashes = new bytes32[](blobHashesLength);
            for (uint256 j; j < blobHashesLength; ++j) {
                (payload_.derivation.sources[i].blobSlice.blobHashes[j], ptr) =
                    P.unpackBytes32(ptr);
            }

            (payload_.derivation.sources[i].blobSlice.offset, ptr) = P.unpackUint24(ptr);
            (payload_.derivation.sources[i].blobSlice.timestamp, ptr) = P.unpackUint48(ptr);
        }

        (payload_.proposal.derivationHash, ptr) = P.unpackBytes32(ptr);
    }

    /// @notice Calculate the exact byte size needed for encoding a ProposedEventPayload.
    function calculateProposedEventSize(IInbox.DerivationSource[] memory _sources)
        internal
        pure
        returns (uint256 size_)
    {
        unchecked {
            // Fixed size without sources: 111 bytes
            // Proposal: id(6) + proposer(20) + timestamp(6) + endOfSubmissionWindowTimestamp(6)
            // Derivation base: originBlockNumber(6) + originBlockHash(32) + basefeeSharingPctg(1)
            // Sources length: 2
            // Proposal hash: derivationHash(32)
            size_ = 111;

            for (uint256 i; i < _sources.length; ++i) {
                size_ += 12 + (_sources[i].blobSlice.blobHashes.length * 32);
            }
        }
    }
}
