// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../SlotChainTypes.sol";
import { LibSlotChainConstants } from "./LibSlotChainConstants.sol";

/// @title Canonical Slot Chain fixed-preimage encodings
/// @custom:security-contact security@taiko.xyz
library LibSlotChainEncoding {
    /// @dev Hashes the fixed Slot Chain EIP-712 domain.
    function hashEip712Domain(
        uint256 _chainId,
        address _verifyingContract
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encode(
                LibSlotChainConstants.EIP712_DOMAIN_TYPEHASH,
                LibSlotChainConstants.SLOT_CHAIN_NAME_HASH,
                LibSlotChainConstants.SLOT_CHAIN_VERSION_HASH,
                _chainId,
                _verifyingContract
            )
        );
    }

    /// @dev Hashes the exact 24-field EIP-712 SlotChainBlock tuple.
    function hashSlotChainBlock(SlotChainTypes.SlotChainBlock memory _block)
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            bytes.concat(LibSlotChainConstants.SLOT_CHAIN_BLOCK_TYPEHASH, abi.encode(_block))
        );
    }

    /// @dev Hashes an EIP-712 SlotChainBlock digest using the fixed domain name and version.
    function hashSlotChainDigest(
        uint256 _chainId,
        address _verifyingContract,
        SlotChainTypes.SlotChainBlock memory _block
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            bytes.concat(
                hex"1901",
                hashEip712Domain(_chainId, _verifyingContract),
                hashSlotChainBlock(_block)
            )
        );
    }

    /// @dev Hashes a canonical core with the normative u64 encoding of its uint48 block number.
    function hashCanonicalCore(SlotChainTypes.CanonicalCoreV2 memory _core)
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.CORE_DOMAIN,
                uint64(_core.l2BlockNumber),
                _core.tipHash,
                _core.tipSlot,
                _core.stateRoot,
                _core.messageCursor,
                _core.winningDataCommitment,
                _core.nextBaseFee,
                _core.nextExcessBlobGas,
                _core.terminalRoot,
                _core.terminalCount
            )
        );
    }

    /// @dev Binds a canonical core to the L1 block at which it became canonical.
    function hashBaseCanonical(
        bytes32 _coreHash,
        uint64 _canonicalizedAtBlock
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.CANONICAL_DOMAIN, _coreHash, _canonicalizedAtBlock
            )
        );
    }

    /// @dev Hashes the normal-mode context.
    function hashNormalContext(
        bytes32 _baseHash,
        uint64 _admissionVersion,
        bytes32 _admissionRoot,
        uint64 _anchorNumber,
        bytes32 _anchorHash
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.NORMAL_CONTEXT_DOMAIN,
                _baseHash,
                _admissionVersion,
                _admissionRoot,
                _anchorNumber,
                _anchorHash
            )
        );
    }

    /// @dev Hashes the data imported by a settlement-version migration.
    function hashMigrationData(
        uint256 _settlementChainId,
        uint256 _l2ChainId,
        bytes32 _tipHash,
        bytes32 _stateRoot,
        bytes32 _terminalRoot,
        uint64 _terminalCount
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.MIGRATION_DATA_DOMAIN,
                _settlementChainId,
                _l2ChainId,
                _tipHash,
                _stateRoot,
                _terminalRoot,
                _terminalCount
            )
        );
    }

    /// @dev Hashes a bounded candidate after enforcing strict slot order.
    function hashCandidate(
        bytes32 _baseHash,
        SlotChainTypes.CandidateBlockV2[] memory _rows
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        uint256 count = _rows.length;
        if (count == 0 || count > LibSlotChainConstants.MAX_CANDIDATE_BLOCKS) {
            revert InvalidCandidateCount();
        }

        bytes memory domain = bytes(LibSlotChainConstants.CANDIDATE_DOMAIN);
        bytes memory preimage = new bytes(domain.length + 32 + 2 + count * 144);
        uint256 offset = _writeBytes(preimage, 0, domain);
        offset = _writeBytes32(preimage, offset, _baseHash);
        offset = _writeU16(preimage, offset, uint16(count));
        uint64 priorSlot;
        for (uint256 i; i < count; ++i) {
            SlotChainTypes.CandidateBlockV2 memory row = _rows[i];
            if (i != 0 && row.slot <= priorSlot) revert NonIncreasingCandidateSlot(i);
            priorSlot = row.slot;
            offset = _writeU64(preimage, offset, row.slot);
            offset = _writeBytes32(preimage, offset, row.blockStructHash);
            offset = _writeBytes32(preimage, offset, row.blockHash);
            offset = _writeBytes32(preimage, offset, row.bodyRoot);
            offset = _writeBytes32(preimage, offset, row.dataManifestRoot);
            offset = _writeU64(preimage, offset, row.messageEnd);
        }
        assert(offset == preimage.length);
        return keccak256(preimage);
    }

    /// @dev Hashes the winning candidate and sealed-session list commitments.
    function hashWinningData(
        bytes32 _candidateHash,
        bytes32 _sessionListHash
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.WINNING_DATA_DOMAIN, _candidateHash, _sessionListHash
            )
        );
    }

    /// @dev Hashes a bounded schedule list after enforcing strict window order.
    function hashScheduleList(SlotChainTypes.ScheduleEntryV1[] memory _rows)
        internal
        pure
        returns (bytes32 hash_)
    {
        uint256 count = _rows.length;
        if (count > LibSlotChainConstants.MAX_SCHEDULE_WINDOWS) revert InvalidScheduleCount();
        bytes memory domain = bytes(LibSlotChainConstants.SCHEDULE_LIST_DOMAIN);
        bytes memory preimage = new bytes(domain.length + 1 + count * 72);
        uint256 offset = _writeBytes(preimage, 0, domain);
        offset = _writeU8(preimage, offset, uint8(count));
        uint64 priorWindow;
        for (uint256 i; i < count; ++i) {
            SlotChainTypes.ScheduleEntryV1 memory row = _rows[i];
            if (i != 0 && row.window <= priorWindow) revert NonIncreasingScheduleWindow(i);
            priorWindow = row.window;
            offset = _writeU64(preimage, offset, row.window);
            offset = _writeBytes32(preimage, offset, row.entryRoot);
            offset = _writeBytes32(preimage, offset, row.seed);
        }
        assert(offset == preimage.length);
        return keccak256(preimage);
    }

    /// @dev Hashes a bounded session list after enforcing strict session-id order and record caps.
    function hashSessionList(SlotChainTypes.SessionRefV1[] memory _rows)
        internal
        pure
        returns (bytes32 hash_)
    {
        uint256 count = _rows.length;
        if (count > LibSlotChainConstants.MAX_SESSION_REFS) revert InvalidSessionCount();
        bytes memory domain = bytes(LibSlotChainConstants.SESSION_LIST_DOMAIN);
        bytes memory preimage = new bytes(domain.length + 1 + count * 66);
        uint256 offset = _writeBytes(preimage, 0, domain);
        offset = _writeU8(preimage, offset, uint8(count));
        bytes32 priorSession;
        for (uint256 i; i < count; ++i) {
            SlotChainTypes.SessionRefV1 memory row = _rows[i];
            if (i != 0 && uint256(row.sessionId) <= uint256(priorSession)) {
                revert NonIncreasingSessionId(i);
            }
            if (row.recordCount > LibSlotChainConstants.MAX_DATA_RECORDS) {
                revert InvalidSessionRecordCount(i);
            }
            priorSession = row.sessionId;
            offset = _writeBytes32(preimage, offset, row.sessionId);
            offset = _writeU16(preimage, offset, row.recordCount);
            offset = _writeBytes32(preimage, offset, row.root);
        }
        assert(offset == preimage.length);
        return keccak256(preimage);
    }

    /// @dev Hashes the fixed execution-output tuple.
    function hashExecutionOutputs(SlotChainTypes.ExecutionOutputsV2 memory _outputs)
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.OUTPUTS_DOMAIN,
                _outputs.stateRoot,
                _outputs.transactionsRoot,
                _outputs.receiptsRoot,
                _outputs.logsBloomHash,
                _outputs.withdrawalsRoot,
                _outputs.terminalRoot,
                _outputs.terminalCount
            )
        );
    }

    /// @dev Hashes the exact 45-word settlement statement tuple.
    function hashSettlementStatement(SlotChainTypes.SettlementStatementV2 memory _statement)
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            bytes.concat(bytes(LibSlotChainConstants.STATEMENT_DOMAIN), abi.encode(_statement))
        );
    }

    /// @dev Hashes the immutable fields of a proof reward receipt; `claimed` is excluded.
    function hashRewardReceipt(SlotChainTypes.RewardReceiptV1 memory _receipt)
        internal
        pure
        returns (bytes32 hash_)
    {
        if (
            _receipt.candidateId == bytes32(0) || _receipt.beneficiary == address(0)
                || _receipt.rewardClass < LibSlotChainConstants.NORMAL_REWARD_CLASS
                || _receipt.rewardClass > LibSlotChainConstants.UNSIGNED_ESCAPE_REWARD_CLASS
                || _receipt.executionProfileHash == bytes32(0) || _receipt.committedAtBlock == 0
                || _receipt.committedAtTimestamp == 0
                || _receipt.claimUntil <= _receipt.committedAtTimestamp
        ) {
            revert InvalidRewardReceipt();
        }
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.REWARD_RECEIPT_DOMAIN,
                _receipt.candidateId,
                _receipt.beneficiary,
                _receipt.rewardClass,
                _receipt.rewardExecutionGas,
                _receipt.rewardPublishedBytes,
                _receipt.executionProfileHash,
                _receipt.committedAtBlock,
                _receipt.committedAtTimestamp,
                _receipt.claimUntil
            )
        );
    }

    /// @dev Hashes an occupied or canonical empty registry leaf.
    function hashRegistryLeaf(
        uint8 _index,
        bool _occupied,
        SlotChainTypes.RegistryCellV1 memory _cell
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (!_occupied) {
            return keccak256(
                abi.encodePacked(
                    LibSlotChainConstants.REGISTRY_LEAF_DOMAIN,
                    _index,
                    uint8(0),
                    bytes20(0),
                    uint192(0),
                    uint64(0),
                    uint64(0),
                    bytes32(0),
                    uint64(0)
                )
            );
        }
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.REGISTRY_LEAF_DOMAIN,
                _index,
                uint8(1),
                _cell.builder,
                _cell.bond,
                _cell.registrationIndex,
                _cell.effectiveL2Slot,
                _cell.trancheRoot,
                _cell.tombstonedAtL2Slot
            )
        );
    }

    /// @dev Hashes an occupied or canonical empty admission leaf.
    function hashAdmissionLeaf(
        uint16 _index,
        bool _occupied,
        uint8 _location,
        SlotChainTypes.RegistryCellV1 memory _cell
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (!_occupied) {
            return keccak256(
                abi.encodePacked(
                    LibSlotChainConstants.ADMISSION_LEAF_DOMAIN,
                    _index,
                    uint8(0),
                    uint8(0),
                    bytes20(0),
                    uint192(0),
                    uint64(0),
                    uint64(0),
                    uint64(0)
                )
            );
        }
        if (_location != 1 && _location != 2) revert InvalidAdmissionLocation();
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.ADMISSION_LEAF_DOMAIN,
                _index,
                uint8(1),
                _location,
                _cell.builder,
                _cell.bond,
                _cell.registrationIndex,
                _cell.effectiveL2Slot,
                _cell.tombstonedAtL2Slot
            )
        );
    }

    /// @dev Hashes one builder bond-tranche leaf.
    function hashTrancheLeaf(SlotChainTypes.TrancheLeafV1 memory _leaf)
        internal
        pure
        returns (bytes32 hash_)
    {
        if (_leaf.state > uint8(SlotChainTypes.TrancheState.SLASHED)) {
            revert InvalidTrancheState();
        }
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.TRANCHE_LEAF_DOMAIN,
                _leaf.index,
                _leaf.window,
                _leaf.state,
                _leaf.amount,
                _leaf.liableUntil
            )
        );
    }

    /// @dev Hashes an occupied or canonical empty ranked schedule entry.
    function hashRankedEntry(
        uint8 _rank,
        bool _occupied,
        SlotChainTypes.RegistryCellV1 memory _cell,
        bytes32 _trancheLeafHash
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (!_occupied) {
            return keccak256(
                abi.encodePacked(
                    LibSlotChainConstants.ENTRY_LEAF_DOMAIN,
                    _rank,
                    uint8(0),
                    bytes20(0),
                    uint192(0),
                    uint64(0),
                    uint64(0),
                    uint64(0),
                    bytes32(0)
                )
            );
        }
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.ENTRY_LEAF_DOMAIN,
                _rank,
                uint8(1),
                _cell.builder,
                _cell.bond,
                _cell.registrationIndex,
                _cell.effectiveL2Slot,
                _cell.tombstonedAtL2Slot,
                _trancheLeafHash
            )
        );
    }

    /// @dev Hashes one builder-registry tree node.
    function hashRegistryNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return _hashNode(LibSlotChainConstants.REGISTRY_NODE_DOMAIN, _height, _left, _right);
    }

    /// @dev Hashes one admission tree node.
    function hashAdmissionNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return _hashNode(LibSlotChainConstants.ADMISSION_NODE_DOMAIN, _height, _left, _right);
    }

    /// @dev Hashes one ranked-entry tree node.
    function hashRankedEntryNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return _hashNode(LibSlotChainConstants.ENTRY_NODE_DOMAIN, _height, _left, _right);
    }

    /// @dev Hashes one bond-tranche tree node.
    function hashTrancheNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return _hashNode(LibSlotChainConstants.TRANCHE_NODE_DOMAIN, _height, _left, _right);
    }

    /// @dev Encodes the exact 220-byte kind-0 forced descriptor.
    function encodeKind0Descriptor(SlotChainTypes.Kind0ForcedDescriptorV2 memory _descriptor)
        internal
        pure
        returns (bytes memory encoded_)
    {
        encoded_ = abi.encodePacked(
            _descriptor.sender,
            _descriptor.nonce,
            _descriptor.l2ChainId,
            _descriptor.rawTxHash,
            _descriptor.byteLength,
            _descriptor.gasLimit,
            _descriptor.accountedGas,
            _descriptor.maxFee,
            _descriptor.validUntil,
            _descriptor.refundAddress,
            _descriptor.enqueuedAt,
            _descriptor.dueAt,
            _descriptor.deposit
        );
        assert(encoded_.length == LibSlotChainConstants.KIND0_FORCED_DESCRIPTOR_LENGTH);
    }

    /// @dev Encodes the exact 541-byte kind-1 forced descriptor.
    function encodeKind1Descriptor(SlotChainTypes.Kind1ForcedDescriptorV11 memory _descriptor)
        internal
        pure
        returns (bytes memory encoded_)
    {
        if (
            _descriptor.liquidityFee == 0
                || _descriptor.refundMode != LibSlotChainConstants.REFUND_MODE_DIRECT
                || _descriptor.refundVault != address(0)
                || _descriptor.refundCapsuleHash != bytes32(0)
                || (_descriptor.value == 0 && _descriptor.fee == 0)
                || _descriptor.value > type(uint256).max - _descriptor.fee
        ) {
            revert InvalidKind1Descriptor();
        }
        encoded_ = new bytes(LibSlotChainConstants.KIND1_FORCED_DESCRIPTOR_LENGTH);
        uint256 offset = _writeKind1Identity(encoded_, _descriptor);
        offset = _writeKind1ValueTerms(encoded_, offset, _descriptor);
        offset = _writeKind1QueueTerms(encoded_, offset, _descriptor);
        assert(offset == encoded_.length);
    }

    /// @dev Hashes a kind-0 forced-message leaf.
    function hashForcedUserLeaf(
        uint64 _index,
        SlotChainTypes.Kind0ForcedDescriptorV2 memory _descriptor
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            bytes.concat(
                bytes(LibSlotChainConstants.FORCE_USER_DOMAIN),
                bytes8(_index),
                encodeKind0Descriptor(_descriptor)
            )
        );
    }

    /// @dev Hashes a kind-1 forced-message leaf.
    function hashForcedBridgeLeaf(
        uint64 _index,
        SlotChainTypes.Kind1ForcedDescriptorV11 memory _descriptor
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            bytes.concat(
                bytes(LibSlotChainConstants.FORCE_BRIDGE_DOMAIN),
                bytes8(_index),
                encodeKind1Descriptor(_descriptor)
            )
        );
    }

    /// @dev Hashes consumed forced descriptors and an optional immediately following boundary row.
    function hashForcedDescriptorList(
        uint64 _start,
        SlotChainTypes.ForcedDescriptorRowV2[] memory _consumed,
        bool _hasBoundary,
        SlotChainTypes.ForcedDescriptorRowV2 memory _boundary
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        uint256 consumedCount = _consumed.length;
        uint256 totalCount = consumedCount + (_hasBoundary ? 1 : 0);
        if (
            consumedCount > LibSlotChainConstants.MAX_CONSUMED_FORCED_ROWS
                || totalCount > LibSlotChainConstants.MAX_FORCED_DESCRIPTOR_ROWS
                || totalCount > uint256(type(uint64).max) - uint256(_start)
        ) {
            revert InvalidForcedRange();
        }
        uint256 payloadLength;
        for (uint256 i; i < consumedCount; ++i) {
            payloadLength += _validatedForcedRowLength(_consumed[i], _start, i);
        }
        if (_hasBoundary) {
            payloadLength += _validatedForcedRowLength(_boundary, _start, consumedCount);
        }
        bytes memory domain = bytes(LibSlotChainConstants.FORCE_DESCRIPTOR_LIST_DOMAIN);
        bytes memory preimage = new bytes(domain.length + 8 + 2 + 1 + payloadLength);
        uint256 offset = _writeBytes(preimage, 0, domain);
        offset = _writeU64(preimage, offset, _start);
        offset = _writeU16(preimage, offset, uint16(consumedCount));
        offset = _writeU8(preimage, offset, _hasBoundary ? 1 : 0);
        for (uint256 i; i < consumedCount; ++i) {
            offset = _writeForcedRow(preimage, offset, _consumed[i]);
        }
        if (_hasBoundary) offset = _writeForcedRow(preimage, offset, _boundary);
        assert(offset == preimage.length);
        return keccak256(preimage);
    }

    /// @dev Hashes the canonical empty forced leaf.
    function hashForcedEmptyLeaf() internal pure returns (bytes32 hash_) {
        return keccak256(bytes(LibSlotChainConstants.FORCE_EMPTY_DOMAIN));
    }

    /// @dev Hashes one fixed forced-tree node at a caller-independent domain.
    function hashForcedNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return _hashNode(LibSlotChainConstants.FORCE_NODE_DOMAIN, _height, _left, _right);
    }

    /// @dev Binds a forced-tree root to its occupied leaf count.
    function hashForcedRoot(
        uint64 _count,
        bytes32 _treeRoot
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return
            keccak256(abi.encodePacked(LibSlotChainConstants.FORCE_ROOT_DOMAIN, _count, _treeRoot));
    }

    /// @dev Hashes a data-session identifier.
    function hashSessionId(
        uint256 _chainId,
        address _dataSessions,
        address _owner,
        uint64 _nonce
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.SESSION_DOMAIN, _chainId, _dataSessions, _owner, _nonce
            )
        );
    }

    /// @dev Hashes a canonically framed list of raw signed transactions.
    function hashBody(bytes[] memory _transactions) internal pure returns (bytes32 hash_) {
        uint256 bodyLength = 4;
        for (uint256 i; i < _transactions.length; ++i) {
            if (_transactions[i].length > type(uint32).max) revert InvalidBodyLength();
            bodyLength += 4 + _transactions[i].length;
        }
        if (_transactions.length > type(uint32).max || bodyLength > type(uint32).max) {
            revert InvalidBodyLength();
        }
        bytes memory domain = bytes(LibSlotChainConstants.BODY_DOMAIN);
        bytes memory preimage = new bytes(domain.length + 4 + bodyLength);
        uint256 offset = _writeBytes(preimage, 0, domain);
        offset = _writeU32(preimage, offset, uint32(bodyLength));
        offset = _writeU32(preimage, offset, uint32(_transactions.length));
        for (uint256 i; i < _transactions.length; ++i) {
            bytes memory transaction = _transactions[i];
            offset = _writeU32(preimage, offset, uint32(transaction.length));
            offset = _writeBytes(preimage, offset, transaction);
        }
        assert(offset == preimage.length);
        return keccak256(preimage);
    }

    /// @dev Hashes one body chunk; the sole dynamic suffix is length-prefixed.
    function hashBodyChunk(
        bytes32 _fullBodyRoot,
        uint16 _blockOrdinal,
        uint16 _chunkIndex,
        uint16 _chunkCount,
        bytes memory _chunk
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (_chunk.length > type(uint32).max) revert InvalidBodyLength();
        return keccak256(
            bytes.concat(
                bytes(LibSlotChainConstants.BODY_CHUNK_DOMAIN),
                _fullBodyRoot,
                bytes2(_blockOrdinal),
                bytes2(_chunkIndex),
                bytes2(_chunkCount),
                bytes4(uint32(_chunk.length)),
                _chunk
            )
        );
    }

    /// @dev Hashes a fixed data-MMR leaf whose chunk root is supplied independently.
    function hashDataLeaf(SlotChainTypes.DataRecordV1 memory _record)
        internal
        pure
        returns (bytes32 hash_)
    {
        bytes memory domain = bytes(LibSlotChainConstants.DATA_LEAF_DOMAIN);
        bytes memory preimage = new bytes(domain.length + 232);
        uint256 offset = _writeBytes(preimage, 0, domain);
        offset = _writeBytes32(preimage, offset, _record.sessionId);
        offset = _writeU16(preimage, offset, _record.recordIndex);
        offset = _writeBytes32(preimage, offset, _record.versionedHash);
        offset = _writeBytes32(preimage, offset, _record.fullBodyRoot);
        offset = _writeU16(preimage, offset, _record.blockOrdinal);
        offset = _writeU16(preimage, offset, _record.chunkIndex);
        offset = _writeU16(preimage, offset, _record.chunkCount);
        offset = _writeU32(preimage, offset, _record.chunkLength);
        offset = _writeBytes32(preimage, offset, _record.chunkRoot);
        offset = _writeAddress(preimage, offset, _record.publisher);
        offset = _writeU64(preimage, offset, _record.validUntil);
        offset = _writeU256(preimage, offset, _record.z);
        offset = _writeU256(preimage, offset, _record.y);
        assert(offset == preimage.length);
        return keccak256(preimage);
    }

    /// @dev Hashes one data-MMR node.
    function hashDataNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return _hashNode(LibSlotChainConstants.DATA_NODE_DOMAIN, _height, _left, _right);
    }

    /// @dev Hashes a pre-encoded canonical peak list after validating its declared size.
    function hashDataBag(
        uint16 _recordCount,
        uint8 _peakCount,
        bytes memory _encodedPeaks
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (
            _recordCount > LibSlotChainConstants.MAX_DATA_RECORDS
                || _peakCount > LibSlotChainConstants.DATA_MMR_DEPTH
                || _encodedPeaks.length != uint256(_peakCount) * 33
        ) {
            revert InvalidDataBag();
        }

        uint256 expectedPeakCount;
        uint256 encodedPeakIndex;
        for (uint8 height; height < LibSlotChainConstants.DATA_MMR_DEPTH; ++height) {
            if ((_recordCount & (uint16(1) << height)) == 0) continue;
            if (
                encodedPeakIndex >= _peakCount
                    || _encodedPeaks[encodedPeakIndex * 33] != bytes1(height)
            ) {
                revert InvalidDataBag();
            }
            ++expectedPeakCount;
            ++encodedPeakIndex;
        }
        if (expectedPeakCount != _peakCount) revert InvalidDataBag();
        return keccak256(
            bytes.concat(
                bytes(LibSlotChainConstants.DATA_BAG_DOMAIN),
                bytes2(_recordCount),
                bytes1(_peakCount),
                _encodedPeaks
            )
        );
    }

    /// @dev Hashes the canonical empty manifest leaf.
    function hashManifestEmptyLeaf() internal pure returns (bytes32 hash_) {
        return keccak256(bytes(LibSlotChainConstants.MANIFEST_EMPTY_DOMAIN));
    }

    /// @dev Hashes one manifest leaf after binding it to its enclosing block ordinal.
    function hashManifestLeaf(
        uint16 _expectedBlockOrdinal,
        uint16 _position,
        SlotChainTypes.ManifestEntryV1 memory _entry
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (
            _expectedBlockOrdinal >= LibSlotChainConstants.MAX_CANDIDATE_BLOCKS
                || _position >= LibSlotChainConstants.MAX_MANIFEST_ENTRIES
                || _entry.blockOrdinal != _expectedBlockOrdinal
        ) {
            revert InvalidManifestBlockOrdinal(_position);
        }
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.MANIFEST_LEAF_DOMAIN,
                _position,
                _entry.blockOrdinal,
                _entry.sessionId,
                _entry.recordIndex,
                _entry.chunkIndex,
                _entry.chunkCount,
                _entry.chunkLength,
                _entry.fullBodyRoot,
                _entry.chunkRoot
            )
        );
    }

    /// @dev Hashes one manifest Merkle node.
    function hashManifestNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return _hashNode(LibSlotChainConstants.MANIFEST_NODE_DOMAIN, _height, _left, _right);
    }

    /// @dev Binds a manifest tree root to its entry count.
    function hashManifestRoot(
        uint16 _count,
        bytes32 _treeRoot
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (_count > LibSlotChainConstants.MAX_MANIFEST_ENTRIES) revert InvalidManifestCount();
        if (_count == 0 && _treeRoot != hashManifestEmptyLeaf()) revert InvalidManifestEmptyRoot();
        return keccak256(
            abi.encodePacked(LibSlotChainConstants.MANIFEST_ROOT_DOMAIN, _count, _treeRoot)
        );
    }

    /// @dev Hashes a bounded contiguous disposition list with checked exclusive-end arithmetic.
    function hashDispositions(
        uint64 _start,
        SlotChainTypes.DispositionV1[] memory _rows
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        uint256 count = _rows.length;
        if (
            count > LibSlotChainConstants.MAX_DISPOSITION_ROWS
                || count > uint256(type(uint64).max) - uint256(_start)
        ) {
            revert InvalidDispositionRange();
        }
        uint64 end = uint64(uint256(_start) + count);
        bytes memory domain = bytes(LibSlotChainConstants.DISPOSITIONS_DOMAIN);
        bytes memory preimage = new bytes(domain.length + 8 + 8 + 2 + count * 45);
        uint256 offset = _writeBytes(preimage, 0, domain);
        offset = _writeU64(preimage, offset, _start);
        offset = _writeU64(preimage, offset, end);
        offset = _writeU16(preimage, offset, uint16(count));
        for (uint256 i; i < count; ++i) {
            SlotChainTypes.DispositionV1 memory row = _rows[i];
            uint64 expectedIndex = uint64(uint256(_start) + i);
            if (row.queueIndex != expectedIndex) revert NonContiguousDisposition(i);
            if (row.disposition > uint8(SlotChainTypes.Disposition.BRIDGE_CREDIT)) {
                revert InvalidDisposition(i);
            }
            offset = _writeU64(preimage, offset, row.queueIndex);
            offset = _writeU8(preimage, offset, row.disposition);
            offset = _writeU32(preimage, offset, row.txIndex);
            offset = _writeBytes32(preimage, offset, row.resultHash);
        }
        assert(offset == preimage.length);
        return keccak256(preimage);
    }

    /// @dev Hashes the complete recovery identity tuple.
    function hashRecoveryId(SlotChainTypes.RecoveryContextV2 memory _context)
        internal
        pure
        returns (bytes32 hash_)
    {
        bytes memory domain = bytes(LibSlotChainConstants.RECOVERY_DOMAIN);
        bytes memory preimage = new bytes(domain.length + 237);
        uint256 offset = _writeBytes(preimage, 0, domain);
        offset = _writeU256(preimage, offset, _context.chainId);
        offset = _writeAddress(preimage, offset, _context.settlement);
        offset = _writeU64(preimage, offset, _context.episode);
        offset = _writeU64(preimage, offset, _context.revision);
        offset = _writeBytes32(preimage, offset, _context.baseHash);
        offset = _writeU64(preimage, offset, _context.roundStartSlot);
        offset = _writeU64(preimage, offset, _context.anchorNumber);
        offset = _writeBytes32(preimage, offset, _context.anchorHash);
        offset = _writeBytes32(preimage, offset, _context.forceRoot);
        offset = _writeU64(preimage, offset, _context.forceCutoff);
        offset = _writeU64(preimage, offset, _context.admissionVersion);
        offset = _writeBytes32(preimage, offset, _context.admissionRoot);
        offset = _writeU64(preimage, offset, _context.escapeSlot);
        offset = _writeU8(preimage, offset, _context.causes);
        assert(offset == preimage.length);
        return keccak256(preimage);
    }

    /// @dev Hashes the fixed EIP-712 source context tuple after enforcing the kind-1 domain.
    function hashSourceContext(SlotChainTypes.SourceContextV2 memory _context)
        internal
        pure
        returns (bytes32 hash_)
    {
        if (
            _context.protocolVersion == 0
                || _context.kind != LibSlotChainConstants.KIND_BRIDGE_CREDIT
        ) {
            revert InvalidSourceContext();
        }
        return keccak256(
            bytes.concat(LibSlotChainConstants.SOURCE_CONTEXT_TYPEHASH, abi.encode(_context))
        );
    }

    /// @dev Hashes the fixed EIP-712 destination context tuple.
    function hashDestinationContext(SlotChainTypes.DestinationContextV2 memory _context)
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            bytes.concat(LibSlotChainConstants.DESTINATION_CONTEXT_TYPEHASH, abi.encode(_context))
        );
    }

    /// @dev Hashes the fixed source-domain identity.
    function hashSourceDomain(SlotChainTypes.SourceDomainV4 memory _domain)
        internal
        pure
        returns (bytes32 hash_)
    {
        if (
            _domain.genesisHash == bytes32(0) || _domain.creditRegistry == address(0)
                || _domain.terminalVerifier == address(0) || _domain.bridge == address(0)
                || _domain.bridgeExecutionHash == bytes32(0)
                || _domain.registryNamespace == bytes32(0)
        ) {
            revert InvalidSourceDomain();
        }
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.SOURCE_DOMAIN_DOMAIN,
                _domain.sourceChainId,
                _domain.genesisHash,
                _domain.creditRegistry,
                _domain.terminalVerifier,
                _domain.bridge,
                _domain.bridgeExecutionHash,
                _domain.registryNamespace
            )
        );
    }

    /// @dev Hashes the fixed destination-domain identity.
    function hashDestinationDomain(SlotChainTypes.DestinationDomainV7 memory _domain)
        internal
        pure
        returns (bytes32 hash_)
    {
        if (
            _domain.genesisHash == bytes32(0) || _domain.bridgeInboxAdapter == address(0)
                || _domain.activeSettlementRouter == address(0)
                || _domain.terminalVerifier == address(0) || _domain.inboxApply == address(0)
                || _domain.inboxCreditStore == address(0)
                || _domain.protocolReleaseAuthority == address(0)
                || _domain.terminalDomainRegistrar == address(0)
                || _domain.terminalAccumulator == address(0)
                || _domain.nativeLiquidityPool == address(0) || _domain.bridge == address(0)
                || _domain.bridgeExecutionHash == bytes32(0)
                || _domain.infrastructureHash == bytes32(0) || _domain.namespace == bytes32(0)
        ) {
            revert InvalidDestinationDomain();
        }
        bytes memory domain = bytes(LibSlotChainConstants.DESTINATION_DOMAIN_DOMAIN);
        bytes memory preimage = new bytes(domain.length + 336);
        uint256 offset = _writeBytes(preimage, 0, domain);
        offset = _writeU64(preimage, offset, _domain.destinationChainId);
        offset = _writeBytes32(preimage, offset, _domain.genesisHash);
        offset = _writeAddress(preimage, offset, _domain.bridgeInboxAdapter);
        offset = _writeAddress(preimage, offset, _domain.activeSettlementRouter);
        offset = _writeAddress(preimage, offset, _domain.terminalVerifier);
        offset = _writeAddress(preimage, offset, _domain.inboxApply);
        offset = _writeAddress(preimage, offset, _domain.inboxCreditStore);
        offset = _writeAddress(preimage, offset, _domain.protocolReleaseAuthority);
        offset = _writeAddress(preimage, offset, _domain.terminalDomainRegistrar);
        offset = _writeAddress(preimage, offset, _domain.terminalAccumulator);
        offset = _writeAddress(preimage, offset, _domain.nativeLiquidityPool);
        offset = _writeAddress(preimage, offset, _domain.bridge);
        offset = _writeBytes32(preimage, offset, _domain.bridgeExecutionHash);
        offset = _writeBytes32(preimage, offset, _domain.infrastructureHash);
        offset = _writeBytes32(preimage, offset, _domain.namespace);
        assert(offset == preimage.length);
        return keccak256(preimage);
    }

    /// @dev Derives the canonical bridge-credit identity.
    function hashBridgeCreditId(
        uint64 _sourceChainId,
        bytes32 _sourceDomainId,
        uint64 _sourceEpoch,
        address _sourceBridge,
        bytes32 _destinationDomainId,
        bytes32 _messageHash,
        uint64 _liquidityFee
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (_liquidityFee == 0) revert InvalidBridgeCredit();
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.BRIDGE_CREDIT_ID_DOMAIN,
                _sourceChainId,
                _sourceDomainId,
                _sourceEpoch,
                _sourceBridge,
                _destinationDomainId,
                _messageHash,
                _liquidityFee
            )
        );
    }

    /// @dev Hashes the fixed bridge-credit result committed by a kind-1 forced row.
    function hashBridgeCreditResult(
        uint64 _index,
        SlotChainTypes.Kind1ForcedDescriptorV11 memory _descriptor
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (_descriptor.srcChainId > type(uint64).max) revert InvalidBridgeCredit();
        bytes32 creditId = hashBridgeCreditId(
            uint64(_descriptor.srcChainId),
            _descriptor.sourceDomainId,
            _descriptor.srcEpoch,
            _descriptor.srcBridge,
            _descriptor.destinationDomainId,
            _descriptor.msgHash,
            _descriptor.liquidityFee
        );
        bytes memory descriptor = encodeKind1Descriptor(_descriptor);
        uint256 resultDescriptorLength = descriptor.length - 80;
        bytes memory domain = bytes(LibSlotChainConstants.BRIDGE_RESULT_DOMAIN);
        bytes memory preimage = new bytes(domain.length + 8 + 32 + resultDescriptorLength);
        uint256 offset = _writeBytes(preimage, 0, domain);
        offset = _writeU64(preimage, offset, _index);
        offset = _writeBytes32(preimage, offset, creditId);
        assembly ("memory-safe") {
            mcopy(add(add(preimage, 0x20), offset), add(descriptor, 0x20), resultDescriptorLength)
        }
        return keccak256(preimage);
    }

    /// @dev Derives the canonical source Bridge escrow key.
    function hashBridgeEscrowId(bytes32 _creditId) internal pure returns (bytes32 hash_) {
        return keccak256(abi.encodePacked(LibSlotChainConstants.BRIDGE_ESCROW_DOMAIN, _creditId));
    }

    /// @dev Derives the exact inbox-credit storage slot.
    function hashInboxCreditSlot(bytes32 _creditId) internal pure returns (bytes32 hash_) {
        if (_creditId == bytes32(0)) revert InvalidBridgeCredit();
        return
            keccak256(abi.encodePacked(LibSlotChainConstants.INBOX_CREDIT_SLOT_DOMAIN, _creditId));
    }

    /// @dev Hashes one terminal credit leaf after enforcing settlement/terminal consistency.
    function hashTerminalLeaf(
        uint64 _index,
        bytes32 _destinationDomainId,
        address _destinationBridge,
        bytes32 _creditId,
        uint8 _terminal,
        bytes32 _liquiditySettlementHash
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (
            (_terminal == uint8(SlotChainTypes.TerminalState.DONE)
                    && _liquiditySettlementHash == bytes32(0))
                || (_terminal == uint8(SlotChainTypes.TerminalState.FAILED)
                    && _liquiditySettlementHash != bytes32(0))
                || _terminal < uint8(SlotChainTypes.TerminalState.DONE)
                || _terminal > uint8(SlotChainTypes.TerminalState.FAILED)
        ) {
            revert InvalidTerminalLeaf();
        }
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.TERMINAL_LEAF_DOMAIN,
                _index,
                _destinationDomainId,
                _destinationBridge,
                _creditId,
                _terminal,
                _liquiditySettlementHash
            )
        );
    }

    /// @dev Hashes the canonical empty terminal leaf.
    function hashTerminalEmptyLeaf() internal pure returns (bytes32 hash_) {
        return keccak256(bytes(LibSlotChainConstants.TERMINAL_EMPTY_DOMAIN));
    }

    /// @dev Hashes one terminal tree node.
    function hashTerminalNode(
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return _hashNode(LibSlotChainConstants.TERMINAL_NODE_DOMAIN, _height, _left, _right);
    }

    /// @dev Binds a terminal tree root to its occupied leaf count.
    function hashTerminalRoot(
        uint64 _count,
        bytes32 _treeRoot
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(LibSlotChainConstants.TERMINAL_ROOT_DOMAIN, _count, _treeRoot)
        );
    }

    /// @dev Hashes a successful liquidity settlement tuple.
    function hashLiquiditySettlement(SlotChainTypes.LiquiditySettlementV1 memory _settlement)
        internal
        pure
        returns (bytes32 hash_)
    {
        if (
            _settlement.ticketId == bytes32(0) || _settlement.l1Recipient == address(0)
                || _settlement.settlementAmount == 0
        ) {
            revert InvalidLiquiditySettlement();
        }
        return keccak256(
            abi.encodePacked(
                LibSlotChainConstants.LIQUIDITY_SETTLEMENT_DOMAIN,
                _settlement.ticketId,
                _settlement.l1Recipient,
                _settlement.settlementAmount
            )
        );
    }

    /// @dev Writes the identity prefix of one kind-1 descriptor.
    function _writeKind1Identity(
        bytes memory _output,
        SlotChainTypes.Kind1ForcedDescriptorV11 memory _descriptor
    )
        private
        pure
        returns (uint256 offset_)
    {
        offset_ = _writeBytes32(_output, 0, _descriptor.msgHash);
        offset_ = _writeU256(_output, offset_, _descriptor.srcChainId);
        offset_ = _writeBytes32(_output, offset_, _descriptor.sourceDomainId);
        offset_ = _writeU64(_output, offset_, _descriptor.srcEpoch);
        offset_ = _writeAddress(_output, offset_, _descriptor.srcBridge);
        offset_ = _writeBytes32(_output, offset_, _descriptor.bridgeExecutionHash);
        offset_ = _writeU64(_output, offset_, _descriptor.emittedAtBlock);
        offset_ = _writeBytes32(_output, offset_, _descriptor.destinationDomainId);
        offset_ = _writeU256(_output, offset_, _descriptor.destChainId);
    }

    /// @dev Writes the ownership and value terms of one kind-1 descriptor.
    function _writeKind1ValueTerms(
        bytes memory _output,
        uint256 _offset,
        SlotChainTypes.Kind1ForcedDescriptorV11 memory _descriptor
    )
        private
        pure
        returns (uint256 offset_)
    {
        offset_ = _writeU64(_output, _offset, _descriptor.enqueueBy);
        offset_ = _writeAddress(_output, offset_, _descriptor.sender);
        offset_ = _writeAddress(_output, offset_, _descriptor.srcOwner);
        offset_ = _writeAddress(_output, offset_, _descriptor.destOwner);
        offset_ = _writeU256(_output, offset_, _descriptor.value);
        offset_ = _writeU64(_output, offset_, _descriptor.fee);
        offset_ = _writeU64(_output, offset_, _descriptor.liquidityFee);
        offset_ = _writeBytes32(_output, offset_, _descriptor.calldataHash);
        offset_ = _writeU8(_output, offset_, _descriptor.refundMode);
        offset_ = _writeAddress(_output, offset_, _descriptor.refundVault);
        offset_ = _writeBytes32(_output, offset_, _descriptor.refundCapsuleHash);
        offset_ = _writeBytes32(_output, offset_, _descriptor.escrowId);
    }

    /// @dev Writes the queue-accounting suffix of one kind-1 descriptor.
    function _writeKind1QueueTerms(
        bytes memory _output,
        uint256 _offset,
        SlotChainTypes.Kind1ForcedDescriptorV11 memory _descriptor
    )
        private
        pure
        returns (uint256 offset_)
    {
        offset_ = _writeU32(_output, _offset, _descriptor.byteLength);
        offset_ = _writeU64(_output, offset_, _descriptor.accountedGas);
        offset_ = _writeAddress(_output, offset_, _descriptor.refundAddress);
        offset_ = _writeU64(_output, offset_, _descriptor.enqueuedAt);
        offset_ = _writeU64(_output, offset_, _descriptor.dueAt);
        offset_ = _writeU256(_output, offset_, _descriptor.deposit);
    }

    /// @dev Hashes a domain-separated binary node.
    function _hashNode(
        string memory _domain,
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        private
        pure
        returns (bytes32 hash_)
    {
        return keccak256(abi.encodePacked(_domain, _height, _left, _right));
    }

    /// @dev Validates one forced-descriptor row and returns its encoded byte length.
    function _validatedForcedRowLength(
        SlotChainTypes.ForcedDescriptorRowV2 memory _row,
        uint64 _start,
        uint256 _offset
    )
        private
        pure
        returns (uint256 length_)
    {
        if (_row.index != uint64(uint256(_start) + _offset)) {
            revert NonContiguousForcedDescriptor(_offset);
        }
        uint256 expectedLength;
        if (_row.kind == LibSlotChainConstants.KIND_USER_TRANSACTION) {
            expectedLength = LibSlotChainConstants.KIND0_FORCED_DESCRIPTOR_LENGTH;
        } else if (_row.kind == LibSlotChainConstants.KIND_BRIDGE_CREDIT) {
            expectedLength = LibSlotChainConstants.KIND1_FORCED_DESCRIPTOR_LENGTH;
        } else {
            revert InvalidForcedDescriptorKind(_offset);
        }
        if (_row.descriptorBytes.length != expectedLength) {
            revert InvalidForcedDescriptorLength(_offset);
        }
        return 11 + expectedLength;
    }

    /// @dev Writes one already validated forced-descriptor row.
    function _writeForcedRow(
        bytes memory _output,
        uint256 _offset,
        SlotChainTypes.ForcedDescriptorRowV2 memory _row
    )
        private
        pure
        returns (uint256 offset_)
    {
        offset_ = _writeU64(_output, _offset, _row.index);
        offset_ = _writeU8(_output, offset_, _row.kind);
        offset_ = _writeU16(_output, offset_, uint16(_row.descriptorBytes.length));
        offset_ = _writeBytes(_output, offset_, _row.descriptorBytes);
    }

    /// @dev Copies bytes into an allocated preimage.
    function _writeBytes(
        bytes memory _output,
        uint256 _offset,
        bytes memory _value
    )
        private
        pure
        returns (uint256 offset_)
    {
        uint256 length = _value.length;
        if (_offset + length > _output.length) revert EncodingBufferOverflow();
        assembly ("memory-safe") {
            mcopy(add(add(_output, 0x20), _offset), add(_value, 0x20), length)
        }
        return _offset + length;
    }

    /// @dev Writes one byte in big-endian field order.
    function _writeU8(
        bytes memory _output,
        uint256 _offset,
        uint8 _value
    )
        private
        pure
        returns (uint256 offset_)
    {
        if (_offset >= _output.length) revert EncodingBufferOverflow();
        assembly ("memory-safe") {
            mstore8(add(add(_output, 0x20), _offset), _value)
        }
        return _offset + 1;
    }

    /// @dev Writes two bytes in big-endian field order.
    function _writeU16(
        bytes memory _output,
        uint256 _offset,
        uint16 _value
    )
        private
        pure
        returns (uint256 offset_)
    {
        if (_offset + 2 > _output.length) revert EncodingBufferOverflow();
        assembly ("memory-safe") {
            mstore(add(add(_output, 0x20), _offset), shl(240, _value))
        }
        return _offset + 2;
    }

    /// @dev Writes four bytes in big-endian field order.
    function _writeU32(
        bytes memory _output,
        uint256 _offset,
        uint32 _value
    )
        private
        pure
        returns (uint256 offset_)
    {
        if (_offset + 4 > _output.length) revert EncodingBufferOverflow();
        assembly ("memory-safe") {
            mstore(add(add(_output, 0x20), _offset), shl(224, _value))
        }
        return _offset + 4;
    }

    /// @dev Writes eight bytes in big-endian field order.
    function _writeU64(
        bytes memory _output,
        uint256 _offset,
        uint64 _value
    )
        private
        pure
        returns (uint256 offset_)
    {
        if (_offset + 8 > _output.length) revert EncodingBufferOverflow();
        assembly ("memory-safe") {
            mstore(add(add(_output, 0x20), _offset), shl(192, _value))
        }
        return _offset + 8;
    }

    /// @dev Writes twenty address bytes in big-endian field order.
    function _writeAddress(
        bytes memory _output,
        uint256 _offset,
        address _value
    )
        private
        pure
        returns (uint256 offset_)
    {
        if (_offset + 20 > _output.length) revert EncodingBufferOverflow();
        assembly ("memory-safe") {
            mstore(add(add(_output, 0x20), _offset), shl(96, _value))
        }
        return _offset + 20;
    }

    /// @dev Writes one uint256 field in big-endian field order.
    function _writeU256(
        bytes memory _output,
        uint256 _offset,
        uint256 _value
    )
        private
        pure
        returns (uint256 offset_)
    {
        if (_offset + 32 > _output.length) revert EncodingBufferOverflow();
        assembly ("memory-safe") {
            mstore(add(add(_output, 0x20), _offset), _value)
        }
        return _offset + 32;
    }

    /// @dev Writes one bytes32 field.
    function _writeBytes32(
        bytes memory _output,
        uint256 _offset,
        bytes32 _value
    )
        private
        pure
        returns (uint256 offset_)
    {
        if (_offset + 32 > _output.length) revert EncodingBufferOverflow();
        assembly ("memory-safe") {
            mstore(add(add(_output, 0x20), _offset), _value)
        }
        return _offset + 32;
    }

    error InvalidCandidateCount();
    error NonIncreasingCandidateSlot(uint256 index);
    error InvalidScheduleCount();
    error NonIncreasingScheduleWindow(uint256 index);
    error InvalidSessionCount();
    error NonIncreasingSessionId(uint256 index);
    error InvalidSessionRecordCount(uint256 index);
    error InvalidRewardReceipt();
    error InvalidAdmissionLocation();
    error InvalidTrancheState();
    error InvalidKind1Descriptor();
    error InvalidForcedRange();
    error NonContiguousForcedDescriptor(uint256 index);
    error InvalidForcedDescriptorKind(uint256 index);
    error InvalidForcedDescriptorLength(uint256 index);
    error InvalidBodyLength();
    error InvalidDataBag();
    error InvalidManifestBlockOrdinal(uint256 position);
    error InvalidManifestCount();
    error InvalidManifestEmptyRoot();
    error InvalidDispositionRange();
    error NonContiguousDisposition(uint256 index);
    error InvalidDisposition(uint256 index);
    error InvalidTerminalLeaf();
    error InvalidLiquiditySettlement();
    error InvalidSourceContext();
    error InvalidSourceDomain();
    error InvalidDestinationDomain();
    error InvalidBridgeCredit();
    error EncodingBufferOverflow();
}
