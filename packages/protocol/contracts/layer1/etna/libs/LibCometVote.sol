// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { Base64 } from "solady/src/utils/Base64.sol";

/// @title LibCometVote
/// @notice The Etna CometBFT chain id and vote sign bytes, from which the staking registry checks
/// double-sign evidence (spec 3.1, 4.1, appendix A).
/// @dev `signBytes` rebuilds stock CometBFT v0.40.0 `VoteSignBytes`: the uvarint-length-prefixed
/// protobuf encoding of a `CanonicalVote`. A secp256k1eth vote signature is over keccak256 of
/// these bytes, so `ecrecover` recovers the validator's key address on L1.
/// @custom:security-contact security@taiko.xyz
library LibCometVote {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev The domain tag of `chainDomain`: "ETNA_COMET_DOMAIN_V1", right-padded with zero bytes.
    bytes32 internal constant DOMAIN_TAG = bytes32("ETNA_COMET_DOMAIN_V1");

    /// @dev 2^63: heights and timestamp seconds are positive int64 values below it.
    uint64 private constant _TWO_POW_63 = uint64(1) << 63;

    /// @dev 2^31: rounds are positive int32 values below it.
    uint32 private constant _TWO_POW_31 = uint32(1) << 31;

    /// @dev Timestamp nanoseconds are below 10^9.
    uint32 private constant _NANOS_PER_SECOND = 1e9;

    /// @dev The length of a signature `R ‖ S ‖ V`.
    uint256 private constant _SIGNATURE_LENGTH = 65;

    // ---------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------

    /// @dev The chain domain: keccak256(abi.encode(DOMAIN_TAG, uint256(l1ChainId),
    /// uint256(l2ChainId), address(inbox), uint48(generation))) (appendix A).
    /// @param _l1ChainId The L1 chain id.
    /// @param _l2ChainId The Etna L2 chain id.
    /// @param _inbox The Etna Inbox proxy.
    /// @param _generation The recovery generation.
    /// @return The chain domain.
    function chainDomain(
        uint256 _l1ChainId,
        uint256 _l2ChainId,
        address _inbox,
        uint48 _generation
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(DOMAIN_TAG, _l1ChainId, _l2ChainId, _inbox, _generation));
    }

    /// @dev The CometBFT chain id of a chain domain: "etna-" followed by the base64url encoding
    /// (RFC 4648 section 5, no padding) of its 32 bytes, 48 ASCII bytes in all (appendix A).
    /// @param _chainDomain The chain domain.
    /// @return The chain id.
    function chainId(bytes32 _chainDomain) internal pure returns (bytes memory) {
        return
            bytes.concat("etna-", bytes(Base64.encode(abi.encodePacked(_chainDomain), true, true)));
    }

    /// @dev Reverts with `InvalidVote` unless the vote type is 1 or 2, 1 <= height < 2^63,
    /// round < 2^31, timestamp seconds < 2^63, timestamp nanos < 10^9 and the signature is 65
    /// bytes. The signature's V and S ranges are left to `LibEtnaKeys.recoverSigner`.
    /// @param _vote The vote.
    function checkRanges(IEtnaStakingRegistry.Vote memory _vote) internal pure {
        if (
            (_vote.voteType != 1 && _vote.voteType != 2) || _vote.height == 0
                || _vote.height >= _TWO_POW_63 || _vote.round >= _TWO_POW_31
                || _vote.timestampSeconds >= _TWO_POW_63
                || _vote.timestampNanos >= _NANOS_PER_SECOND
                || _vote.signature.length != _SIGNATURE_LENGTH
        ) {
            revert IEtnaStakingRegistry.InvalidVote();
        }
    }

    /// @dev Whether the vote is nil: its block hash, part set total and part set hash are all
    /// zero.
    /// @param _vote The vote.
    /// @return Whether the vote is nil.
    function isNil(IEtnaStakingRegistry.Vote memory _vote) internal pure returns (bool) {
        return _vote.blockHash == 0 && _vote.partsTotal == 0 && _vote.partsHash == 0;
    }

    /// @dev Whether two votes have the same block id: equal block hash, part set total and part
    /// set hash. A nil vote's block id differs from every non-nil one.
    /// @param _a One vote.
    /// @param _b The other vote.
    /// @return Whether the block ids are equal.
    function sameBlockId(
        IEtnaStakingRegistry.Vote memory _a,
        IEtnaStakingRegistry.Vote memory _b
    )
        internal
        pure
        returns (bool)
    {
        return _a.blockHash == _b.blockHash && _a.partsTotal == _b.partsTotal
            && _a.partsHash == _b.partsHash;
    }

    /// @dev The CometBFT sign bytes of a vote, `uvarint(len(cv)) ‖ cv`, where `cv` is the
    /// `CanonicalVote` (appendix A):
    /// `[08 type] ‖ [11 int64_le(height)] ‖ [19 int64_le(round)] ‖ [22 len blockId] ‖
    /// 2a len timestamp ‖ 32 len chainId`, with `blockId = [0a 20 hash] ‖ 12 len psh`,
    /// `psh = [08 total] ‖ [12 20 partsHash]` and `timestamp = [08 seconds] ‖ [10 nanos]`.
    /// A bracketed field is omitted when zero, and the block id when the vote is nil; a non-nil
    /// block id always carries its part set header, possibly empty (`12 00`), and the timestamp
    /// is always written, possibly empty (`2a 00`). Type, total, seconds, nanos and every `len`
    /// are uvarints. For a vote `checkRanges` accepts this is CometBFT's protobuf encoding; above
    /// those ranges (e.g. nanos >= 2^31, an int32 CometBFT sign-extends) it may differ.
    /// @param _vote The vote; its generation and signature are not encoded.
    /// @param _chainId The chain id the vote is signed under, as returned by `chainId`; never
    /// empty, so it is always written.
    /// @return The sign bytes.
    function signBytes(
        IEtnaStakingRegistry.Vote memory _vote,
        bytes memory _chainId
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory cv = bytes.concat(
            _varintField(0x08, _vote.voteType),
            _fixed64Field(0x11, _vote.height),
            _fixed64Field(0x19, _vote.round),
            isNil(_vote) ? bytes("") : _bytesField(0x22, _blockId(_vote)),
            _bytesField(
                0x2a,
                bytes.concat(
                    _varintField(0x08, _vote.timestampSeconds),
                    _varintField(0x10, _vote.timestampNanos)
                )
            ),
            _bytesField(0x32, _chainId)
        );
        return bytes.concat(_uvarint(cv.length), cv);
    }

    // ---------------------------------------------------------------
    // Private functions
    // ---------------------------------------------------------------

    /// @dev The `CanonicalBlockID` of a non-nil vote: `[0a 20 hash] ‖ 12 len psh` with
    /// `psh = [08 total] ‖ [12 20 partsHash]`.
    /// @param _vote The vote.
    /// @return The encoded block id.
    function _blockId(IEtnaStakingRegistry.Vote memory _vote) private pure returns (bytes memory) {
        return bytes.concat(
            _hashField(0x0a, _vote.blockHash),
            _bytesField(
                0x12,
                bytes.concat(
                    _varintField(0x08, _vote.partsTotal), _hashField(0x12, _vote.partsHash)
                )
            )
        );
    }

    /// @dev `_tag ‖ uvarint(_value)`, or nothing when `_value` is zero.
    /// @param _tag The field tag.
    /// @param _value The value.
    /// @return The encoded field.
    function _varintField(uint8 _tag, uint256 _value) private pure returns (bytes memory) {
        return _value == 0 ? bytes("") : bytes.concat(bytes1(_tag), _uvarint(_value));
    }

    /// @dev `_tag ‖ int64_le(_value)`, or nothing when `_value` is zero.
    /// @param _tag The field tag.
    /// @param _value The value.
    /// @return The encoded field.
    function _fixed64Field(uint8 _tag, uint64 _value) private pure returns (bytes memory) {
        if (_value == 0) return "";
        // Reverse the eight bytes so that the big-endian `bytes8` reads little-endian.
        uint64 v = _value;
        v = ((v & 0xFF00FF00FF00FF00) >> 8) | ((v & 0x00FF00FF00FF00FF) << 8);
        v = ((v & 0xFFFF0000FFFF0000) >> 16) | ((v & 0x0000FFFF0000FFFF) << 16);
        v = (v >> 32) | (v << 32);
        return bytes.concat(bytes1(_tag), bytes8(v));
    }

    /// @dev `_tag ‖ 20 ‖ _hash`, or nothing when `_hash` is zero.
    /// @param _tag The field tag.
    /// @param _hash The hash.
    /// @return The encoded field.
    function _hashField(uint8 _tag, bytes32 _hash) private pure returns (bytes memory) {
        return _hash == 0 ? bytes("") : bytes.concat(bytes1(_tag), bytes1(0x20), _hash);
    }

    /// @dev `_tag ‖ uvarint(len(_payload)) ‖ _payload`, written even when `_payload` is empty.
    /// @param _tag The field tag.
    /// @param _payload The payload.
    /// @return The encoded field.
    function _bytesField(uint8 _tag, bytes memory _payload) private pure returns (bytes memory) {
        return bytes.concat(bytes1(_tag), _uvarint(_payload.length), _payload);
    }

    /// @dev The protobuf uvarint of `_value`: seven bits per byte, least significant group
    /// first, the high bit set on every byte but the last.
    /// @param _value The value.
    /// @return out_ The encoding, one byte for a value below 128.
    function _uvarint(uint256 _value) private pure returns (bytes memory out_) {
        uint256 n = 1;
        for (uint256 rest = _value >> 7; rest != 0; rest >>= 7) {
            ++n;
        }
        out_ = new bytes(n);
        for (uint256 i; i < n - 1; ++i) {
            out_[i] = bytes1(uint8(_value & 0x7f) | 0x80);
            _value >>= 7;
        }
        out_[n - 1] = bytes1(uint8(_value));
    }
}
