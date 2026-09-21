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
                _core.nextExcessBlobGas
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
                _outputs.withdrawalsRoot
            )
        );
    }

    /// @dev Hashes the exact 41-word settlement statement tuple.
    function hashSettlementStatement(SlotChainTypes.SettlementStatementV2 memory _statement)
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            bytes.concat(bytes(LibSlotChainConstants.STATEMENT_DOMAIN), abi.encode(_statement))
        );
    }

    /// @dev Hashes the settlement-validity public-input schema identity that every settlement
    ///      verifier descriptor must pin.
    function hashSettlementValidityPublicInputSchema() internal pure returns (bytes32 hash_) {
        return
            keccak256(bytes(LibSlotChainConstants.SETTLEMENT_VALIDITY_PUBLIC_INPUT_SCHEMA_DOMAIN));
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
        if (_height >= LibSlotChainConstants.REGISTRY_TREE_DEPTH) revert InvalidNodeHeight();
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
        if (_height >= LibSlotChainConstants.ADMISSION_TREE_DEPTH) revert InvalidNodeHeight();
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
        if (_height >= LibSlotChainConstants.RANKED_ENTRY_TREE_DEPTH) {
            revert InvalidNodeHeight();
        }
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
        if (_height >= LibSlotChainConstants.TRANCHE_TREE_DEPTH) revert InvalidNodeHeight();
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

    /// @dev Encodes the exact 204-byte kind-0 admission body: the durable descriptor without the
    ///      queue-owned `enqueuedAt` and `dueAt` words.
    function encodeKind0Admission(SlotChainTypes.Kind0ForcedAdmissionV2 memory _admission)
        internal
        pure
        returns (bytes memory encoded_)
    {
        encoded_ = abi.encodePacked(
            _admission.sender,
            _admission.nonce,
            _admission.l2ChainId,
            _admission.rawTxHash,
            _admission.byteLength,
            _admission.gasLimit,
            _admission.accountedGas,
            _admission.maxFee,
            _admission.validUntil,
            _admission.refundAddress,
            _admission.deposit
        );
        assert(encoded_.length == LibSlotChainConstants.KIND0_FORCED_ADMISSION_LENGTH);
    }

    /// @dev Inserts the queue's live `enqueuedAt` and `dueAt` words immediately before the final
    ///      deposit word of a kind-0 admission body, yielding the durable queue descriptor.
    function toKind0Descriptor(
        SlotChainTypes.Kind0ForcedAdmissionV2 memory _admission,
        uint64 _enqueuedAt,
        uint64 _dueAt
    )
        internal
        pure
        returns (SlotChainTypes.Kind0ForcedDescriptorV2 memory descriptor_)
    {
        descriptor_ = SlotChainTypes.Kind0ForcedDescriptorV2({
            sender: _admission.sender,
            nonce: _admission.nonce,
            l2ChainId: _admission.l2ChainId,
            rawTxHash: _admission.rawTxHash,
            byteLength: _admission.byteLength,
            gasLimit: _admission.gasLimit,
            accountedGas: _admission.accountedGas,
            maxFee: _admission.maxFee,
            validUntil: _admission.validUntil,
            refundAddress: _admission.refundAddress,
            enqueuedAt: _enqueuedAt,
            dueAt: _dueAt,
            deposit: _admission.deposit
        });
    }

    /// @dev Hashes the kind-0 admission schema identity.
    function hashKind0AdmissionSchema() internal pure returns (bytes32 hash_) {
        return keccak256(bytes(LibSlotChainConstants.FORCE_USER_ADMISSION_DOMAIN));
    }

    /// @dev Hashes the forced descriptor schema identity.
    function hashForcedDescriptorSchema() internal pure returns (bytes32 hash_) {
        return keccak256(bytes(LibSlotChainConstants.FORCED_DESCRIPTOR_SCHEMA_DOMAIN));
    }

    /// @dev Hashes the exact 113-byte ForcedQueue constructor configuration preimage. Both local
    ///      addresses are nonzero and distinct.
    function hashForcedQueueConfig(
        address _activeSettlementRouter,
        address _initialActiveSettlement
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        if (
            _activeSettlementRouter == address(0) || _initialActiveSettlement == address(0)
                || _activeSettlementRouter == _initialActiveSettlement
        ) {
            revert InvalidForcedQueueConfig();
        }
        bytes memory preimage = abi.encodePacked(
            _activeSettlementRouter,
            _initialActiveSettlement,
            uint8(LibSlotChainConstants.FORCED_TREE_DEPTH),
            LibSlotChainConstants.FORCED_QUEUE_CAPACITY,
            hashForcedEmptyLeaf(),
            hashForcedDescriptorSchema()
        );
        assert(preimage.length == LibSlotChainConstants.FORCED_QUEUE_CONFIG_PREIMAGE_LENGTH);
        return keccak256(
            bytes.concat(
                bytes(LibSlotChainConstants.FORCED_QUEUE_CONFIG_DOMAIN),
                bytes2(uint16(preimage.length)),
                preimage
            )
        );
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
        if (_height >= LibSlotChainConstants.FORCED_TREE_DEPTH) revert InvalidNodeHeight();
        return _hashNode(LibSlotChainConstants.FORCE_NODE_DOMAIN, _height, _left, _right);
    }

    /// @dev Binds a forced-tree root to its occupied leaf count.
    function hashForcedRoot(uint64 _count, bytes32 _treeRoot)
        internal
        pure
        returns (bytes32 hash_)
    {
        return keccak256(
            abi.encodePacked(LibSlotChainConstants.FORCE_ROOT_DOMAIN, _count, _treeRoot)
        );
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
        if (_height >= LibSlotChainConstants.DATA_MMR_DEPTH) revert InvalidNodeHeight();
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
        if (_height >= LibSlotChainConstants.MANIFEST_TREE_DEPTH) revert InvalidNodeHeight();
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

    /// @dev Validates one kind-0 forced-descriptor row and returns its encoded byte length.
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
        if (_row.kind != LibSlotChainConstants.KIND_USER_TRANSACTION) {
            revert InvalidForcedDescriptorKind(_offset);
        }
        if (_row.descriptorBytes.length != LibSlotChainConstants.KIND0_FORCED_DESCRIPTOR_LENGTH) {
            revert InvalidForcedDescriptorLength(_offset);
        }
        return 11 + LibSlotChainConstants.KIND0_FORCED_DESCRIPTOR_LENGTH;
    }

    /// @dev Writes one already validated kind-0 forced-descriptor row.
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
    error InvalidNodeHeight();
    error InvalidForcedRange();
    error NonContiguousForcedDescriptor(uint256 index);
    error InvalidForcedDescriptorKind(uint256 index);
    error InvalidForcedDescriptorLength(uint256 index);
    error InvalidForcedQueueConfig();
    error InvalidBodyLength();
    error InvalidDataBag();
    error InvalidManifestBlockOrdinal(uint256 position);
    error InvalidManifestCount();
    error InvalidManifestEmptyRoot();
    error EncodingBufferOverflow();
}
