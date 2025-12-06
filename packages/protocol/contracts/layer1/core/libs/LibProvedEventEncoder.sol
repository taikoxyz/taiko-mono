// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibPackUnpack as P } from "./LibPackUnpack.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibProvedEventEncoder
/// @notice Compact encoder/decoder for ProvedEventPayload using LibPackUnpack.
/// @custom:security-contact security@taiko.xyz
library LibProvedEventEncoder {
    /// @notice Encodes a ProvedEventPayload into bytes using compact encoding.
    function encode(IInbox.ProvedEventPayload memory _payload)
        internal
        pure
        returns (bytes memory encoded_)
    {
        encoded_ = new bytes(calculateProvedEventSize());

        uint256 ptr = P.dataPtr(encoded_);

        ptr = P.packUint48(ptr, _payload.proposalId);

        ptr = P.packBytes32(ptr, _payload.transition.proposalHash);
        ptr = P.packBytes32(ptr, _payload.transition.parentTransitionHash);
        ptr = P.packUint48(ptr, _payload.transition.checkpoint.blockNumber);
        ptr = P.packBytes32(ptr, _payload.transition.checkpoint.blockHash);
        ptr = P.packBytes32(ptr, _payload.transition.checkpoint.stateRoot);
        ptr = P.packAddress(ptr, _payload.transition.designatedProver);
        ptr = P.packAddress(ptr, _payload.transition.actualProver);

        ptr = P.packUint48(ptr, _payload.bondInstruction.proposalId);
        ptr = P.packUint8(ptr, uint8(_payload.bondInstruction.bondType));
        ptr = P.packAddress(ptr, _payload.bondInstruction.payer);
        ptr = P.packAddress(ptr, _payload.bondInstruction.payee);

        P.packBytes32(ptr, _payload.bondSignal);
    }

    /// @notice Decodes bytes into a ProvedEventPayload using compact encoding.
    function decode(bytes memory _data)
        internal
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        uint256 ptr = P.dataPtr(_data);

        (payload_.proposalId, ptr) = P.unpackUint48(ptr);

        (payload_.transition.proposalHash, ptr) = P.unpackBytes32(ptr);
        (payload_.transition.parentTransitionHash, ptr) = P.unpackBytes32(ptr);
        (payload_.transition.checkpoint.blockNumber, ptr) = P.unpackUint48(ptr);
        (payload_.transition.checkpoint.blockHash, ptr) = P.unpackBytes32(ptr);
        (payload_.transition.checkpoint.stateRoot, ptr) = P.unpackBytes32(ptr);
        (payload_.transition.designatedProver, ptr) = P.unpackAddress(ptr);
        (payload_.transition.actualProver, ptr) = P.unpackAddress(ptr);

        (payload_.bondInstruction.proposalId, ptr) = P.unpackUint48(ptr);

        uint8 bondTypeValue;
        (bondTypeValue, ptr) = P.unpackUint8(ptr);
        require(bondTypeValue <= uint8(LibBonds.BondType.LIVENESS), InvalidBondType());
        payload_.bondInstruction.bondType = LibBonds.BondType(bondTypeValue);

        (payload_.bondInstruction.payer, ptr) = P.unpackAddress(ptr);
        (payload_.bondInstruction.payee, ptr) = P.unpackAddress(ptr);

        (payload_.bondSignal, ptr) = P.unpackBytes32(ptr);
    }

    /// @notice Calculate the exact byte size needed for encoding a ProvedEventPayload.
    function calculateProvedEventSize() internal pure returns (uint256 size_) {
        // proposalId: 6
        // Transition: 174
        // BondInstruction: 47
        // bondSignal: 32
        size_ = 259;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidBondType();
}
