// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibMptProof } from "../../../shared/slotchain/libs/LibMptProof.sol";

/// @title Canonical Schedule seal witness framing
/// @custom:security-contact security@taiko.xyz
library LibScheduleSealWitnessV1 {
    uint256 internal constant MAX_WITNESS_BYTES = 280_000;
    uint256 internal constant MAX_FORK_WITNESS_BYTES = 131_072;
    uint256 internal constant MAX_CARRIER_HEADER_BYTES = 2048;
    uint256 internal constant MAX_THREE_MPT_PATH_BYTES = 117_393;
    uint256 internal constant REGISTRY_CELL_COUNT = 64;
    uint256 internal constant REGISTRY_CELL_BYTES = 101;
    uint256 internal constant TRANCHE_RECORD_BYTES = 329;

    uint8 internal constant WITNESS_VERSION = 1;

    /// @dev Zero-copy framing of one complete `ScheduleSealWitnessV1`. Every offset is relative to
    ///      the supplied calldata byte array. Present-cell records occur in ascending cell order.
    struct Witness {
        uint256 forkWitnessOffset;
        uint256 forkWitnessLength;
        uint256 carrierHeaderOffset;
        uint256 carrierHeaderLength;
        LibMptProof.Path accountPath;
        LibMptProof.Path headerSlotPath;
        LibMptProof.Path rootSlotPath;
        uint256 registryCellsOffset;
        uint256 trancheRecordsOffset;
        uint8 presentCount;
    }

    /// @dev Parses and bounds the complete packed witness without copying dynamic components. This
    ///      validates the version, component sizes, MPT framing, presence bits, canonical absent
    ///      cells and the record cardinality implied by the 64 cells. Returned views remain bound
    ///      to this exact `_witness` slice. MPT membership semantics and present-cell/tranche values
    ///      are deliberately verified by the snapshot evaluator, which is the acceptance boundary.
    /// @param _witness The exact packed version-one Schedule seal witness.
    /// @return parsed_ The bounded zero-copy component views.
    function parseFraming(bytes calldata _witness) internal pure returns (Witness memory parsed_) {
        uint256 witnessLength = _witness.length;
        if (witnessLength == 0 || witnessLength > MAX_WITNESS_BYTES) {
            revert InvalidScheduleSealWitnessLength(witnessLength);
        }

        uint256 cursor;
        if (_readU8(_witness, cursor) != WITNESS_VERSION) {
            revert InvalidScheduleSealWitnessVersion();
        }
        ++cursor;

        uint256 forkWitnessLength = _readU32(_witness, cursor);
        cursor += 4;
        if (forkWitnessLength == 0 || forkWitnessLength > MAX_FORK_WITNESS_BYTES) {
            revert InvalidForkWitnessLength(forkWitnessLength);
        }
        _requireAvailable(cursor, forkWitnessLength, witnessLength);
        parsed_.forkWitnessOffset = cursor;
        parsed_.forkWitnessLength = forkWitnessLength;
        cursor += forkWitnessLength;

        uint256 carrierHeaderLength = _readU16(_witness, cursor);
        cursor += 2;
        if (carrierHeaderLength == 0 || carrierHeaderLength > MAX_CARRIER_HEADER_BYTES) {
            revert InvalidCarrierHeaderLength(carrierHeaderLength);
        }
        _requireAvailable(cursor, carrierHeaderLength, witnessLength);
        parsed_.carrierHeaderOffset = cursor;
        parsed_.carrierHeaderLength = carrierHeaderLength;
        cursor += carrierHeaderLength;

        uint256 pathsOffset = cursor;
        (parsed_.accountPath, cursor) = _parsePath(_witness, cursor, witnessLength);
        (parsed_.headerSlotPath, cursor) = _parsePath(_witness, cursor, witnessLength);
        (parsed_.rootSlotPath, cursor) = _parsePath(_witness, cursor, witnessLength);
        if (cursor - pathsOffset > MAX_THREE_MPT_PATH_BYTES) {
            revert ScheduleMptPathsTooLarge(cursor - pathsOffset);
        }

        uint256 cellBytes = REGISTRY_CELL_COUNT * REGISTRY_CELL_BYTES;
        _requireAvailable(cursor, cellBytes, witnessLength);
        parsed_.registryCellsOffset = cursor;
        for (uint256 i; i < REGISTRY_CELL_COUNT; ++i) {
            uint256 offset = cursor + i * REGISTRY_CELL_BYTES;
            uint8 present = uint8(_witness[offset]);
            if (present == 0) {
                if (!_isZeroAbsentCellPayload(_witness, offset + 1)) {
                    revert NonCanonicalAbsentRegistryCell(i);
                }
            } else if (present == 1) {
                unchecked {
                    ++parsed_.presentCount;
                }
            } else {
                revert InvalidRegistryCellPresence(i, present);
            }
        }
        cursor += cellBytes;
        parsed_.trancheRecordsOffset = cursor;

        uint256 recordBytes = uint256(parsed_.presentCount) * TRANCHE_RECORD_BYTES;
        if (cursor > witnessLength || recordBytes != witnessLength - cursor) {
            revert InvalidTrancheRecordCardinality(parsed_.presentCount, witnessLength - cursor);
        }
    }

    /// @dev Returns the offset of one ordinal registry cell.
    /// @param _parsed The parsed witness framing.
    /// @param _cellIndex The exact cell index in `[0,64)`.
    /// @return offset_ The cell's first-byte offset in the witness.
    function registryCellOffset(
        Witness memory _parsed,
        uint256 _cellIndex
    )
        internal
        pure
        returns (uint256 offset_)
    {
        if (_cellIndex >= REGISTRY_CELL_COUNT) revert InvalidRegistryCellIndex(_cellIndex);
        return _parsed.registryCellsOffset + _cellIndex * REGISTRY_CELL_BYTES;
    }

    /// @dev Returns the offset of one present-cell tranche record by ascending presence ordinal.
    /// @param _parsed The parsed witness framing.
    /// @param _recordOrdinal The ordinal in `[0,presentCount)`.
    /// @return offset_ The record's first-byte offset in the witness.
    function trancheRecordOffset(
        Witness memory _parsed,
        uint256 _recordOrdinal
    )
        internal
        pure
        returns (uint256 offset_)
    {
        if (_recordOrdinal >= _parsed.presentCount) {
            revert InvalidTrancheRecordOrdinal(_recordOrdinal);
        }
        return _parsed.trancheRecordsOffset + _recordOrdinal * TRANCHE_RECORD_BYTES;
    }

    /// @dev Parses one `u8(nodeCount)||repeat(u16(nodeBytes)||node)` MPT path.
    function _parsePath(
        bytes calldata _witness,
        uint256 _offset,
        uint256 _end
    )
        private
        pure
        returns (LibMptProof.Path memory path_, uint256 nextOffset_)
    {
        uint256 nodeCount = _readU8(_witness, _offset);
        return LibMptProof.parsePath(_witness, _offset + 1, _end, nodeCount);
    }

    /// @dev Checks the exact 100 bytes following an absent cell's zero presence byte. Three full
    ///      words and the high four bytes of the final load cover the region without constraining
    ///      the following cell or record.
    function _isZeroAbsentCellPayload(
        bytes calldata _witness,
        uint256 _offset
    )
        private
        pure
        returns (bool zero_)
    {
        assembly ("memory-safe") {
            let absoluteOffset := add(_witness.offset, _offset)
            zero_ := iszero(
                or(
                    or(calldataload(absoluteOffset), calldataload(add(absoluteOffset, 32))),
                    or(
                        calldataload(add(absoluteOffset, 64)),
                        shr(224, calldataload(add(absoluteOffset, 96)))
                    )
                )
            )
        }
    }

    /// @dev Reads one big-endian byte with an explicit enclosing-bound check.
    function _readU8(
        bytes calldata _input,
        uint256 _offset
    )
        private
        pure
        returns (uint256 value_)
    {
        if (_offset >= _input.length) revert TruncatedScheduleSealWitness();
        return uint8(_input[_offset]);
    }

    /// @dev Reads one big-endian u16 with an explicit enclosing-bound check.
    function _readU16(
        bytes calldata _input,
        uint256 _offset
    )
        private
        pure
        returns (uint256 value_)
    {
        _requireAvailable(_offset, 2, _input.length);
        return (uint256(uint8(_input[_offset])) << 8) | uint8(_input[_offset + 1]);
    }

    /// @dev Reads one big-endian u32 with an explicit enclosing-bound check.
    function _readU32(
        bytes calldata _input,
        uint256 _offset
    )
        private
        pure
        returns (uint256 value_)
    {
        _requireAvailable(_offset, 4, _input.length);
        return (uint256(uint8(_input[_offset])) << 24) | (uint256(uint8(_input[_offset + 1])) << 16)
            | (uint256(uint8(_input[_offset + 2])) << 8) | uint8(_input[_offset + 3]);
    }

    /// @dev Requires `[offset,offset+length)` to fit without overflowing its enclosing boundary.
    function _requireAvailable(
        uint256 _offset,
        uint256 _length,
        uint256 _end
    )
        private
        pure
    {
        if (_end > MAX_WITNESS_BYTES || _offset > _end || _length > _end - _offset) {
            revert TruncatedScheduleSealWitness();
        }
    }

    error InvalidCarrierHeaderLength(uint256 actual);
    error InvalidForkWitnessLength(uint256 actual);
    error InvalidRegistryCellIndex(uint256 index);
    error InvalidRegistryCellPresence(uint256 index, uint8 present);
    error InvalidScheduleSealWitnessLength(uint256 actual);
    error InvalidScheduleSealWitnessVersion();
    error InvalidTrancheRecordCardinality(uint8 presentCount, uint256 trailingBytes);
    error InvalidTrancheRecordOrdinal(uint256 ordinal);
    error NonCanonicalAbsentRegistryCell(uint256 index);
    error ScheduleMptPathsTooLarge(uint256 actual);
    error TruncatedScheduleSealWitness();
}
