// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../SlotChainTypes.sol";
import { LibSlotChainConstants } from "./LibSlotChainConstants.sol";
import { LibSlotChainEncoding } from "./LibSlotChainEncoding.sol";

/// @title Slot Chain equivocation evidence codec
/// @custom:security-contact security@taiko.xyz
library LibSlotChainEvidence {
    uint256 internal constant PACKED_BLOCK_LENGTH = 521;
    uint256 internal constant SIGNATURE_LENGTH = 65;
    uint256 internal constant EQUIVOCATION_EVIDENCE_LENGTH = 2366;

    uint256 private constant _SECP256K1N_HALF =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    /// @dev Decodes the exact 521-byte signed-header tuple at `_offset`.
    /// @param _encoded The containing canonical evidence bytes.
    /// @param _offset The byte offset of the packed block.
    /// @return block_ The decoded SlotChainBlock tuple.
    function decodePackedBlock(
        bytes calldata _encoded,
        uint256 _offset
    )
        internal
        pure
        returns (SlotChainTypes.SlotChainBlock memory block_)
    {
        if (_offset > _encoded.length || _encoded.length - _offset < PACKED_BLOCK_LENGTH) {
            revert InvalidPackedBlockLength();
        }

        block_.settlementChainId = _readU256(_encoded, _offset);
        block_.l2ChainId = _readU256(_encoded, _offset + 32);
        block_.protocolVersion = _readU256(_encoded, _offset + 64);
        block_.verifyingContract = _readAddress(_encoded, _offset + 96);
        block_.slot = _readU64(_encoded, _offset + 116);
        block_.parentHash = _readBytes32(_encoded, _offset + 124);
        block_.blockHash = _readBytes32(_encoded, _offset + 156);
        block_.stateRoot = _readBytes32(_encoded, _offset + 188);
        block_.bodyRoot = _readBytes32(_encoded, _offset + 220);
        block_.anchorNumber = _readU64(_encoded, _offset + 252);
        block_.anchorHash = _readBytes32(_encoded, _offset + 260);
        block_.forceRoot = _readBytes32(_encoded, _offset + 292);
        block_.forceCutoff = _readU64(_encoded, _offset + 324);
        block_.messageStart = _readU64(_encoded, _offset + 332);
        block_.messageEnd = _readU64(_encoded, _offset + 340);
        block_.dataManifestRoot = _readBytes32(_encoded, _offset + 348);
        block_.coinbase = _readAddress(_encoded, _offset + 380);
        block_.tier = _readU8(_encoded, _offset + 400);
        block_.contextId = _readBytes32(_encoded, _offset + 401);
        block_.admissionVersion = _readU64(_encoded, _offset + 433);
        block_.admissionRoot = _readBytes32(_encoded, _offset + 441);
        block_.episode = _readU64(_encoded, _offset + 473);
        block_.recoveryRevision = _readU64(_encoded, _offset + 481);
        block_.recoveryId = _readBytes32(_encoded, _offset + 489);

        _validateTier(block_);
    }

    /// @dev Recovers the signer of one exact canonical low-s 65-byte signature.
    /// @param _digest The EIP-712 digest.
    /// @param _encoded The containing canonical evidence bytes.
    /// @param _offset The signature's byte offset.
    /// @return signer_ The nonzero recovered ECDSA signer.
    function recoverSigner(
        bytes32 _digest,
        bytes calldata _encoded,
        uint256 _offset
    )
        internal
        pure
        returns (address signer_)
    {
        if (_offset > _encoded.length || _encoded.length - _offset < SIGNATURE_LENGTH) {
            revert InvalidSignatureLength();
        }

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(add(_encoded.offset, _offset))
            s := calldataload(add(add(_encoded.offset, _offset), 32))
            v := byte(0, calldataload(add(add(_encoded.offset, _offset), 64)))
        }
        if (
            r == bytes32(0) || s == bytes32(0) || uint256(s) > _SECP256K1N_HALF
                || (v != 27 && v != 28)
        ) {
            revert InvalidSignature();
        }
        signer_ = ecrecover(_digest, v, r, s);
        if (signer_ == address(0)) revert InvalidSignature();
    }

    /// @dev Validates the shared equivocation identity and recovers its builder.
    /// @param _a The first signed block.
    /// @param _b The second signed block.
    /// @param _evidence The containing canonical evidence bytes.
    /// @param _signatureAOffset The first signature offset.
    /// @param _signatureBOffset The second signature offset.
    /// @return builder_ The common recovered builder.
    /// @return digestA_ The first ordered EIP-712 digest.
    /// @return digestB_ The second ordered EIP-712 digest.
    function validateEquivocationPair(
        SlotChainTypes.SlotChainBlock memory _a,
        SlotChainTypes.SlotChainBlock memory _b,
        bytes calldata _evidence,
        uint256 _signatureAOffset,
        uint256 _signatureBOffset
    )
        internal
        pure
        returns (address builder_, bytes32 digestA_, bytes32 digestB_)
    {
        if (
            _a.settlementChainId != _b.settlementChainId || _a.l2ChainId != _b.l2ChainId
                || _a.protocolVersion != _b.protocolVersion
                || _a.verifyingContract != _b.verifyingContract || _a.slot != _b.slot
                || _a.contextId == bytes32(0) || _a.contextId != _b.contextId
                || _a.admissionVersion != _b.admissionVersion
                || _a.admissionRoot != _b.admissionRoot || _a.tier != _b.tier
                || _a.anchorNumber != _b.anchorNumber || _a.anchorHash != _b.anchorHash
                || _a.forceRoot != _b.forceRoot || _a.forceCutoff != _b.forceCutoff
                || _a.episode != _b.episode || _a.recoveryRevision != _b.recoveryRevision
                || _a.recoveryId != _b.recoveryId
        ) {
            revert InvalidEquivocationPair();
        }

        bytes32 structHashA = LibSlotChainEncoding.hashSlotChainBlock(_a);
        bytes32 structHashB = LibSlotChainEncoding.hashSlotChainBlock(_b);
        if (uint256(structHashA) >= uint256(structHashB)) revert InvalidStructHashOrder();

        digestA_ = LibSlotChainEncoding.hashSlotChainDigest(
            _a.settlementChainId, _a.verifyingContract, _a
        );
        digestB_ = LibSlotChainEncoding.hashSlotChainDigest(
            _b.settlementChainId, _b.verifyingContract, _b
        );

        builder_ = recoverSigner(digestA_, _evidence, _signatureAOffset);
        if (recoverSigner(digestB_, _evidence, _signatureBOffset) != builder_) {
            revert SignerMismatch();
        }
    }

    /// @dev Loads one bottom-up fixed-tree sibling from calldata.
    function readBytes32(
        bytes calldata _encoded,
        uint256 _offset
    )
        internal
        pure
        returns (bytes32 value_)
    {
        return _readBytes32(_encoded, _offset);
    }

    /// @dev Loads one canonical big-endian u16 from calldata.
    function readU16(
        bytes calldata _encoded,
        uint256 _offset
    )
        internal
        pure
        returns (uint16 value_)
    {
        if (_offset > _encoded.length || _encoded.length - _offset < 2) {
            revert EvidenceReadOutOfBounds();
        }
        assembly ("memory-safe") {
            value_ := shr(240, calldataload(add(_encoded.offset, _offset)))
        }
    }

    /// @dev Loads one canonical big-endian u64 from calldata.
    function readU64(
        bytes calldata _encoded,
        uint256 _offset
    )
        internal
        pure
        returns (uint64 value_)
    {
        return _readU64(_encoded, _offset);
    }

    /// @dev Enforces the signed-header tier-local zero/nonzero grammar.
    function _validateTier(SlotChainTypes.SlotChainBlock memory _block) private pure {
        if (_block.tier == LibSlotChainConstants.NORMAL_TIER) {
            if (
                _block.episode != 0 || _block.recoveryRevision != 0
                    || _block.recoveryId != bytes32(0)
            ) {
                revert InvalidTierFields();
            }
        } else if (_block.tier == LibSlotChainConstants.SIGNED_RECOVERY_TIER) {
            if (
                _block.episode == 0 || _block.recoveryRevision == 0
                    || _block.recoveryId == bytes32(0) || _block.contextId != _block.recoveryId
            ) {
                revert InvalidTierFields();
            }
        } else {
            revert InvalidEvidenceTier();
        }
    }

    /// @dev Loads one uint256 from calldata.
    function _readU256(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (uint256 value_)
    {
        if (_offset > _encoded.length || _encoded.length - _offset < 32) {
            revert EvidenceReadOutOfBounds();
        }
        assembly ("memory-safe") {
            value_ := calldataload(add(_encoded.offset, _offset))
        }
    }

    /// @dev Loads one address from an exact packed 20-byte field.
    function _readAddress(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (address value_)
    {
        if (_offset > _encoded.length || _encoded.length - _offset < 20) {
            revert EvidenceReadOutOfBounds();
        }
        assembly ("memory-safe") {
            value_ := shr(96, calldataload(add(_encoded.offset, _offset)))
        }
    }

    /// @dev Loads one canonical big-endian u64 from calldata.
    function _readU64(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (uint64 value_)
    {
        if (_offset > _encoded.length || _encoded.length - _offset < 8) {
            revert EvidenceReadOutOfBounds();
        }
        assembly ("memory-safe") {
            value_ := shr(192, calldataload(add(_encoded.offset, _offset)))
        }
    }

    /// @dev Loads one canonical u8 from calldata.
    function _readU8(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (uint8 value_)
    {
        if (_offset >= _encoded.length) revert EvidenceReadOutOfBounds();
        assembly ("memory-safe") {
            value_ := byte(0, calldataload(add(_encoded.offset, _offset)))
        }
    }

    /// @dev Loads one bytes32 from calldata.
    function _readBytes32(
        bytes calldata _encoded,
        uint256 _offset
    )
        private
        pure
        returns (bytes32 value_)
    {
        if (_offset > _encoded.length || _encoded.length - _offset < 32) {
            revert EvidenceReadOutOfBounds();
        }
        assembly ("memory-safe") {
            value_ := calldataload(add(_encoded.offset, _offset))
        }
    }

    error EvidenceReadOutOfBounds();
    error InvalidEquivocationPair();
    error InvalidEvidenceTier();
    error InvalidPackedBlockLength();
    error InvalidSignature();
    error InvalidSignatureLength();
    error InvalidStructHashOrder();
    error InvalidTierFields();
    error SignerMismatch();
}
