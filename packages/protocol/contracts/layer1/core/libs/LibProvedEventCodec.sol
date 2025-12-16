// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";

/// @title LibProvedEventCodec
/// @notice Compact encoder/decoder for ProvedEventPayload using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProvedEventCodec {
    /// @dev Encoded size: firstProposalId (6) + firstNewProposalId (6) + lastProposalId (6) +
    /// actualProver (20) + checkpointSynced (1) = 39 bytes
    uint256 private constant ENCODED_SIZE = 39;

    /// @notice Encodes a ProvedEventPayload into bytes using compact encoding.
    function encode(IInbox.ProvedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        encoded_ = new bytes(ENCODED_SIZE);
        uint256 ptr = P.dataPtr(encoded_);

        ptr = P.packUint48(ptr, _payload.firstProposalId);
        ptr = P.packUint48(ptr, _payload.firstNewProposalId);
        ptr = P.packUint48(ptr, _payload.lastProposalId);
        ptr = P.packAddress(ptr, _payload.actualProver);
        P.packUint8(ptr, _payload.checkpointSynced ? 1 : 0);
    }

    /// @notice Decodes bytes into a ProvedEventPayload using compact encoding.
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        uint256 ptr = P.dataPtr(_data);

        (payload_.firstProposalId, ptr) = P.unpackUint48(ptr);
        (payload_.firstNewProposalId, ptr) = P.unpackUint48(ptr);
        (payload_.lastProposalId, ptr) = P.unpackUint48(ptr);
        (payload_.actualProver, ptr) = P.unpackAddress(ptr);

        uint8 checkpointSyncedByte;
        (checkpointSyncedByte,) = P.unpackUint8(ptr);
        payload_.checkpointSynced = checkpointSyncedByte != 0;
    }
}
