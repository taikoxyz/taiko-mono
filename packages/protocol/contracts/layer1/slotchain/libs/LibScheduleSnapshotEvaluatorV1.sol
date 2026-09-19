// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../../../shared/slotchain/SlotChainTypes.sol";
import { LibMptProof } from "../../../shared/slotchain/libs/LibMptProof.sol";
import { LibSlotChainConstants } from "../../../shared/slotchain/libs/LibSlotChainConstants.sol";
import { LibSlotChainEncoding } from "../../../shared/slotchain/libs/LibSlotChainEncoding.sol";
import { LibSlotChainFixedTrees } from "../../../shared/slotchain/libs/LibSlotChainFixedTrees.sol";
import { LibScheduleForkVerifierCallV1 } from "./LibScheduleForkVerifierCallV1.sol";
import { LibScheduleSealWitnessV1 } from "./LibScheduleSealWitnessV1.sol";

/// @title Authenticated Schedule builder-snapshot evaluation
/// @custom:security-contact security@taiko.xyz
library LibScheduleSnapshotEvaluatorV1 {
    bytes4 internal constant HEADER_MAGIC = 0x42524831; // BRH1
    uint8 internal constant HEADER_VERSION = 1;

    bytes32 internal constant HEADER_STORAGE_TRIE_KEY =
        0x3dc336ad17079f9525d2b0708a8773321ab29957d522a6f2d10fc522b7362aec;
    bytes32 internal constant ROOT_STORAGE_TRIE_KEY =
        0x04bafd6333ae949248e59a002ce1fbccb8a4bc8da3a0c3228ae523d727170880;

    uint256 internal constant WINDOW_SECONDS = 384;
    uint256 internal constant TRANCHE_INDEX_MASK = 511;

    /// @dev Immutable Schedule and BuilderRegistry values needed to validate one snapshot.
    struct SnapshotContext {
        address builderRegistry;
        bytes32 builderRegistryRuntimeHash;
        uint64 window;
        uint64 genesisTimestamp;
        uint64 firstManagedWindow;
        uint64 lastManagedWindow;
        uint64 evidenceDelaySeconds;
        uint64 reorgMarginSeconds;
        uint192 leasePerWindowAtomic;
    }

    struct RegistryHeader {
        uint8 activeCount;
        uint64 registryMutationVersion;
        uint64 admissionVersion;
        uint64 nextRegistrationIndex;
    }

    struct Candidate {
        SlotChainTypes.RegistryCellV1 cell;
        bytes32 trancheLeafHash;
    }

    struct Work {
        bytes32[64] registryLeaves;
        bytes32[64] entryLeaves;
        address[64] seenBuilders;
        uint64[64] seenRegistrationIndices;
        Candidate[64] ranked;
        uint8 presentCount;
        uint8 eligibleCount;
    }

    struct Traversal {
        LibScheduleSealWitnessV1.Witness parsed;
        SnapshotContext snapshot;
        uint64 nextRegistrationIndex;
        uint64 sourceL2Slot;
    }

    /// @dev Authenticates BuilderRegistry under the parent payload state root, reconstructs the
    ///      complete 64-cell registry and every present cell's window tranche, filters and ranks
    ///      eligible builders, and returns the exact omission-free ranked-entry root. This
    ///      reparses its own exact witness slice so offsets cannot be reused with other calldata.
    /// @param _witness The complete canonical ScheduleSealWitnessV1 byte string.
    /// @param _context The pinned Registry identity, window bounds and economic timing values.
    /// @param _carrier The carrier result already authenticated by the exact fork-verifier call.
    /// @return entryRoot_ The exact 64-leaf ranked-entry commitment for the requested window.
    function evaluate(
        bytes calldata _witness,
        SnapshotContext memory _context,
        LibScheduleForkVerifierCallV1.Carrier memory _carrier
    )
        internal
        pure
        returns (bytes32 entryRoot_)
    {
        _requireContext(_context, _carrier);
        LibScheduleSealWitnessV1.Witness memory parsed =
            LibScheduleSealWitnessV1.parseFraming(_witness);

        bytes32 storageRoot = LibMptProof.verifyAccount(
            _witness,
            parsed.accountPath,
            _carrier.stateRoot,
            _context.builderRegistry,
            _context.builderRegistryRuntimeHash
        );
        RegistryHeader memory header = _decodeHeader(
            LibMptProof.verifyStorageValue(
                _witness, parsed.headerSlotPath, storageRoot, HEADER_STORAGE_TRIE_KEY
            )
        );
        bytes32 authenticatedRegistryRoot = LibMptProof.verifyStorageValue(
            _witness, parsed.rootSlotPath, storageRoot, ROOT_STORAGE_TRIE_KEY
        );

        Traversal memory traversal = Traversal({
            parsed: parsed,
            snapshot: _context,
            nextRegistrationIndex: header.nextRegistrationIndex,
            sourceL2Slot: _carrier.payloadTimestamp >= _context.genesisTimestamp
                ? _carrier.payloadTimestamp - _context.genesisTimestamp
                : 0
        });
        Work memory work;
        _consumeCells(_witness, traversal, work);

        if (work.presentCount != parsed.presentCount || work.presentCount != header.activeCount) {
            revert ActiveBuilderCountMismatch(header.activeCount, work.presentCount);
        }

        bytes32 reconstructedRegistryRoot = work.presentCount == 0
            ? LibSlotChainFixedTrees.emptyRegistryRoot()
            : LibSlotChainFixedTrees.registryRoot(work.registryLeaves);
        if (reconstructedRegistryRoot != authenticatedRegistryRoot) {
            revert BuilderRegistryRootMismatch();
        }
        if (work.eligibleCount == 0) return LibSlotChainFixedTrees.emptyRankedEntryRoot();

        for (uint256 rank; rank < LibSlotChainConstants.RANKED_ENTRY_LEAF_COUNT; ++rank) {
            bool occupied = rank < work.eligibleCount;
            Candidate memory candidate = work.ranked[rank];
            work.entryLeaves[rank] = LibSlotChainEncoding.hashRankedEntry(
                uint8(rank), occupied, candidate.cell, candidate.trancheLeafHash
            );
        }
        return LibSlotChainFixedTrees.rankedEntryRoot(work.entryLeaves);
    }

    /// @dev Decodes and validates the exact big-endian BRH1 storage word.
    function _decodeHeader(bytes32 _word) private pure returns (RegistryHeader memory header_) {
        uint256 value = uint256(_word);
        if (
            bytes4(_word) != HEADER_MAGIC || uint8(value >> 216) != HEADER_VERSION
                || uint8(value >> 208) > LibSlotChainConstants.REGISTRY_CELL_COUNT
                || uint16(value >> 192) != 0
        ) {
            revert InvalidBuilderRegistryHeader();
        }
        header_.activeCount = uint8(value >> 208);
        header_.registryMutationVersion = uint64(value >> 128);
        header_.admissionVersion = uint64(value >> 64);
        header_.nextRegistrationIndex = uint64(value);
    }

    /// @dev Streams all 64 cells and the ascending present-cell record sequence.
    function _consumeCells(
        bytes calldata _witness,
        Traversal memory _traversal,
        Work memory _work
    )
        private
        pure
    {
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        for (uint256 index; index < LibSlotChainConstants.REGISTRY_CELL_COUNT; ++index) {
            uint256 cellOffset =
                LibScheduleSealWitnessV1.registryCellOffset(_traversal.parsed, index);
            bool present = _readU8(_witness, cellOffset) == 1;
            if (!present) {
                _work.registryLeaves[index] =
                    LibSlotChainEncoding.hashRegistryLeaf(uint8(index), false, emptyCell);
                continue;
            }
            _consumePresentCell(_witness, cellOffset, uint8(index), _traversal, _work);
        }
    }

    /// @dev Consumes one occupied cell and its record at the same ascending presence ordinal.
    function _consumePresentCell(
        bytes calldata _witness,
        uint256 _cellOffset,
        uint8 _cellIndex,
        Traversal memory _traversal,
        Work memory _work
    )
        private
        pure
    {
        SlotChainTypes.RegistryCellV1 memory cell = _decodeCell(_witness, _cellOffset);
        _requireCell(cell, _cellIndex, _traversal, _work);
        _work.registryLeaves[_cellIndex] =
            LibSlotChainEncoding.hashRegistryLeaf(_cellIndex, true, cell);

        uint256 recordOffset =
            LibScheduleSealWitnessV1.trancheRecordOffset(_traversal.parsed, _work.presentCount);
        (bytes32 trancheLeafHash, bool eligible) =
            _consumeTranche(_witness, recordOffset, cell, _traversal, _cellIndex);
        if (eligible) _insertCandidate(_work, Candidate(cell, trancheLeafHash));

        uint8 presentOrdinal = _work.presentCount;
        _work.seenBuilders[presentOrdinal] = cell.builder;
        _work.seenRegistrationIndices[presentOrdinal] = cell.registrationIndex;
        unchecked {
            ++_work.presentCount;
        }
    }

    /// @dev Decodes the fixed 100-byte occupied-cell payload after its presence byte.
    function _decodeCell(
        bytes calldata _witness,
        uint256 _offset
    )
        private
        pure
        returns (SlotChainTypes.RegistryCellV1 memory cell_)
    {
        cell_.builder = _readAddress(_witness, _offset + 1);
        cell_.bond = _readU192(_witness, _offset + 21);
        cell_.registrationIndex = _readU64(_witness, _offset + 45);
        cell_.effectiveL2Slot = _readU64(_witness, _offset + 53);
        cell_.trancheRoot = _readBytes32(_witness, _offset + 61);
        cell_.tombstonedAtL2Slot = _readU64(_witness, _offset + 93);
    }

    /// @dev Enforces occupied-cell bounds and detects identities duplicated anywhere in the
    ///      authenticated active array, including cells that later fail window eligibility.
    function _requireCell(
        SlotChainTypes.RegistryCellV1 memory _cell,
        uint8 _cellIndex,
        Traversal memory _traversal,
        Work memory _work
    )
        private
        pure
    {
        if (
            _cell.builder == address(0) || _cell.trancheRoot == bytes32(0)
                || _cell.bond < _traversal.snapshot.leasePerWindowAtomic
                || _cell.registrationIndex >= _traversal.nextRegistrationIndex
        ) {
            revert InvalidBuilderRegistryCell(_cellIndex);
        }
        for (uint256 i; i < _work.presentCount; ++i) {
            if (_work.seenBuilders[i] == _cell.builder) revert DuplicateBuilder(_cellIndex);
            if (_work.seenRegistrationIndices[i] == _cell.registrationIndex) {
                revert DuplicateRegistrationIndex(_cellIndex);
            }
        }
    }

    /// @dev Authenticates and validates one present cell's exact derived-index tranche record.
    function _consumeTranche(
        bytes calldata _witness,
        uint256 _offset,
        SlotChainTypes.RegistryCellV1 memory _cell,
        Traversal memory _traversal,
        uint8 _cellIndex
    )
        private
        pure
        returns (bytes32 leafHash_, bool eligible_)
    {
        SlotChainTypes.TrancheLeafV1 memory leaf;
        leaf.index = uint16(uint256(_traversal.snapshot.window) & TRANCHE_INDEX_MASK);
        leaf.window = _readU64(_witness, _offset);
        leaf.state = _readU8(_witness, _offset + 8);
        leaf.amount = _readU192(_witness, _offset + 9);
        leaf.liableUntil = _readU64(_witness, _offset + 33);
        _requireCanonicalTranche(leaf, _traversal.snapshot, _cellIndex);

        leafHash_ = LibSlotChainEncoding.hashTrancheLeaf(leaf);
        bytes32[9] memory siblings;
        for (uint256 height; height < LibSlotChainConstants.TRANCHE_TREE_DEPTH; ++height) {
            siblings[height] = _readBytes32(_witness, _offset + 41 + height * 32);
        }
        if (
            LibSlotChainFixedTrees.computeTrancheRoot(leaf.index, leafHash_, siblings)
                != _cell.trancheRoot
        ) {
            revert BuilderTrancheRootMismatch(_cellIndex);
        }

        eligible_ = leaf.window == _traversal.snapshot.window
            && leaf.state == uint8(SlotChainTypes.TrancheState.RESERVED)
            && _cell.effectiveL2Slot <= _traversal.sourceL2Slot
            && _cell.tombstonedAtL2Slot > _traversal.sourceL2Slot;
    }

    /// @dev Enforces the only canonical encoding for each tranche state and its exact deadline.
    function _requireCanonicalTranche(
        SlotChainTypes.TrancheLeafV1 memory _leaf,
        SnapshotContext memory _context,
        uint8 _cellIndex
    )
        private
        pure
    {
        uint8 state = _leaf.state;
        if (state == uint8(SlotChainTypes.TrancheState.EMPTY)) {
            if (_leaf.window != type(uint64).max || _leaf.amount != 0 || _leaf.liableUntil != 0) {
                revert InvalidBuilderTranche(_cellIndex);
            }
            return;
        }
        if (
            state > uint8(SlotChainTypes.TrancheState.SLASHED)
                || _leaf.window < _context.firstManagedWindow
                || _leaf.window > _context.lastManagedWindow
                || (uint256(_leaf.window) & TRANCHE_INDEX_MASK)
                    != (uint256(_context.window) & TRANCHE_INDEX_MASK)
        ) {
            revert InvalidBuilderTranche(_cellIndex);
        }

        if (state == uint8(SlotChainTypes.TrancheState.FREE)) {
            if (_leaf.amount != 0 || _leaf.liableUntil != 0) {
                revert InvalidBuilderTranche(_cellIndex);
            }
            return;
        }

        uint256 deadline = uint256(_context.genesisTimestamp) + WINDOW_SECONDS
            * (uint256(_leaf.window) + 1) + _context.evidenceDelaySeconds
            + _context.reorgMarginSeconds;
        if (deadline > type(uint64).max || _leaf.liableUntil != uint64(deadline)) {
            revert InvalidBuilderTranche(_cellIndex);
        }
        if (
            state == uint8(SlotChainTypes.TrancheState.RESERVED)
                || state == uint8(SlotChainTypes.TrancheState.LIABLE)
        ) {
            if (_leaf.amount != _context.leasePerWindowAtomic) {
                revert InvalidBuilderTranche(_cellIndex);
            }
        } else if (_leaf.amount != 0) {
            revert InvalidBuilderTranche(_cellIndex);
        }
    }

    /// @dev Inserts one eligible candidate by descending bond then ascending registration index.
    function _insertCandidate(Work memory _work, Candidate memory _candidate) private pure {
        uint256 position = _work.eligibleCount;
        while (position != 0 && _precedes(_candidate, _work.ranked[position - 1])) {
            _work.ranked[position] = _work.ranked[position - 1];
            unchecked {
                --position;
            }
        }
        _work.ranked[position] = _candidate;
        unchecked {
            ++_work.eligibleCount;
        }
    }

    /// @dev Returns whether `_left` ranks strictly before `_right`.
    function _precedes(
        Candidate memory _left,
        Candidate memory _right
    )
        private
        pure
        returns (bool precedes_)
    {
        return _left.cell.bond > _right.cell.bond
            || (_left.cell.bond == _right.cell.bond
                && _left.cell.registrationIndex < _right.cell.registrationIndex);
    }

    /// @dev Rejects impossible or unpinned evaluator context before consuming proof bytes.
    function _requireContext(
        SnapshotContext memory _context,
        LibScheduleForkVerifierCallV1.Carrier memory _carrier
    )
        private
        pure
    {
        if (
            _carrier.stateRoot == bytes32(0) || _carrier.payloadTimestamp == 0
                || _context.builderRegistry == address(0)
                || _context.builderRegistryRuntimeHash == bytes32(0)
                || _context.firstManagedWindow > _context.window
                || _context.window > _context.lastManagedWindow
                || _context.leasePerWindowAtomic == 0
        ) {
            revert InvalidScheduleSnapshotContext();
        }
    }

    /// @dev Reads one fixed-width big-endian byte from already parser-bounded calldata.
    function _readU8(
        bytes calldata _input,
        uint256 _offset
    )
        private
        pure
        returns (uint8 value_)
    {
        if (_offset >= _input.length) revert TruncatedScheduleSnapshot();
        return uint8(_input[_offset]);
    }

    /// @dev Reads one fixed-width big-endian uint64 from already parser-bounded calldata.
    function _readU64(
        bytes calldata _input,
        uint256 _offset
    )
        private
        pure
        returns (uint64 value_)
    {
        if (_offset > _input.length || 8 > _input.length - _offset) {
            revert TruncatedScheduleSnapshot();
        }
        assembly ("memory-safe") {
            value_ := shr(192, calldataload(add(_input.offset, _offset)))
        }
    }

    /// @dev Reads one fixed-width big-endian uint192 from already parser-bounded calldata.
    function _readU192(
        bytes calldata _input,
        uint256 _offset
    )
        private
        pure
        returns (uint192 value_)
    {
        if (_offset > _input.length || 24 > _input.length - _offset) {
            revert TruncatedScheduleSnapshot();
        }
        assembly ("memory-safe") {
            value_ := shr(64, calldataload(add(_input.offset, _offset)))
        }
    }

    /// @dev Reads one fixed-width address from already parser-bounded calldata.
    function _readAddress(
        bytes calldata _input,
        uint256 _offset
    )
        private
        pure
        returns (address value_)
    {
        if (_offset > _input.length || 20 > _input.length - _offset) {
            revert TruncatedScheduleSnapshot();
        }
        assembly ("memory-safe") {
            value_ := shr(96, calldataload(add(_input.offset, _offset)))
        }
    }

    /// @dev Reads one exact bytes32 from already parser-bounded calldata.
    function _readBytes32(
        bytes calldata _input,
        uint256 _offset
    )
        private
        pure
        returns (bytes32 value_)
    {
        if (_offset > _input.length || 32 > _input.length - _offset) {
            revert TruncatedScheduleSnapshot();
        }
        assembly ("memory-safe") {
            value_ := calldataload(add(_input.offset, _offset))
        }
    }

    error ActiveBuilderCountMismatch(uint8 authenticated, uint8 supplied);
    error BuilderRegistryRootMismatch();
    error BuilderTrancheRootMismatch(uint8 cellIndex);
    error DuplicateBuilder(uint8 cellIndex);
    error DuplicateRegistrationIndex(uint8 cellIndex);
    error InvalidBuilderRegistryCell(uint8 cellIndex);
    error InvalidBuilderRegistryHeader();
    error InvalidBuilderTranche(uint8 cellIndex);
    error InvalidScheduleSnapshotContext();
    error TruncatedScheduleSnapshot();
}
