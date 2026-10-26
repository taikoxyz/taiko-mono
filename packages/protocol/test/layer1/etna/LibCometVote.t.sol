// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibEtnaVectors } from "./LibEtnaVectors.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";
import { LibEtnaKeys } from "src/layer1/etna/libs/LibEtnaKeys.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @dev Exposes the library through external calls.
contract LibCometVoteHarness {
    function chainDomain(
        uint256 _l1ChainId,
        uint256 _l2ChainId,
        address _inbox,
        uint48 _generation
    )
        external
        pure
        returns (bytes32)
    {
        return LibCometVote.chainDomain(_l1ChainId, _l2ChainId, _inbox, _generation);
    }

    function chainId(bytes32 _chainDomain) external pure returns (bytes memory) {
        return LibCometVote.chainId(_chainDomain);
    }

    function checkRanges(IEtnaStakingRegistry.Vote memory _vote) external pure {
        LibCometVote.checkRanges(_vote);
    }

    function isNil(IEtnaStakingRegistry.Vote memory _vote) external pure returns (bool) {
        return LibCometVote.isNil(_vote);
    }

    function sameBlockId(
        IEtnaStakingRegistry.Vote memory _a,
        IEtnaStakingRegistry.Vote memory _b
    )
        external
        pure
        returns (bool)
    {
        return LibCometVote.sameBlockId(_a, _b);
    }

    function signBytes(
        IEtnaStakingRegistry.Vote memory _vote,
        bytes memory _chainId
    )
        external
        pure
        returns (bytes memory)
    {
        return LibCometVote.signBytes(_vote, _chainId);
    }
}

contract LibCometVoteTest is CommonTest {
    /// @dev The number of `votes.cases` items.
    uint256 private constant _VOTE_CASES = 18;

    /// @dev 2^63: heights and timestamp seconds are below it (C7).
    uint64 private constant _TWO_POW_63 = uint64(1) << 63;

    /// @dev 2^31: rounds are below it (C7).
    uint32 private constant _TWO_POW_31 = uint32(1) << 31;

    LibCometVoteHarness internal comet;

    function setUp() public virtual override {
        super.setUp();
        comet = new LibCometVoteHarness();
    }

    // ---------------------------------------------------------------
    // chainDomain and chainId
    // ---------------------------------------------------------------

    /// @dev Every `chain_domains` case, generation 2^48 - 1 and another Inbox included: the
    /// digest is the vector's and the hash of its preimage, which opens with `DOMAIN_TAG`.
    function test_chainDomain_MatchesVectors() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".chain_domains");
        assertEq(n, 5);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".chain_domains", i);
            uint256 generation = _uint(j, p, "generation");
            assertLe(generation, type(uint48).max);
            bytes memory preimage = _bytes(j, p, "preimage");
            assertEq(bytes32(preimage), LibCometVote.DOMAIN_TAG, "preimage opens with the tag");

            bytes32 chainDomain = comet.chainDomain(
                _uint(j, p, "l1_chain_id"),
                _uint(j, p, "l2_chain_id"),
                _address(j, p, "inbox"),
                uint48(generation)
            );
            assertEq(chainDomain, _bytes32(j, p, "chain_domain"));
            assertEq(chainDomain, keccak256(preimage));
        }
    }

    /// @dev Every `chain_domains` digest maps to its 48-byte `chain_id`: "etna-" and 43
    /// base64url characters whose last one carries zero pad bits; every `votes.chain_ids` entry
    /// is the chain id of the deployment's domain for its Inbox and generation.
    function test_chainId_IsFortyEightAsciiBytes() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".chain_domains");
        assertEq(n, 5);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".chain_domains", i);
            bytes memory id = comet.chainId(_bytes32(j, p, "chain_domain"));
            assertEq(id.length, 48, "length");
            assertEq(string(id), _string(j, p, "chain_id"));
            assertEq(bytes5(id), bytes5("etna-"), "prefix");
            for (uint256 k = 5; k < 48; ++k) {
                assertLt(_base64UrlIndex(id[k]), 64, "base64url alphabet");
            }
            // 43 characters carry 258 bits; the last two are zero padding (RFC 4648 3.5).
            assertEq(_base64UrlIndex(id[47]) % 4, 0, "canonical pad bits");
        }

        n = LibEtnaVectors.lengthAt(j, ".votes.chain_ids");
        assertEq(n, 4);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".votes.chain_ids", i);
            bytes memory id = comet.chainId(
                comet.chainDomain(
                    _uint(j, ".deployment.", "l1_chain_id"),
                    _uint(j, ".deployment.", "l2_chain_id"),
                    _address(j, p, "inbox"),
                    uint48(_uint(j, p, "generation"))
                )
            );
            assertEq(string(id), _string(j, p, "chain_id"));
        }
    }

    // ---------------------------------------------------------------
    // signBytes
    // ---------------------------------------------------------------

    /// @dev Every `votes.cases` item, each under the chain id the library derives for its Inbox
    /// and generation, encodes to the bytes stock CometBFT v0.40.0 signed.
    function test_signBytes_MatchesCometBftForEveryVoteVector() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".votes.cases");
        assertEq(n, _VOTE_CASES);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".votes.cases", i);
            IEtnaStakingRegistry.Vote memory vote = _vote(j, p);
            bytes memory id = _derivedChainId(j, p, vote.generation);
            assertEq(comet.signBytes(vote, id), _bytes(j, p, "sign_bytes"), _string(j, p, "name"));
        }
    }

    /// @dev A zero round and a nil block id are omitted: the byte after the height field is the
    /// next field's tag (`0x22` for `precommit_a`, `0x2a` for `precommit_nil`, and `0x19` for the
    /// round-1 control `prevote_a_r1`), and the top-level tags are exactly the written fields.
    function test_signBytes_OmitsRoundZeroAndNilBlockId() external view {
        string memory j = LibEtnaVectors.load();

        bytes memory a = _signBytesOf(j, "precommit_a");
        assertEq(uint8(a[_afterHeight(a)]), 0x22, "precommit_a: block id follows the height");
        assertEq(_topLevelTags(a), hex"0811222a32", "precommit_a tags");

        bytes memory nil = _signBytesOf(j, "precommit_nil");
        assertEq(uint8(nil[_afterHeight(nil)]), 0x2a, "precommit_nil: timestamp follows height");
        assertEq(_topLevelTags(nil), hex"08112a32", "precommit_nil tags");

        bytes memory r1 = _signBytesOf(j, "prevote_a_r1");
        assertEq(uint8(r1[_afterHeight(r1)]), 0x19, "prevote_a_r1: round follows the height");
        assertEq(_topLevelTags(r1), hex"081119222a32", "prevote_a_r1 tags");
    }

    /// @dev A non-nil block id always writes its part set header, even an empty one (`12 00`),
    /// and omits a zero hash; the timestamp is always written, even a zero one (`2a 00`).
    function test_signBytes_WritesEmptyPartSetHeaderAndZeroTimestamp() external view {
        string memory j = LibEtnaVectors.load();

        string memory p = _caseNamed(j, "hash_only_block_id");
        bytes memory sb = _signBytesOf(j, "hash_only_block_id");
        assertEq(
            _fieldPayload(sb, 0x22),
            bytes.concat(hex"0a20", _bytes32(j, p, "vote.blockHash"), hex"1200"),
            "hash only"
        );

        p = _caseNamed(j, "partial_block_id");
        sb = _signBytesOf(j, "partial_block_id");
        assertEq(
            _fieldPayload(sb, 0x22),
            bytes.concat(hex"122408011220", _bytes32(j, p, "vote.partsHash")),
            "partial"
        );

        sb = _signBytesOf(j, "zero_timestamp");
        assertEq(_fieldPayload(sb, 0x2a), "", "zero timestamp");
        assertEq(_topLevelTags(sb), hex"0811222a32", "zero timestamp tags");
    }

    /// @dev The uvarint length prefix is one byte up to a 127-byte body and two above it:
    /// `max_values` (163 bytes) opens with `a3 01`, `precommit_nil` (71 bytes) with `47`, and the
    /// nil vote under 104- and 105-byte chain ids crosses from `7f` to `80 01`.
    function test_signBytes_LengthPrefixTakesTwoBytesAbove127() external view {
        string memory j = LibEtnaVectors.load();

        bytes memory max = _signBytesOf(j, "max_values");
        assertEq(max.length, 2 + 163, "max_values length");
        assertEq(uint8(max[0]), 0xa3, "low seven bits with the continuation bit");
        assertEq(uint8(max[1]), 0x01, "high bits");

        bytes memory nil = _signBytesOf(j, "precommit_nil");
        assertEq(nil.length, 1 + 71, "precommit_nil length");
        assertEq(uint8(nil[0]), 71);

        IEtnaStakingRegistry.Vote memory vote = _vote(j, _caseNamed(j, "precommit_nil"));
        bytes memory sb = comet.signBytes(vote, new bytes(104));
        assertEq(sb.length, 1 + 127);
        assertEq(uint8(sb[0]), 0x7f);
        sb = comet.signBytes(vote, new bytes(105));
        assertEq(sb.length, 2 + 128);
        assertEq(uint8(sb[0]), 0x80);
        assertEq(uint8(sb[1]), 0x01);
    }

    /// @dev Every vector signature recovers, over keccak256 of the library's sign bytes, to the
    /// vector key's address.
    function test_signatures_RecoverToVectorSigner() external view {
        string memory j = LibEtnaVectors.load();
        address signer = _address(j, ".votes.key.", "signer");
        assertEq(signer, vm.addr(_uint(j, ".votes.key.", "private_key")));
        uint256 n = LibEtnaVectors.lengthAt(j, ".votes.cases");
        assertEq(n, _VOTE_CASES);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".votes.cases", i);
            IEtnaStakingRegistry.Vote memory vote = _vote(j, p);
            bytes memory sb = comet.signBytes(vote, _derivedChainId(j, p, vote.generation));
            assertEq(
                LibEtnaKeys.recoverSigner(keccak256(sb), vote.signature),
                signer,
                _string(j, p, "name")
            );
        }
    }

    /// @dev At the C7 upper bounds, which no vector reaches (CometBFT rejects timestamps past
    /// year 9999), the seconds take a nine-byte varint and the encoding still decodes back.
    function test_signBytes_EncodesTheRangeUpperBounds() external view {
        IEtnaStakingRegistry.Vote memory vote = _maxVote();
        comet.checkRanges(vote);
        bytes memory id = comet.chainId(bytes32(0));
        bytes memory sb = comet.signBytes(vote, id);
        assertEq(
            _fieldPayload(sb, 0x2a),
            hex"08ffffffffffffffff7f10ff93ebdc03",
            "seconds 2^63 - 1, nanos 999,999,999"
        );
        _assertDecodesTo(sb, vote, id);
    }

    /// @dev Any in-range vote under any chain id decodes back to its fields, with zero fields
    /// omitted, fields in order and a nil block id never written.
    function testFuzz_signBytes_DecodesBackToTheVote(
        IEtnaStakingRegistry.Vote memory _vote,
        bytes memory _chainId,
        uint8 _zeroMask
    )
        external
        view
    {
        _vote.voteType = uint8(bound(_vote.voteType, 1, 2));
        _vote.height = uint64(bound(_vote.height, 1, _TWO_POW_63 - 1));
        _vote.round = uint32(bound(_vote.round, 0, _TWO_POW_31 - 1));
        _vote.timestampSeconds = uint64(bound(_vote.timestampSeconds, 0, _TWO_POW_63 - 1));
        _vote.timestampNanos = uint32(bound(_vote.timestampNanos, 0, 1e9 - 1));
        if (_zeroMask & 1 != 0) _vote.round = 0;
        if (_zeroMask & 2 != 0) _vote.blockHash = 0;
        if (_zeroMask & 4 != 0) _vote.partsTotal = 0;
        if (_zeroMask & 8 != 0) _vote.partsHash = 0;
        if (_zeroMask & 16 != 0) _vote.timestampSeconds = 0;
        if (_zeroMask & 32 != 0) _vote.timestampNanos = 0;
        // A chain id is never empty; the fuzzed tail varies its length across 127 bytes.
        _chainId = bytes.concat("etna-", _chainId);

        _assertDecodesTo(comet.signBytes(_vote, _chainId), _vote, _chainId);
    }

    // ---------------------------------------------------------------
    // checkRanges
    // ---------------------------------------------------------------

    function test_checkRanges_RejectsOutOfRange() external view {
        IEtnaStakingRegistry.Vote memory v = _baseVote();
        comet.checkRanges(v);

        v.voteType = 0;
        _assertInvalidVote(v, "voteType 0");
        v.voteType = 3;
        _assertInvalidVote(v, "voteType 3");
        v.voteType = type(uint8).max;
        _assertInvalidVote(v, "voteType 255");

        v = _baseVote();
        v.height = 0;
        _assertInvalidVote(v, "height 0");
        v.height = _TWO_POW_63;
        _assertInvalidVote(v, "height 2^63");
        v.height = type(uint64).max;
        _assertInvalidVote(v, "height 2^64 - 1");

        v = _baseVote();
        v.round = _TWO_POW_31;
        _assertInvalidVote(v, "round 2^31");
        v.round = type(uint32).max;
        _assertInvalidVote(v, "round 2^32 - 1");

        v = _baseVote();
        v.timestampSeconds = _TWO_POW_63;
        _assertInvalidVote(v, "seconds 2^63");
        v.timestampSeconds = type(uint64).max;
        _assertInvalidVote(v, "seconds 2^64 - 1");

        v = _baseVote();
        v.timestampNanos = 1e9;
        _assertInvalidVote(v, "nanos 10^9");
        v.timestampNanos = type(uint32).max;
        _assertInvalidVote(v, "nanos 2^32 - 1");

        v = _baseVote();
        v.signature = new bytes(64);
        _assertInvalidVote(v, "signature 64 bytes");
        v.signature = new bytes(66);
        _assertInvalidVote(v, "signature 66 bytes");
        v.signature = "";
        _assertInvalidVote(v, "signature empty");
    }

    /// @dev Every vector vote is in range, and so is each bound on its own and all of them at
    /// once: both vote types, height 1 and 2^63 - 1, round 2^31 - 1, seconds 2^63 - 1, nanos
    /// 999,999,999 and a nil block id.
    function test_checkRanges_AcceptsEveryVectorVoteAndTheUpperBounds() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".votes.cases");
        for (uint256 i; i < n; ++i) {
            comet.checkRanges(_vote(j, _at(".votes.cases", i)));
        }

        IEtnaStakingRegistry.Vote memory v = _baseVote();
        v.voteType = 1;
        comet.checkRanges(v);
        v.voteType = 2;
        v.height = 1;
        comet.checkRanges(v);
        v.height = _TWO_POW_63 - 1;
        comet.checkRanges(v);
        v = _baseVote();
        v.round = _TWO_POW_31 - 1;
        comet.checkRanges(v);
        v = _baseVote();
        v.timestampSeconds = _TWO_POW_63 - 1;
        comet.checkRanges(v);
        v = _baseVote();
        v.timestampNanos = 1e9 - 1;
        comet.checkRanges(v);
        v = _baseVote();
        v.blockHash = 0;
        v.partsTotal = 0;
        v.partsHash = 0;
        v.timestampSeconds = 0;
        v.timestampNanos = 0;
        v.generation = type(uint48).max;
        comet.checkRanges(v);
        comet.checkRanges(_maxVote());
    }

    // ---------------------------------------------------------------
    // isNil and sameBlockId
    // ---------------------------------------------------------------

    /// @dev Of the eight combinations of zero and nonzero hash, total and parts hash, only the
    /// all-zero one is nil, whatever the other fields hold.
    function test_isNil_RequiresAllThreeFieldsZero() external view {
        for (uint256 mask; mask < 8; ++mask) {
            IEtnaStakingRegistry.Vote memory v = _baseVote();
            v.blockHash = mask & 1 == 0 ? bytes32(0) : bytes32(uint256(1));
            v.partsTotal = mask & 2 == 0 ? 0 : 1;
            v.partsHash = mask & 4 == 0 ? bytes32(0) : bytes32(uint256(1) << 255);
            assertEq(comet.isNil(v), mask == 0, vm.toString(mask));
        }

        string memory j = LibEtnaVectors.load();
        assertTrue(comet.isNil(_vote(j, _caseNamed(j, "precommit_nil"))), "precommit_nil");
        assertFalse(comet.isNil(_vote(j, _caseNamed(j, "partial_block_id"))), "partial");
        assertFalse(comet.isNil(_vote(j, _caseNamed(j, "hash_only_block_id"))), "hash only");
    }

    /// @dev Two votes share a block id iff their hash, total and parts hash are all equal; the
    /// other fields do not matter, and nil differs from every non-nil block id.
    function test_sameBlockId_ComparesHashTotalAndPartsHash() external view {
        IEtnaStakingRegistry.Vote memory a = _baseVote();
        assertTrue(comet.sameBlockId(a, _copy(a)), "identical");

        IEtnaStakingRegistry.Vote memory b = _copy(a);
        b.blockHash = bytes32(uint256(a.blockHash) ^ 1);
        assertFalse(comet.sameBlockId(a, b), "hash");
        b = _copy(a);
        b.partsTotal = a.partsTotal + 1;
        assertFalse(comet.sameBlockId(a, b), "total");
        b = _copy(a);
        b.partsHash = bytes32(uint256(a.partsHash) ^ (uint256(1) << 255));
        assertFalse(comet.sameBlockId(a, b), "parts hash");

        b = _copy(a);
        b.voteType = 1;
        b.height = a.height + 1;
        b.round = a.round + 1;
        b.timestampSeconds = a.timestampSeconds + 1;
        b.timestampNanos = a.timestampNanos + 1;
        b.generation = a.generation + 1;
        b.signature = new bytes(65);
        assertTrue(comet.sameBlockId(a, b), "only the block id counts");

        string memory j = LibEtnaVectors.load();
        IEtnaStakingRegistry.Vote memory nil = _vote(j, _caseNamed(j, "precommit_nil"));
        assertTrue(comet.sameBlockId(nil, _copy(nil)), "nil, nil");
        assertFalse(comet.sameBlockId(nil, _vote(j, _caseNamed(j, "partial_block_id"))));
        assertFalse(comet.sameBlockId(nil, _vote(j, _caseNamed(j, "hash_only_block_id"))));
        assertFalse(comet.sameBlockId(_vote(j, _caseNamed(j, "precommit_a")), nil));
    }

    // ---------------------------------------------------------------
    // Helpers: vectors
    // ---------------------------------------------------------------

    /// @dev The vote of the `votes.cases` item at `_p`, with its signature.
    function _vote(
        string memory _j,
        string memory _p
    )
        private
        pure
        returns (IEtnaStakingRegistry.Vote memory v_)
    {
        string memory q = string.concat(_p, "vote.");
        v_.voteType = uint8(_uint(_j, q, "voteType"));
        v_.height = uint64(_uint(_j, q, "height"));
        v_.round = uint32(_uint(_j, q, "round"));
        v_.blockHash = _bytes32(_j, q, "blockHash");
        v_.partsTotal = uint32(_uint(_j, q, "partsTotal"));
        v_.partsHash = _bytes32(_j, q, "partsHash");
        v_.timestampSeconds = uint64(_uint(_j, q, "timestampSeconds"));
        v_.timestampNanos = uint32(_uint(_j, q, "timestampNanos"));
        v_.generation = uint48(_uint(_j, q, "generation"));
        v_.signature = _bytes(_j, _p, "signature");
    }

    /// @dev The chain id the library derives for the case at `_p`: the deployment's domain for the
    /// `votes.chain_ids` Inbox whose chain id the case was signed under. The entry's generation
    /// must be the vote's.
    function _derivedChainId(
        string memory _j,
        string memory _p,
        uint48 _generation
    )
        private
        view
        returns (bytes memory id_)
    {
        bytes32 signedUnder = keccak256(bytes(_string(_j, _p, "chain_id")));
        uint256 n = LibEtnaVectors.lengthAt(_j, ".votes.chain_ids");
        for (uint256 i; i < n; ++i) {
            string memory c = _at(".votes.chain_ids", i);
            if (keccak256(bytes(_string(_j, c, "chain_id"))) != signedUnder) continue;
            assertEq(_uint(_j, c, "generation"), _generation, "chain id generation");
            id_ = comet.chainId(
                comet.chainDomain(
                    _uint(_j, ".deployment.", "l1_chain_id"),
                    _uint(_j, ".deployment.", "l2_chain_id"),
                    _address(_j, c, "inbox"),
                    _generation
                )
            );
            assertEq(keccak256(id_), signedUnder, "derived chain id");
            return id_;
        }
        revert("case signed under an unlisted chain id");
    }

    /// @dev The library's sign bytes for the case named `_name`.
    function _signBytesOf(
        string memory _j,
        string memory _name
    )
        private
        view
        returns (bytes memory)
    {
        string memory p = _caseNamed(_j, _name);
        IEtnaStakingRegistry.Vote memory vote = _vote(_j, p);
        return comet.signBytes(vote, _derivedChainId(_j, p, vote.generation));
    }

    /// @dev The JSON path prefix of the `votes.cases` item named `_name`.
    function _caseNamed(string memory _j, string memory _name)
        private
        view
        returns (string memory)
    {
        uint256 n = LibEtnaVectors.lengthAt(_j, ".votes.cases");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".votes.cases", i);
            if (keccak256(bytes(_string(_j, p, "name"))) == keccak256(bytes(_name))) return p;
        }
        revert(string.concat("no vote case named ", _name));
    }

    // ---------------------------------------------------------------
    // Helpers: votes
    // ---------------------------------------------------------------

    /// @dev An in-range precommit with every field nonzero.
    function _baseVote() private pure returns (IEtnaStakingRegistry.Vote memory v_) {
        v_.voteType = 2;
        v_.height = 1000;
        v_.round = 3;
        v_.blockHash = keccak256("block");
        v_.partsTotal = 7;
        v_.partsHash = keccak256("parts");
        v_.timestampSeconds = 1_700_000_000;
        v_.timestampNanos = 123;
        v_.generation = 1;
        v_.signature = new bytes(65);
    }

    /// @dev The vote with every field at its C7 upper bound.
    function _maxVote() private pure returns (IEtnaStakingRegistry.Vote memory v_) {
        v_ = _baseVote();
        v_.height = _TWO_POW_63 - 1;
        v_.round = _TWO_POW_31 - 1;
        v_.partsTotal = type(uint32).max;
        v_.timestampSeconds = _TWO_POW_63 - 1;
        v_.timestampNanos = 1e9 - 1;
        v_.generation = type(uint48).max;
    }

    /// @dev A field-by-field copy; memory struct assignment would alias.
    function _copy(IEtnaStakingRegistry.Vote memory _v)
        private
        pure
        returns (IEtnaStakingRegistry.Vote memory c_)
    {
        c_.voteType = _v.voteType;
        c_.height = _v.height;
        c_.round = _v.round;
        c_.blockHash = _v.blockHash;
        c_.partsTotal = _v.partsTotal;
        c_.partsHash = _v.partsHash;
        c_.timestampSeconds = _v.timestampSeconds;
        c_.timestampNanos = _v.timestampNanos;
        c_.generation = _v.generation;
        c_.signature = _v.signature;
    }

    function _assertInvalidVote(
        IEtnaStakingRegistry.Vote memory _v,
        string memory _label
    )
        private
        view
    {
        try comet.checkRanges(_v) {
            assertTrue(false, string.concat(_label, ": accepted"));
        } catch (bytes memory err) {
            assertEq(err, abi.encodeWithSelector(IEtnaStakingRegistry.InvalidVote.selector), _label);
        }
    }

    // ---------------------------------------------------------------
    // Helpers: protobuf reading (a minimal decoder independent of the library)
    // ---------------------------------------------------------------

    /// @dev The offset just after the height field: the length prefix, `08 type` and
    /// `11 int64_le(height)`. Requires a one-byte type.
    function _afterHeight(bytes memory _sb) private pure returns (uint256) {
        (, uint256 o) = _readUvarint(_sb, 0);
        require(uint8(_sb[o]) == 0x08 && uint8(_sb[o + 2]) == 0x11, "type and height lead");
        return o + 2 + 9;
    }

    /// @dev The top-level field tags, in order, after checking the length prefix covers the rest
    /// exactly.
    function _topLevelTags(bytes memory _sb) private pure returns (bytes memory tags_) {
        (uint256 len, uint256 o) = _readUvarint(_sb, 0);
        assertEq(o + len, _sb.length, "length prefix");
        while (o < _sb.length) {
            uint8 tag = uint8(_sb[o]);
            tags_ = bytes.concat(tags_, bytes1(tag));
            o = _skipField(_sb, o);
        }
        assertEq(o, _sb.length, "fields end at the end");
    }

    /// @dev The payload of the top-level length-delimited field with tag `_tag`.
    function _fieldPayload(bytes memory _sb, uint8 _tag) private pure returns (bytes memory) {
        (, uint256 o) = _readUvarint(_sb, 0);
        while (o < _sb.length) {
            if (uint8(_sb[o]) == _tag) {
                (bytes memory payload,) = _readBytes(_sb, o + 1);
                return payload;
            }
            o = _skipField(_sb, o);
        }
        revert("field absent");
    }

    /// @dev Decodes `_sb` as a length-prefixed `CanonicalVote` and checks it holds exactly
    /// `_v`'s encoded fields and `_chainId`: fields appear once and in order, a present scalar is
    /// nonzero, the block id appears iff the vote is not nil and always has its part set header,
    /// and the timestamp and chain id are always present.
    function _assertDecodesTo(
        bytes memory _sb,
        IEtnaStakingRegistry.Vote memory _v,
        bytes memory _chainId
    )
        private
        pure
    {
        IEtnaStakingRegistry.Vote memory d;
        (uint256 len, uint256 o) = _readUvarint(_sb, 0);
        assertEq(o + len, _sb.length, "length prefix");
        // Bit `f` is set once field number `f` (tag >> 3) has been read.
        uint256 seen;
        bytes memory chainId;
        while (o < _sb.length) {
            uint256 field = uint8(_sb[o]) >> 3;
            assertLt(seen, 2 ** field, "fields once and in order");
            seen |= 2 ** field;
            (o, chainId) = _decodeField(_sb, o, d, chainId);
        }
        assertEq(seen & 0x60, 0x60, "timestamp (5) and chain id (6) always written");
        assertEq(d.voteType, _v.voteType, "type");
        assertEq(d.height, _v.height, "height");
        assertEq(d.round, _v.round, "round");
        assertEq(d.blockHash, _v.blockHash, "hash");
        assertEq(d.partsTotal, _v.partsTotal, "total");
        assertEq(d.partsHash, _v.partsHash, "parts hash");
        assertEq(d.timestampSeconds, _v.timestampSeconds, "seconds");
        assertEq(d.timestampNanos, _v.timestampNanos, "nanos");
        assertEq(chainId, _chainId, "chain id");
    }

    /// @dev Decodes the top-level field whose tag is at `_o` into `_d`, or returns it as the chain
    /// id; returns the offset after it.
    function _decodeField(
        bytes memory _sb,
        uint256 _o,
        IEtnaStakingRegistry.Vote memory _d,
        bytes memory _chainId
    )
        private
        pure
        returns (uint256 next_, bytes memory chainId_)
    {
        uint8 tag = uint8(_sb[_o]);
        chainId_ = _chainId;
        if (tag == 0x08) {
            uint256 x;
            (x, next_) = _readUvarint(_sb, _o + 1);
            assertNotEq(x, 0, "a written type is nonzero");
            _d.voteType = uint8(x);
        } else if (tag == 0x11 || tag == 0x19) {
            uint256 x = _readFixed64(_sb, _o + 1);
            next_ = _o + 9;
            assertNotEq(x, 0, "a written height or round is nonzero");
            if (tag == 0x11) _d.height = uint64(x);
            else _d.round = uint32(x);
        } else {
            bytes memory payload;
            (payload, next_) = _readBytes(_sb, _o + 1);
            if (tag == 0x22) _decodeBlockId(payload, _d);
            else if (tag == 0x2a) (_d.timestampSeconds, _d.timestampNanos) = _decodeTime(payload);
            else if (tag == 0x32) chainId_ = payload;
            else revert("unknown tag");
        }
    }

    /// @dev Decodes a `CanonicalBlockID` into `_d`: an optional 32-byte hash, then the always
    /// present part set header with an optional total and an optional 32-byte hash.
    function _decodeBlockId(bytes memory _b, IEtnaStakingRegistry.Vote memory _d) private pure {
        uint256 o;
        if (o < _b.length && uint8(_b[o]) == 0x0a) {
            bytes memory hash;
            (hash, o) = _readBytes(_b, o + 1);
            assertEq(hash.length, 32, "hash length");
            _d.blockHash = bytes32(hash);
            assertNotEq(_d.blockHash, 0, "a written hash is nonzero");
        }
        assertEq(uint8(_b[o]), 0x12, "part set header always written");
        (bytes memory psh, uint256 end) = _readBytes(_b, o + 1);
        assertEq(end, _b.length, "block id ends with the part set header");
        o = 0;
        if (o < psh.length && uint8(psh[o]) == 0x08) {
            uint256 total;
            (total, o) = _readUvarint(psh, o + 1);
            assertNotEq(total, 0, "a written total is nonzero");
            assertLe(total, type(uint32).max);
            _d.partsTotal = uint32(total);
        }
        if (o < psh.length) {
            assertEq(uint8(psh[o]), 0x12, "parts hash tag");
            bytes memory hash;
            (hash, o) = _readBytes(psh, o + 1);
            assertEq(hash.length, 32, "parts hash length");
            _d.partsHash = bytes32(hash);
            assertNotEq(_d.partsHash, 0, "a written parts hash is nonzero");
        }
        assertEq(o, psh.length, "part set header ends");
        assertFalse(
            _d.blockHash == 0 && _d.partsTotal == 0 && _d.partsHash == 0, "nil block id written"
        );
    }

    /// @dev Decodes a `Timestamp`: an optional seconds varint, then an optional nanos varint.
    function _decodeTime(bytes memory _b) private pure returns (uint64 seconds_, uint32 nanos_) {
        uint256 o;
        uint256 x;
        if (o < _b.length && uint8(_b[o]) == 0x08) {
            (x, o) = _readUvarint(_b, o + 1);
            assertNotEq(x, 0, "written seconds are nonzero");
            seconds_ = uint64(x);
        }
        if (o < _b.length) {
            assertEq(uint8(_b[o]), 0x10, "nanos tag");
            (x, o) = _readUvarint(_b, o + 1);
            assertNotEq(x, 0, "written nanos are nonzero");
            nanos_ = uint32(x);
        }
        assertEq(o, _b.length, "timestamp ends");
    }

    /// @dev Skips the field whose tag is at `_o`; returns the offset after it.
    function _skipField(bytes memory _b, uint256 _o) private pure returns (uint256) {
        uint8 wireType = uint8(_b[_o]) & 7;
        if (wireType == 0) {
            (, _o) = _readUvarint(_b, _o + 1);
            return _o;
        }
        if (wireType == 1) return _o + 9;
        require(wireType == 2, "unexpected wire type");
        (, _o) = _readBytes(_b, _o + 1);
        return _o;
    }

    /// @dev Reads a minimal uvarint at `_o`; returns it and the offset after it.
    function _readUvarint(
        bytes memory _b,
        uint256 _o
    )
        private
        pure
        returns (uint256 x_, uint256 next_)
    {
        for (uint256 shift;; shift += 7) {
            require(shift < 70, "uvarint too long");
            uint8 c = uint8(_b[_o++]);
            x_ |= uint256(c & 0x7f) << shift;
            if (c & 0x80 == 0) {
                require(c != 0 || shift == 0, "uvarint not minimal");
                return (x_, _o);
            }
        }
    }

    /// @dev Reads a uvarint length at `_o` and that many bytes after it; returns them and the
    /// offset after them.
    function _readBytes(
        bytes memory _b,
        uint256 _o
    )
        private
        pure
        returns (bytes memory out_, uint256 next_)
    {
        uint256 len;
        (len, _o) = _readUvarint(_b, _o);
        require(_o + len <= _b.length, "length past the end");
        out_ = new bytes(len);
        for (uint256 i; i < len; ++i) {
            out_[i] = _b[_o + i];
        }
        return (out_, _o + len);
    }

    /// @dev Reads eight little-endian bytes at `_o`.
    function _readFixed64(bytes memory _b, uint256 _o) private pure returns (uint256 x_) {
        for (uint256 i; i < 8; ++i) {
            x_ |= uint256(uint8(_b[_o + i])) << (8 * i);
        }
    }

    /// @dev The index of `_c` in the RFC 4648 section 5 alphabet, or 64 if absent.
    function _base64UrlIndex(bytes1 _c) private pure returns (uint256) {
        uint8 c = uint8(_c);
        if (c >= 0x41 && c <= 0x5a) return c - 0x41; // A-Z
        if (c >= 0x61 && c <= 0x7a) return c - 0x61 + 26; // a-z
        if (c >= 0x30 && c <= 0x39) return c - 0x30 + 52; // 0-9
        if (c == 0x2d) return 62; // -
        if (c == 0x5f) return 63; // _
        return 64;
    }

    // ---------------------------------------------------------------
    // Helpers: JSON
    // ---------------------------------------------------------------

    function _at(string memory _array, uint256 _index) private pure returns (string memory) {
        return string.concat(_array, "[", vm.toString(_index), "].");
    }

    function _uint(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (uint256)
    {
        return LibEtnaVectors.uintAt(_j, string.concat(_p, _field));
    }

    function _bytes32(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (bytes32)
    {
        return LibEtnaVectors.bytes32At(_j, string.concat(_p, _field));
    }

    function _address(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (address)
    {
        return LibEtnaVectors.addressAt(_j, string.concat(_p, _field));
    }

    function _bytes(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (bytes memory)
    {
        return LibEtnaVectors.bytesAt(_j, string.concat(_p, _field));
    }

    function _string(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (string memory)
    {
        return LibEtnaVectors.stringAt(_j, string.concat(_p, _field));
    }
}
