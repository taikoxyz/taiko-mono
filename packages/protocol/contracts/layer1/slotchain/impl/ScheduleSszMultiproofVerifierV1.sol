// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IScheduleForkVerifierV1 } from "../iface/IScheduleForkVerifierV1.sol";

/// @title Immutable current-fork Slot Chain schedule-carrier verifier
/// @notice Verifies the frozen 22-node SSZ frontier used by Deneb, Electra and Fulu.
/// @dev This artifact is stateless, non-proxy, unpausable and has no authority surface.
/// @custom:security-contact security@taiko.xyz
contract ScheduleSszMultiproofVerifierV1 is IScheduleForkVerifierV1 {
    uint256 private constant _WITNESS_BYTES = 672;
    uint256 private constant _CALLDATA_BYTES = 772;
    uint256 private constant _WITNESS_OFFSET_WORD = 0x40;
    uint256 private constant _WITNESS_DATA_OFFSET = 100;
    uint256 private constant _FRONTIER_NODES = 22;

    uint64 private constant _BEACON_SLOT_GINDEX = 8;
    uint64 private constant _EXECUTION_PAYLOAD_GINDEX = 201;
    uint64 private constant _STATE_ROOT_GINDEX = 6434;
    uint64 private constant _PREV_RANDAO_GINDEX = 6437;
    uint64 private constant _TIMESTAMP_GINDEX = 6441;
    uint64 private constant _BLOCK_HASH_GINDEX = 6444;

    bytes4 private constant _SFV1_MAGIC = 0x53465631;
    bytes4 private constant _SFC1_MAGIC = 0x53464331;
    bytes4 private constant _VERIFY_SELECTOR = 0x7e981e0b;

    bytes32 private constant _WITNESS_SCHEMA_HASH =
        0x4d3c1d3a7f2921c2f8e7526a2e8aa2c47dc6bdcd3dc9e2b14c58f2b9d39ed30f;
    bytes32 private constant _OUTPUT_SCHEMA_HASH =
        0x3a480130319b3cebce02d217988e89c83c6bd6e71ff93c25bc4fc38e51fbe2c0;

    string private constant _CONSTANTS_DOMAIN = "slot-chain-schedule-fork-constants-v1";
    string private constant _CONFIGURATION_DOMAIN = "slot-chain-schedule-fork-verifier-config-v1";
    string private constant _STATEMENT_DOMAIN = "slot-chain-schedule-carrier-statement-v1";

    bytes4 private immutable _forkDigest;
    uint64 private immutable _verificationGasLimit;
    bytes32 private immutable _configurationHash;

    /// @notice Initializes one immutable current-fork verifier identity.
    /// @param _forkDigest_ The nonzero configured L1 fork digest.
    /// @param _verificationGasLimit_ The ScheduleOracle call stipend, from 100,000 through 5,000,000.
    constructor(bytes4 _forkDigest_, uint64 _verificationGasLimit_) {
        if (
            _forkDigest_ == bytes4(0) || _verificationGasLimit_ < 100_000
                || _verificationGasLimit_ > 5_000_000
        ) {
            revert InvalidForkVerifierConfiguration();
        }
        if (IScheduleForkVerifierV1.verifyScheduleCarrierV1.selector != _VERIFY_SELECTOR) {
            revert InvalidForkVerifierConfiguration();
        }

        _forkDigest = _forkDigest_;
        _verificationGasLimit = _verificationGasLimit_;
        _configurationHash = keccak256(
            abi.encodePacked(
                _CONFIGURATION_DOMAIN,
                _forkDigest_,
                _forkConstantsHash(),
                _WITNESS_SCHEMA_HASH,
                _OUTPUT_SCHEMA_HASH,
                _VERIFY_SELECTOR,
                _verificationGasLimit_
            )
        );
    }

    /// @inheritdoc IScheduleForkVerifierV1
    function scheduleForkVerifierConfigV1()
        external
        view
        returns (
            bytes4 magic_,
            bytes4 forkDigest_,
            uint64 beaconSlotGindex_,
            uint64 executionPayloadGindex_,
            uint64 stateRootGindex_,
            uint64 prevRandaoGindex_,
            uint64 timestampGindex_,
            uint64 blockHashGindex_,
            bytes32 witnessSchemaHash_,
            bytes32 configurationHash_
        )
    {
        return (
            _SFV1_MAGIC,
            _forkDigest,
            _BEACON_SLOT_GINDEX,
            _EXECUTION_PAYLOAD_GINDEX,
            _STATE_ROOT_GINDEX,
            _PREV_RANDAO_GINDEX,
            _TIMESTAMP_GINDEX,
            _BLOCK_HASH_GINDEX,
            _WITNESS_SCHEMA_HASH,
            _configurationHash
        );
    }

    /// @inheritdoc IScheduleForkVerifierV1
    function verifyScheduleCarrierV1(
        bytes calldata _witness,
        bytes32 _beaconBlockRoot
    )
        external
        view
        returns (
            bytes4 magic_,
            bytes32 statementHash_,
            uint64 parentSlot_,
            uint64 executionBlockNumber_,
            uint64 payloadTimestamp_,
            bytes32 blockHash_,
            bytes32 stateRoot_,
            bytes32 prevRandao_
        )
    {
        _requireCanonicalCalldata(_witness);
        if (_beaconBlockRoot == bytes32(0)) revert InvalidBeaconBlockRoot();

        uint64 window = _readU64(_witness, 0);
        parentSlot_ = _readU64(_witness, 8);
        executionBlockNumber_ = _readU64(_witness, 16);
        payloadTimestamp_ = _readU64(_witness, 24);
        blockHash_ = _readWord(_witness, 32);
        stateRoot_ = _readWord(_witness, 64);
        prevRandao_ = _readWord(_witness, 96);
        if (
            parentSlot_ == 0 || executionBlockNumber_ == 0 || payloadTimestamp_ == 0
                || blockHash_ == bytes32(0) || stateRoot_ == bytes32(0) || prevRandao_ == bytes32(0)
        ) {
            revert InvalidScheduleCarrierWitness();
        }

        if (
            _multiproofRoot(
                    _witness, parentSlot_, payloadTimestamp_, blockHash_, stateRoot_, prevRandao_
                ) != _beaconBlockRoot
        ) {
            revert ScheduleCarrierRootMismatch();
        }

        statementHash_ = keccak256(
            abi.encodePacked(
                _STATEMENT_DOMAIN,
                block.chainid,
                msg.sender,
                _forkDigest,
                window,
                _beaconBlockRoot,
                parentSlot_,
                executionBlockNumber_,
                payloadTimestamp_,
                blockHash_,
                stateRoot_,
                prevRandao_
            )
        );
        return (
            _SFC1_MAGIC,
            statementHash_,
            parentSlot_,
            executionBlockNumber_,
            payloadTimestamp_,
            blockHash_,
            stateRoot_,
            prevRandao_
        );
    }

    /// @dev Executes the fixed 22-node SSZ frontier and consumes it into the sole gindex-one root.
    function _multiproofRoot(
        bytes calldata _witness,
        uint64 _parentSlot,
        uint64 _payloadTimestamp,
        bytes32 _blockHash,
        bytes32 _stateRoot,
        bytes32 _prevRandao
    )
        private
        pure
        returns (bytes32 root_)
    {
        uint64[] memory positions = new uint64[](_FRONTIER_NODES);
        bytes32[] memory nodes = new bytes32[](_FRONTIER_NODES);
        uint64[] memory derived = new uint64[](_FRONTIER_NODES - 1);

        positions[0] = _BEACON_SLOT_GINDEX;
        positions[1] = _STATE_ROOT_GINDEX;
        positions[2] = _PREV_RANDAO_GINDEX;
        positions[3] = _TIMESTAMP_GINDEX;
        positions[4] = _BLOCK_HASH_GINDEX;
        nodes[0] = _sszUint64Root(_parentSlot);
        nodes[1] = _stateRoot;
        nodes[2] = _prevRandao;
        nodes[3] = _sszUint64Root(_payloadTimestamp);
        nodes[4] = _blockHash;

        uint64[17] memory helpers = [
            uint64(6445),
            6440,
            6436,
            6435,
            3223,
            3221,
            3219,
            3216,
            403,
            200,
            101,
            51,
            24,
            13,
            9,
            7,
            5
        ];
        for (uint256 i; i < helpers.length; ++i) {
            positions[i + 5] = helpers[i];
            nodes[i + 5] = _readWord(_witness, 128 + i * 32);
        }
        _requireUniqueFrontier(positions);

        uint256 count = _FRONTIER_NODES;
        uint256 derivedCount;
        while (count > 1) {
            bool found;
            for (uint256 i; i < count && !found; ++i) {
                uint64 left = positions[i];
                if (left <= 1 || (left & 1) != 0) continue;
                for (uint256 j; j < count; ++j) {
                    if (positions[j] != left + 1) continue;
                    uint64 parent = left >> 1;
                    if (
                        _contains(positions, count, parent)
                            || _contains(derived, derivedCount, parent)
                    ) {
                        revert InvalidScheduleSszFrontier();
                    }

                    positions[i] = parent;
                    nodes[i] = sha256(bytes.concat(nodes[i], nodes[j]));
                    derived[derivedCount++] = parent;
                    uint256 last = count - 1;
                    if (j != last) {
                        positions[j] = positions[last];
                        nodes[j] = nodes[last];
                    }
                    count = last;
                    found = true;
                    break;
                }
            }
            if (!found) revert IncompleteScheduleSszProof();
        }
        if (positions[0] != 1) revert IncompleteScheduleSszProof();
        return nodes[0];
    }

    /// @dev Rejects ABI-equivalent dynamic offsets, gaps, suffixes and nonminimal tails.
    function _requireCanonicalCalldata(bytes calldata _witness) private pure {
        uint256 offsetWord;
        uint256 encodedLength;
        uint256 witnessOffset;
        assembly ("memory-safe") {
            offsetWord := calldataload(4)
            encodedLength := calldataload(68)
            witnessOffset := _witness.offset
        }
        if (
            _witness.length != _WITNESS_BYTES || msg.data.length != _CALLDATA_BYTES
                || offsetWord != _WITNESS_OFFSET_WORD || encodedLength != _WITNESS_BYTES
                || witnessOffset != _WITNESS_DATA_OFFSET
        ) {
            revert NonCanonicalScheduleCarrierCalldata();
        }
    }

    /// @dev Rejects repeated or ancestor-frontier positions before any hashing.
    function _requireUniqueFrontier(uint64[] memory _positions) private pure {
        for (uint256 i; i < _positions.length; ++i) {
            uint64 position = _positions[i];
            if (position <= 1) revert InvalidScheduleSszFrontier();
            for (uint256 j; j < i; ++j) {
                uint64 other = _positions[j];
                if (
                    position == other || _isAncestor(position, other)
                        || _isAncestor(other, position)
                ) {
                    revert InvalidScheduleSszFrontier();
                }
            }
        }
    }

    /// @dev Returns whether `_ancestor` is a strict generalized-index ancestor of `_descendant`.
    function _isAncestor(
        uint64 _ancestor,
        uint64 _descendant
    )
        private
        pure
        returns (bool result_)
    {
        while (_descendant > _ancestor) {
            _descendant >>= 1;
        }
        return _descendant == _ancestor;
    }

    /// @dev Returns whether one active or previously derived generalized index already exists.
    function _contains(
        uint64[] memory _positions,
        uint256 _count,
        uint64 _needle
    )
        private
        pure
        returns (bool result_)
    {
        for (uint256 i; i < _count; ++i) {
            if (_positions[i] == _needle) return true;
        }
    }

    /// @dev Returns the SSZ basic-type root for a uint64.
    function _sszUint64Root(uint64 _value) private pure returns (bytes32 root_) {
        uint64 reversed;
        for (uint256 i; i < 8; ++i) {
            reversed |= uint64((_value >> (i * 8)) & 0xff) << uint64((7 - i) * 8);
        }
        return bytes32(uint256(reversed) << 192);
    }

    /// @dev Reads one big-endian packed uint64 from the fixed witness.
    function _readU64(
        bytes calldata _witness,
        uint256 _offset
    )
        private
        pure
        returns (uint64 value_)
    {
        for (uint256 i; i < 8; ++i) {
            value_ = (value_ << 8) | uint8(_witness[_offset + i]);
        }
    }

    /// @dev Reads one exact word from the fixed witness.
    function _readWord(
        bytes calldata _witness,
        uint256 _offset
    )
        private
        pure
        returns (bytes32 value_)
    {
        assembly ("memory-safe") {
            value_ := calldataload(add(_witness.offset, _offset))
        }
    }

    /// @dev Returns the exact fixed-gindex commitment.
    function _forkConstantsHash() private pure returns (bytes32 hash_) {
        return keccak256(
            abi.encodePacked(
                _CONSTANTS_DOMAIN,
                _BEACON_SLOT_GINDEX,
                _EXECUTION_PAYLOAD_GINDEX,
                _STATE_ROOT_GINDEX,
                _PREV_RANDAO_GINDEX,
                _TIMESTAMP_GINDEX,
                _BLOCK_HASH_GINDEX
            )
        );
    }

    error IncompleteScheduleSszProof();
    error InvalidBeaconBlockRoot();
    error InvalidForkVerifierConfiguration();
    error InvalidScheduleCarrierWitness();
    error InvalidScheduleSszFrontier();
    error NonCanonicalScheduleCarrierCalldata();
    error ScheduleCarrierRootMismatch();
}
