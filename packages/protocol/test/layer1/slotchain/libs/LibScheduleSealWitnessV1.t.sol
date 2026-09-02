// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    LibScheduleSealWitnessV1
} from "../../../../contracts/layer1/slotchain/libs/LibScheduleSealWitnessV1.sol";
import { LibMptProof } from "../../../../contracts/shared/slotchain/libs/LibMptProof.sol";
import { Test } from "forge-std/src/Test.sol";

contract ScheduleSealWitnessHarness {
    struct ParsedView {
        uint256 forkWitnessOffset;
        uint256 forkWitnessLength;
        uint256 carrierHeaderOffset;
        uint256 carrierHeaderLength;
        uint256 accountNodesOffset;
        uint256 accountEndOffset;
        uint8 accountNodeCount;
        uint256 headerNodesOffset;
        uint256 headerEndOffset;
        uint8 headerNodeCount;
        uint256 rootNodesOffset;
        uint256 rootEndOffset;
        uint8 rootNodeCount;
        uint256 registryCellsOffset;
        uint256 trancheRecordsOffset;
        uint8 presentCount;
    }

    function parse(bytes calldata _witness) external pure returns (ParsedView memory parsed_) {
        LibScheduleSealWitnessV1.Witness memory witness =
            LibScheduleSealWitnessV1.parseFraming(_witness);
        parsed_ = ParsedView({
            forkWitnessOffset: witness.forkWitnessOffset,
            forkWitnessLength: witness.forkWitnessLength,
            carrierHeaderOffset: witness.carrierHeaderOffset,
            carrierHeaderLength: witness.carrierHeaderLength,
            accountNodesOffset: witness.accountPath.nodesOffset,
            accountEndOffset: witness.accountPath.endOffset,
            accountNodeCount: witness.accountPath.nodeCount,
            headerNodesOffset: witness.headerSlotPath.nodesOffset,
            headerEndOffset: witness.headerSlotPath.endOffset,
            headerNodeCount: witness.headerSlotPath.nodeCount,
            rootNodesOffset: witness.rootSlotPath.nodesOffset,
            rootEndOffset: witness.rootSlotPath.endOffset,
            rootNodeCount: witness.rootSlotPath.nodeCount,
            registryCellsOffset: witness.registryCellsOffset,
            trancheRecordsOffset: witness.trancheRecordsOffset,
            presentCount: witness.presentCount
        });
    }

    function registryCellOffset(
        bytes calldata _witness,
        uint256 _cellIndex
    )
        external
        pure
        returns (uint256 offset_)
    {
        return LibScheduleSealWitnessV1.registryCellOffset(
            LibScheduleSealWitnessV1.parseFraming(_witness), _cellIndex
        );
    }

    function trancheRecordOffset(
        bytes calldata _witness,
        uint256 _recordOrdinal
    )
        external
        pure
        returns (uint256 offset_)
    {
        return LibScheduleSealWitnessV1.trancheRecordOffset(
            LibScheduleSealWitnessV1.parseFraming(_witness), _recordOrdinal
        );
    }
}

contract LibScheduleSealWitnessV1Test is Test {
    uint256 private constant _MAX_WITNESS_BYTES = 280_000;
    uint256 private constant _MAX_FORK_WITNESS_BYTES = 131_072;
    uint256 private constant _MAX_CARRIER_HEADER_BYTES = 2048;
    uint256 private constant _REGISTRY_CELL_COUNT = 64;
    uint256 private constant _REGISTRY_CELL_BYTES = 101;
    uint256 private constant _TRANCHE_RECORD_BYTES = 329;

    uint256 private constant _MINIMAL_CELLS_OFFSET = 21;
    uint256 private constant _MINIMAL_RECORDS_OFFSET =
        _MINIMAL_CELLS_OFFSET + _REGISTRY_CELL_COUNT * _REGISTRY_CELL_BYTES;

    ScheduleSealWitnessHarness private _harness;

    function setUp() public {
        _harness = new ScheduleSealWitnessHarness();
    }

    function test_parse_AcceptsMinimumAllAbsentWitnessAndReturnsExactOffsets() external view {
        bytes memory witness = _minimalWitness(0);
        ScheduleSealWitnessHarness.ParsedView memory parsed = _harness.parse(witness);

        assertEq(witness.length, 6485);
        assertEq(parsed.forkWitnessOffset, 5);
        assertEq(parsed.forkWitnessLength, 1);
        assertEq(parsed.carrierHeaderOffset, 8);
        assertEq(parsed.carrierHeaderLength, 1);
        assertEq(parsed.accountNodesOffset, 10);
        assertEq(parsed.accountEndOffset, 13);
        assertEq(parsed.accountNodeCount, 1);
        assertEq(parsed.headerNodesOffset, 14);
        assertEq(parsed.headerEndOffset, 17);
        assertEq(parsed.headerNodeCount, 1);
        assertEq(parsed.rootNodesOffset, 18);
        assertEq(parsed.rootEndOffset, 21);
        assertEq(parsed.rootNodeCount, 1);
        assertEq(parsed.registryCellsOffset, _MINIMAL_CELLS_OFFSET);
        assertEq(parsed.trancheRecordsOffset, _MINIMAL_RECORDS_OFFSET);
        assertEq(parsed.presentCount, 0);
    }

    function test_parse_AcceptsMixedPresentCellsAndAscendingRecordCardinality() external view {
        bytes memory witness = _minimalWitness(0);
        _setCellPresent(witness, 1);
        _setCellPresent(witness, 42);
        _setCellPresent(witness, 63);
        witness = bytes.concat(witness, new bytes(3 * _TRANCHE_RECORD_BYTES));

        ScheduleSealWitnessHarness.ParsedView memory parsed = _harness.parse(witness);
        assertEq(parsed.presentCount, 3);
        assertEq(parsed.trancheRecordsOffset, _MINIMAL_RECORDS_OFFSET);
        assertEq(_harness.registryCellOffset(witness, 0), _MINIMAL_CELLS_OFFSET);
        assertEq(
            _harness.registryCellOffset(witness, 63),
            _MINIMAL_CELLS_OFFSET + 63 * _REGISTRY_CELL_BYTES
        );
        assertEq(_harness.trancheRecordOffset(witness, 0), _MINIMAL_RECORDS_OFFSET);
        assertEq(
            _harness.trancheRecordOffset(witness, 2),
            _MINIMAL_RECORDS_OFFSET + 2 * _TRANCHE_RECORD_BYTES
        );
    }

    function test_parse_RevertWhen_VersionIsZeroOrTwo() external {
        bytes memory witness = _minimalWitness(0);
        witness[0] = 0;
        vm.expectRevert(LibScheduleSealWitnessV1.InvalidScheduleSealWitnessVersion.selector);
        _harness.parse(witness);

        witness[0] = bytes1(uint8(2));
        vm.expectRevert(LibScheduleSealWitnessV1.InvalidScheduleSealWitnessVersion.selector);
        _harness.parse(witness);
    }

    function test_parse_RevertWhen_WitnessIsEmptyOrOversize() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.InvalidScheduleSealWitnessLength.selector, 0
            )
        );
        _harness.parse("");

        bytes memory oversize = new bytes(_MAX_WITNESS_BYTES + 1);
        oversize[0] = bytes1(uint8(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.InvalidScheduleSealWitnessLength.selector,
                _MAX_WITNESS_BYTES + 1
            )
        );
        _harness.parse(oversize);
    }

    function test_parse_RevertWhen_ForkWitnessLengthIsZeroOrOverMaximum() external {
        bytes memory witness = _minimalWitness(0);
        _writeU32(witness, 1, 0);
        vm.expectRevert(
            abi.encodeWithSelector(LibScheduleSealWitnessV1.InvalidForkWitnessLength.selector, 0)
        );
        _harness.parse(witness);

        _writeU32(witness, 1, _MAX_FORK_WITNESS_BYTES + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.InvalidForkWitnessLength.selector,
                _MAX_FORK_WITNESS_BYTES + 1
            )
        );
        _harness.parse(witness);
    }

    function test_parse_RevertWhen_ForkWitnessIsTruncated() external {
        bytes memory witness = new bytes(5);
        witness[0] = bytes1(uint8(1));
        _writeU32(witness, 1, 1);
        vm.expectRevert(LibScheduleSealWitnessV1.TruncatedScheduleSealWitness.selector);
        _harness.parse(witness);
    }

    function test_parse_RevertWhen_CarrierHeaderLengthIsZeroOrOverMaximum() external {
        bytes memory witness = _minimalWitness(0);
        _writeU16(witness, 6, 0);
        vm.expectRevert(
            abi.encodeWithSelector(LibScheduleSealWitnessV1.InvalidCarrierHeaderLength.selector, 0)
        );
        _harness.parse(witness);

        _writeU16(witness, 6, _MAX_CARRIER_HEADER_BYTES + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.InvalidCarrierHeaderLength.selector,
                _MAX_CARRIER_HEADER_BYTES + 1
            )
        );
        _harness.parse(witness);
    }

    function test_parse_RevertWhen_CarrierHeaderIsTruncated() external {
        bytes memory witness = new bytes(8);
        witness[0] = bytes1(uint8(1));
        _writeU32(witness, 1, 1);
        witness[5] = 0xaa;
        _writeU16(witness, 6, 1);
        vm.expectRevert(LibScheduleSealWitnessV1.TruncatedScheduleSealWitness.selector);
        _harness.parse(witness);
    }

    function test_parse_RevertWhen_PathCountIsZeroOrAbove65() external {
        bytes memory witness = _minimalWitness(0);
        witness[9] = 0;
        vm.expectRevert(LibMptProof.InvalidMptPathGeometry.selector);
        _harness.parse(witness);

        witness[9] = bytes1(uint8(66));
        vm.expectRevert(LibMptProof.InvalidMptPathGeometry.selector);
        _harness.parse(witness);
    }

    function test_parse_RevertWhen_NodeLengthIsZeroOrAbove600() external {
        bytes memory witness = _minimalWitness(0);
        _writeU16(witness, 10, 0);
        vm.expectRevert(LibMptProof.InvalidMptNodeGeometry.selector);
        _harness.parse(witness);

        _writeU16(witness, 10, 601);
        vm.expectRevert(LibMptProof.InvalidMptNodeGeometry.selector);
        _harness.parse(witness);
    }

    function test_parse_RevertWhen_NodeBodyIsTruncated() external {
        bytes memory witness = new bytes(12);
        witness[0] = bytes1(uint8(1));
        _writeU32(witness, 1, 1);
        witness[5] = 0xaa;
        _writeU16(witness, 6, 1);
        witness[8] = 0xbb;
        witness[9] = bytes1(uint8(1));
        _writeU16(witness, 10, 1);
        vm.expectRevert(LibMptProof.InvalidMptNodeGeometry.selector);
        _harness.parse(witness);
    }

    function test_parse_RevertWhen_SecondOrThirdPathIsMalformed() external {
        bytes memory witness = _minimalWitness(0);
        witness[13] = 0;
        vm.expectRevert(LibMptProof.InvalidMptPathGeometry.selector);
        _harness.parse(witness);

        witness[13] = bytes1(uint8(1));
        witness[17] = 0;
        vm.expectRevert(LibMptProof.InvalidMptPathGeometry.selector);
        _harness.parse(witness);
    }

    function test_parse_AcceptsExactMaximumComponentGeometry() external view {
        bytes memory witness = _maximumGeometryWitness();
        ScheduleSealWitnessHarness.ParsedView memory parsed = _harness.parse(witness);

        assertEq(witness.length, 278_040);
        assertLt(witness.length, _MAX_WITNESS_BYTES + 1);
        assertEq(parsed.forkWitnessLength, _MAX_FORK_WITNESS_BYTES);
        assertEq(parsed.carrierHeaderLength, _MAX_CARRIER_HEADER_BYTES);
        assertEq(parsed.accountNodeCount, 65);
        assertEq(parsed.headerNodeCount, 65);
        assertEq(parsed.rootNodeCount, 65);
        assertEq(parsed.rootEndOffset - (parsed.accountNodesOffset - 1), 117_393);
        assertEq(parsed.presentCount, 64);
        assertEq(parsed.trancheRecordsOffset + 64 * _TRANCHE_RECORD_BYTES, witness.length);
    }

    function test_parse_RevertWhen_PresenceByteIsTwoAtFirstOrLastCell() external {
        bytes memory witness = _minimalWitness(0);
        witness[_cellOffset(0)] = bytes1(uint8(2));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.InvalidRegistryCellPresence.selector, 0, 2
            )
        );
        _harness.parse(witness);

        witness[_cellOffset(0)] = 0;
        witness[_cellOffset(63)] = bytes1(uint8(2));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.InvalidRegistryCellPresence.selector, 63, 2
            )
        );
        _harness.parse(witness);
    }

    function test_parse_RevertForEveryNonzeroByteInFirstAbsentCellPayload() external {
        bytes memory witness = _minimalWitness(0);
        for (uint256 payloadIndex; payloadIndex < 100; ++payloadIndex) {
            witness[_cellOffset(0) + 1 + payloadIndex] = 0x01;
            vm.expectRevert(
                abi.encodeWithSelector(
                    LibScheduleSealWitnessV1.NonCanonicalAbsentRegistryCell.selector, 0
                )
            );
            _harness.parse(witness);
            witness[_cellOffset(0) + 1 + payloadIndex] = 0;
        }
    }

    function test_parse_RevertForEveryNonzeroByteInFinalAbsentCellPayload() external {
        bytes memory witness = _minimalWitness(0);
        for (uint256 payloadIndex; payloadIndex < 100; ++payloadIndex) {
            witness[_cellOffset(63) + 1 + payloadIndex] = 0x80;
            vm.expectRevert(
                abi.encodeWithSelector(
                    LibScheduleSealWitnessV1.NonCanonicalAbsentRegistryCell.selector, 63
                )
            );
            _harness.parse(witness);
            witness[_cellOffset(63) + 1 + payloadIndex] = 0;
        }
    }

    function test_parse_DoesNotConstrainFollowingCellPresenceAsPriorPayload() external view {
        bytes memory witness = _minimalWitness(0);
        _setCellPresent(witness, 1);
        witness = bytes.concat(witness, new bytes(_TRANCHE_RECORD_BYTES));

        ScheduleSealWitnessHarness.ParsedView memory parsed = _harness.parse(witness);
        assertEq(parsed.presentCount, 1);
    }

    function test_parse_RevertWhen_RecordIsMissingOrExtraForZeroOneAnd64PresentCells() external {
        bytes memory noPresent = _minimalWitness(0);
        _expectCardinality(0, 1, bytes.concat(noPresent, hex"00"));

        bytes memory onePresent = _minimalWitness(1);
        _expectCardinality(1, _TRANCHE_RECORD_BYTES - 1, _prefix(onePresent, onePresent.length - 1));
        _expectCardinality(1, _TRANCHE_RECORD_BYTES + 1, bytes.concat(onePresent, hex"00"));

        bytes memory allPresent = _minimalWitness(64);
        _expectCardinality(
            64, 64 * _TRANCHE_RECORD_BYTES - 1, _prefix(allPresent, allPresent.length - 1)
        );
        _expectCardinality(64, 64 * _TRANCHE_RECORD_BYTES + 1, bytes.concat(allPresent, hex"00"));
    }

    function test_registryCellOffset_RevertWhen_IndexIs64() external {
        bytes memory witness = _minimalWitness(0);
        vm.expectRevert(
            abi.encodeWithSelector(LibScheduleSealWitnessV1.InvalidRegistryCellIndex.selector, 64)
        );
        _harness.registryCellOffset(witness, 64);
    }

    function test_trancheRecordOffset_RevertWhen_OrdinalEqualsPresentCount() external {
        bytes memory witness = _minimalWitness(1);
        vm.expectRevert(
            abi.encodeWithSelector(LibScheduleSealWitnessV1.InvalidTrancheRecordOrdinal.selector, 1)
        );
        _harness.trancheRecordOffset(witness, 1);

        bytes memory noPresent = _minimalWitness(0);
        vm.expectRevert(
            abi.encodeWithSelector(LibScheduleSealWitnessV1.InvalidTrancheRecordOrdinal.selector, 0)
        );
        _harness.trancheRecordOffset(noPresent, 0);
    }

    function testFuzz_parse_RevertWhen_AbsentPayloadContainsNonzeroByte(
        uint8 _cell,
        uint8 _payloadByte,
        uint8 _value
    )
        external
    {
        uint256 cell = bound(_cell, 0, 63);
        uint256 payloadByte = bound(_payloadByte, 0, 99);
        uint8 value = uint8(bound(_value, 1, 255));
        bytes memory witness = _minimalWitness(0);
        witness[_cellOffset(cell) + 1 + payloadByte] = bytes1(value);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.NonCanonicalAbsentRegistryCell.selector, cell
            )
        );
        _harness.parse(witness);
    }

    function testFuzz_parse_RevertWhen_PresenceByteIsNotBoolean(
        uint8 _cell,
        uint8 _presence
    )
        external
    {
        uint256 cell = bound(_cell, 0, 63);
        uint8 presence = uint8(bound(_presence, 2, 255));
        bytes memory witness = _minimalWitness(0);
        witness[_cellOffset(cell)] = bytes1(presence);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.InvalidRegistryCellPresence.selector, cell, presence
            )
        );
        _harness.parse(witness);
    }

    function testFuzz_parse_RevertWhen_CanonicalWitnessHasTrailingBytes(uint8 _extraBytes)
        external
    {
        uint256 extraBytes = bound(_extraBytes, 1, 255);
        bytes memory witness = bytes.concat(_minimalWitness(0), new bytes(extraBytes));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.InvalidTrancheRecordCardinality.selector, 0, extraBytes
            )
        );
        _harness.parse(witness);
    }

    function _expectCardinality(
        uint8 _presentCount,
        uint256 _trailingBytes,
        bytes memory _malformed
    )
        private
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.InvalidTrancheRecordCardinality.selector,
                _presentCount,
                _trailingBytes
            )
        );
        _harness.parse(_malformed);
    }

    function _minimalWitness(uint256 _presentCount) private pure returns (bytes memory witness_) {
        assert(_presentCount <= _REGISTRY_CELL_COUNT);
        witness_ = new bytes(_MINIMAL_RECORDS_OFFSET + _presentCount * _TRANCHE_RECORD_BYTES);
        witness_[0] = bytes1(uint8(1));
        _writeU32(witness_, 1, 1);
        witness_[5] = 0xaa;
        _writeU16(witness_, 6, 1);
        witness_[8] = 0xbb;

        uint256 cursor = 9;
        for (uint256 path; path < 3; ++path) {
            witness_[cursor] = bytes1(uint8(1));
            _writeU16(witness_, cursor + 1, 1);
            witness_[cursor + 3] = bytes1(uint8(0xc0 + path));
            cursor += 4;
        }
        assert(cursor == _MINIMAL_CELLS_OFFSET);

        for (uint256 cell; cell < _presentCount; ++cell) {
            _setCellPresent(witness_, cell);
        }
    }

    function _maximumGeometryWitness() private pure returns (bytes memory witness_) {
        uint256 length = 1 + 4 + _MAX_FORK_WITNESS_BYTES + 2 + _MAX_CARRIER_HEADER_BYTES + 3
            * (1 + 65 * (2 + 600)) + _REGISTRY_CELL_COUNT * _REGISTRY_CELL_BYTES
            + _REGISTRY_CELL_COUNT * _TRANCHE_RECORD_BYTES;
        witness_ = new bytes(length);
        witness_[0] = bytes1(uint8(1));
        _writeU32(witness_, 1, _MAX_FORK_WITNESS_BYTES);
        uint256 cursor = 5 + _MAX_FORK_WITNESS_BYTES;
        _writeU16(witness_, cursor, _MAX_CARRIER_HEADER_BYTES);
        cursor += 2 + _MAX_CARRIER_HEADER_BYTES;

        for (uint256 path; path < 3; ++path) {
            witness_[cursor] = bytes1(uint8(65));
            ++cursor;
            for (uint256 node; node < 65; ++node) {
                _writeU16(witness_, cursor, 600);
                cursor += 602;
            }
        }

        for (uint256 cell; cell < _REGISTRY_CELL_COUNT; ++cell) {
            witness_[cursor + cell * _REGISTRY_CELL_BYTES] = bytes1(uint8(1));
        }
        cursor += _REGISTRY_CELL_COUNT * _REGISTRY_CELL_BYTES;
        assert(cursor + _REGISTRY_CELL_COUNT * _TRANCHE_RECORD_BYTES == length);
    }

    function _setCellPresent(bytes memory _witness, uint256 _cell) private pure {
        _witness[_cellOffset(_cell)] = bytes1(uint8(1));
    }

    function _cellOffset(uint256 _cell) private pure returns (uint256 offset_) {
        return _MINIMAL_CELLS_OFFSET + _cell * _REGISTRY_CELL_BYTES;
    }

    function _prefix(
        bytes memory _input,
        uint256 _length
    )
        private
        pure
        returns (bytes memory output_)
    {
        output_ = new bytes(_length);
        for (uint256 i; i < _length; ++i) {
            output_[i] = _input[i];
        }
    }

    function _writeU16(bytes memory _output, uint256 _offset, uint256 _value) private pure {
        _output[_offset] = bytes1(uint8(_value >> 8));
        _output[_offset + 1] = bytes1(uint8(_value));
    }

    function _writeU32(bytes memory _output, uint256 _offset, uint256 _value) private pure {
        _output[_offset] = bytes1(uint8(_value >> 24));
        _output[_offset + 1] = bytes1(uint8(_value >> 16));
        _output[_offset + 2] = bytes1(uint8(_value >> 8));
        _output[_offset + 3] = bytes1(uint8(_value));
    }
}
