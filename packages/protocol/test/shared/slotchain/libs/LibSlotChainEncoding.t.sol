// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../../../../contracts/shared/slotchain/SlotChainTypes.sol";
import {
    LibSlotChainEncoding
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainEncoding.sol";
import { SlotChainGoldenVectors } from "../vectors/SlotChainGoldenVectors.sol";
import { Test } from "forge-std/src/Test.sol";

contract LibSlotChainEncodingTest is Test {
    bytes32 private constant HASH_A = bytes32(uint256(0x11));
    bytes32 private constant HASH_B = bytes32(uint256(0x22));
    EncodingHarness private harness;

    function setUp() external {
        harness = new EncodingHarness();
    }

    function test_hashEip712Domain_MatchesGoldenVector() external pure {
        assertEq(
            LibSlotChainEncoding.hashEip712Domain(1, address(0xABCD)),
            SlotChainGoldenVectors.DOMAIN_SEPARATOR
        );
    }

    function test_hashSignedBlock_MatchesGoldenVectors() external pure {
        SlotChainTypes.SlotChainBlock memory signedBlock = _signedBlock();
        assertEq(
            LibSlotChainEncoding.hashSlotChainBlock(signedBlock),
            SlotChainGoldenVectors.BLOCK_STRUCT_HASH
        );
        assertEq(
            LibSlotChainEncoding.hashSlotChainDigest(1, address(0xABCD), signedBlock),
            SlotChainGoldenVectors.EIP712_DIGEST
        );
    }

    function test_hashCanonicalCore_MatchesGoldenVector() external pure {
        SlotChainTypes.CanonicalCoreV2 memory core = SlotChainTypes.CanonicalCoreV2({
            l2BlockNumber: 8000,
            tipHash: 0x7777777777777777777777777777777777777777777777777777777777777777,
            tipSlot: 8000,
            stateRoot: bytes32(uint256(type(uint256).max / 0xFF * 0x66)),
            messageCursor: 2,
            winningDataCommitment: 0x417be737a57e38eb410f2d6e65c77ee19d5c314cdaf432067861c6a36c6a990f,
            nextBaseFee: 100,
            nextExcessBlobGas: 0,
            terminalRoot: 0xc5da197edc2f03c7023cc6afe137ccb77d01fc56514d322b6ba66a149315bcb0,
            terminalCount: 0
        });

        assertEq(
            LibSlotChainEncoding.hashCanonicalCore(core),
            0xf59591f1e2e274e4aace20509a2d855e42b88ecac33a5550fd1af781c83047eb
        );
    }

    function test_hashCandidate_RevertWhen_Empty() external {
        SlotChainTypes.CandidateBlockV2[] memory rows = new SlotChainTypes.CandidateBlockV2[](0);
        vm.expectRevert(LibSlotChainEncoding.InvalidCandidateCount.selector);
        harness.hashCandidate(HASH_A, rows);
    }

    function test_hashCandidate_MatchesGoldenVector() external pure {
        SlotChainTypes.CandidateBlockV2[] memory rows = new SlotChainTypes.CandidateBlockV2[](1);
        rows[0] = SlotChainTypes.CandidateBlockV2({
            slot: 8001,
            blockStructHash: SlotChainGoldenVectors.BLOCK_STRUCT_HASH,
            blockHash: _repeatByte(0x88),
            bodyRoot: SlotChainGoldenVectors.BODY_ROOT,
            dataManifestRoot: SlotChainGoldenVectors.MANIFEST_ROOT,
            messageEnd: 66
        });
        assertEq(
            LibSlotChainEncoding.hashCandidate(SlotChainGoldenVectors.BASE_CANONICAL, rows),
            SlotChainGoldenVectors.CANDIDATE_COMMITMENT
        );
    }

    function test_hashSecondCandidateAndWinningData_MatchGoldenVectors() external pure {
        SlotChainTypes.CandidateBlockV2[] memory rows = new SlotChainTypes.CandidateBlockV2[](2);
        rows[0] = SlotChainTypes.CandidateBlockV2({
            slot: 8001,
            blockStructHash: SlotChainGoldenVectors.BLOCK_STRUCT_HASH,
            blockHash: _repeatByte(0x88),
            bodyRoot: SlotChainGoldenVectors.BODY_ROOT,
            dataManifestRoot: SlotChainGoldenVectors.MANIFEST_ROOT,
            messageEnd: 66
        });
        rows[1] = SlotChainTypes.CandidateBlockV2({
            slot: 8002,
            blockStructHash: _repeatByte(0x43),
            blockHash: _repeatByte(0x44),
            bodyRoot: SlotChainGoldenVectors.BODY_ROOT,
            dataManifestRoot: SlotChainGoldenVectors.MANIFEST_ROOT_BLOCK_1,
            messageEnd: 67
        });
        assertEq(
            LibSlotChainEncoding.hashCandidate(SlotChainGoldenVectors.BASE_CANONICAL, rows),
            SlotChainGoldenVectors.CANDIDATE_COMMITMENT_2
        );
        assertEq(
            LibSlotChainEncoding.hashWinningData(
                SlotChainGoldenVectors.CANDIDATE_COMMITMENT, SlotChainGoldenVectors.SESSION_LIST
            ),
            SlotChainGoldenVectors.WINNING_DATA
        );
    }

    function test_hashCandidate_RevertWhen_SlotsAreNotStrictlyIncreasing() external {
        SlotChainTypes.CandidateBlockV2[] memory rows = _candidateRows(2);
        rows[1].slot = rows[0].slot;
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.NonIncreasingCandidateSlot.selector, 1)
        );
        harness.hashCandidate(HASH_A, rows);
    }

    function test_hashCandidate_AcceptsMaximumCount() external pure {
        SlotChainTypes.CandidateBlockV2[] memory rows = _candidateRows(4096);
        assertNotEq(LibSlotChainEncoding.hashCandidate(HASH_A, rows), bytes32(0));
    }

    function test_hashCandidate_RevertWhen_AboveMaximumCount() external {
        SlotChainTypes.CandidateBlockV2[] memory rows = _candidateRows(4097);
        vm.expectRevert(LibSlotChainEncoding.InvalidCandidateCount.selector);
        harness.hashCandidate(HASH_A, rows);
    }

    function test_hashScheduleList_RevertWhen_WindowsAreNotStrictlyIncreasing() external {
        SlotChainTypes.ScheduleEntryV1[] memory rows = new SlotChainTypes.ScheduleEntryV1[](2);
        rows[0] = SlotChainTypes.ScheduleEntryV1(1, HASH_A, HASH_B);
        rows[1] = SlotChainTypes.ScheduleEntryV1(1, HASH_B, HASH_A);
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.NonIncreasingScheduleWindow.selector, 1)
        );
        harness.hashScheduleList(rows);
    }

    function test_hashScheduleAndSessionLists_MatchGoldenVectors() external pure {
        SlotChainTypes.ScheduleEntryV1[] memory schedules = new SlotChainTypes.ScheduleEntryV1[](1);
        schedules[0] = SlotChainTypes.ScheduleEntryV1({
            window: 20, entryRoot: SlotChainGoldenVectors.ENTRY_ROOT, seed: _repeatByte(0x12)
        });
        assertEq(
            LibSlotChainEncoding.hashScheduleList(schedules), SlotChainGoldenVectors.SCHEDULE_LIST
        );

        SlotChainTypes.SessionRefV1[] memory sessions = new SlotChainTypes.SessionRefV1[](1);
        sessions[0] = SlotChainTypes.SessionRefV1({
            sessionId: SlotChainGoldenVectors.SESSION_ID,
            recordCount: 2,
            root: SlotChainGoldenVectors.MMR_ROOT_2
        });
        assertEq(
            LibSlotChainEncoding.hashSessionList(sessions), SlotChainGoldenVectors.SESSION_LIST
        );
    }

    function test_hashSessionList_RevertWhen_RecordCountIsAboveMaximum() external {
        SlotChainTypes.SessionRefV1[] memory rows = new SlotChainTypes.SessionRefV1[](1);
        rows[0] = SlotChainTypes.SessionRefV1(HASH_A, 2101, HASH_B);
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.InvalidSessionRecordCount.selector, 0)
        );
        harness.hashSessionList(rows);
    }

    function test_hashSessionList_RevertWhen_SessionIdsAreDuplicateOrDescending() external {
        SlotChainTypes.SessionRefV1[] memory rows = new SlotChainTypes.SessionRefV1[](2);
        rows[0] = SlotChainTypes.SessionRefV1(bytes32(uint256(2)), 1, HASH_A);
        rows[1] = SlotChainTypes.SessionRefV1(bytes32(uint256(2)), 1, HASH_B);
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.NonIncreasingSessionId.selector, 1)
        );
        harness.hashSessionList(rows);

        rows[1].sessionId = bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.NonIncreasingSessionId.selector, 1)
        );
        harness.hashSessionList(rows);
    }

    function test_boundedLists_AcceptAtCapAndRejectAboveCap() external {
        SlotChainTypes.ScheduleEntryV1[] memory schedules = new SlotChainTypes.ScheduleEntryV1[](12);
        for (uint256 i; i < schedules.length; ++i) {
            schedules[i] = SlotChainTypes.ScheduleEntryV1(uint64(i), HASH_A, HASH_B);
        }
        assertNotEq(LibSlotChainEncoding.hashScheduleList(schedules), bytes32(0));
        schedules = new SlotChainTypes.ScheduleEntryV1[](13);
        vm.expectRevert(LibSlotChainEncoding.InvalidScheduleCount.selector);
        harness.hashScheduleList(schedules);

        SlotChainTypes.SessionRefV1[] memory sessions = new SlotChainTypes.SessionRefV1[](16);
        for (uint256 i; i < sessions.length; ++i) {
            sessions[i] = SlotChainTypes.SessionRefV1(bytes32(i + 1), 2100, HASH_A);
        }
        assertNotEq(LibSlotChainEncoding.hashSessionList(sessions), bytes32(0));
        sessions = new SlotChainTypes.SessionRefV1[](17);
        vm.expectRevert(LibSlotChainEncoding.InvalidSessionCount.selector);
        harness.hashSessionList(sessions);

        SlotChainTypes.DispositionV1[] memory dispositions = new SlotChainTypes.DispositionV1[](64);
        for (uint256 i; i < dispositions.length; ++i) {
            uint8 disposition = uint8(i % 6);
            bool hasTransaction = disposition == uint8(SlotChainTypes.Disposition.INCLUDED_TX);
            bool hasResult = disposition >= uint8(SlotChainTypes.Disposition.INCLUDED_TX);
            dispositions[i] = SlotChainTypes.DispositionV1(
                uint64(i),
                disposition,
                hasTransaction ? uint32(i) : type(uint32).max,
                hasResult ? keccak256(abi.encode(i)) : bytes32(0)
            );
        }
        assertNotEq(LibSlotChainEncoding.hashDispositions(0, dispositions), bytes32(0));
        dispositions = new SlotChainTypes.DispositionV1[](65);
        vm.expectRevert(LibSlotChainEncoding.InvalidDispositionRange.selector);
        harness.hashDispositions(0, dispositions);
    }

    function test_forcedList_AcceptsAtCapAndRejectsAboveCap() external {
        SlotChainTypes.ForcedDescriptorRowV2[] memory rows =
            new SlotChainTypes.ForcedDescriptorRowV2[](256);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = SlotChainTypes.ForcedDescriptorRowV2({
                index: uint64(i), kind: 0, descriptorBytes: new bytes(220)
            });
        }
        SlotChainTypes.ForcedDescriptorRowV2 memory boundary = SlotChainTypes.ForcedDescriptorRowV2({
            index: 256, kind: 1, descriptorBytes: new bytes(541)
        });
        assertNotEq(
            LibSlotChainEncoding.hashForcedDescriptorList(0, rows, true, boundary), bytes32(0)
        );

        rows = new SlotChainTypes.ForcedDescriptorRowV2[](257);
        vm.expectRevert(LibSlotChainEncoding.InvalidForcedRange.selector);
        harness.hashForcedDescriptorList(0, rows, false, boundary);
    }

    function test_hashForcedDescriptorList_RevertWhen_BoundaryWouldReachUnusedIndex() external {
        SlotChainTypes.ForcedDescriptorRowV2[] memory rows =
            new SlotChainTypes.ForcedDescriptorRowV2[](1);
        rows[0] = SlotChainTypes.ForcedDescriptorRowV2({
            index: type(uint64).max - 1, kind: 0, descriptorBytes: new bytes(220)
        });
        SlotChainTypes.ForcedDescriptorRowV2 memory boundary = SlotChainTypes.ForcedDescriptorRowV2({
            index: type(uint64).max, kind: 1, descriptorBytes: new bytes(541)
        });
        vm.expectRevert(LibSlotChainEncoding.InvalidForcedRange.selector);
        harness.hashForcedDescriptorList(type(uint64).max - 1, rows, true, boundary);
    }

    function test_hashForcedDescriptorList_RevertWhen_RowIsNoncanonical() external {
        SlotChainTypes.ForcedDescriptorRowV2[] memory rows =
            new SlotChainTypes.ForcedDescriptorRowV2[](1);
        SlotChainTypes.ForcedDescriptorRowV2 memory unusedBoundary;

        rows[0] = SlotChainTypes.ForcedDescriptorRowV2({
            index: 8, kind: 0, descriptorBytes: new bytes(220)
        });
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.NonContiguousForcedDescriptor.selector, 0)
        );
        harness.hashForcedDescriptorList(7, rows, false, unusedBoundary);

        rows[0] = SlotChainTypes.ForcedDescriptorRowV2({
            index: 7, kind: 2, descriptorBytes: new bytes(220)
        });
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.InvalidForcedDescriptorKind.selector, 0)
        );
        harness.hashForcedDescriptorList(7, rows, false, unusedBoundary);

        rows[0] = SlotChainTypes.ForcedDescriptorRowV2({
            index: 7, kind: 0, descriptorBytes: new bytes(219)
        });
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.InvalidForcedDescriptorLength.selector, 0)
        );
        harness.hashForcedDescriptorList(7, rows, false, unusedBoundary);

        rows[0] = SlotChainTypes.ForcedDescriptorRowV2({
            index: 7, kind: 1, descriptorBytes: new bytes(540)
        });
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.InvalidForcedDescriptorLength.selector, 0)
        );
        harness.hashForcedDescriptorList(7, rows, false, unusedBoundary);
    }

    function test_hashForcedDescriptorList_MatchesGoldenVector() external pure {
        SlotChainTypes.ForcedDescriptorRowV2[] memory rows =
            new SlotChainTypes.ForcedDescriptorRowV2[](64);
        for (uint256 i; i < rows.length; ++i) {
            uint64 index = uint64(i + 2);
            rows[i] = SlotChainTypes.ForcedDescriptorRowV2({
                index: index,
                kind: 0,
                descriptorBytes: LibSlotChainEncoding.encodeKind0Descriptor(
                    _forcedDescriptor(index)
                )
            });
        }
        SlotChainTypes.ForcedDescriptorRowV2 memory boundary = SlotChainTypes.ForcedDescriptorRowV2({
            index: 66,
            kind: 0,
            descriptorBytes: LibSlotChainEncoding.encodeKind0Descriptor(_forcedDescriptor(66))
        });
        assertEq(
            LibSlotChainEncoding.hashForcedDescriptorList(2, rows, true, boundary),
            SlotChainGoldenVectors.FORCED_DESCRIPTORS
        );
    }

    function test_hashManifestLeaf_RevertWhen_BlockOrdinalDiffers() external {
        SlotChainTypes.ManifestEntryV1 memory entry = SlotChainTypes.ManifestEntryV1({
            blockOrdinal: 1,
            sessionId: HASH_A,
            recordIndex: 0,
            chunkIndex: 0,
            chunkCount: 1,
            chunkLength: 0,
            fullBodyRoot: HASH_A,
            chunkRoot: HASH_B
        });
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.InvalidManifestBlockOrdinal.selector, 0)
        );
        harness.hashManifestLeaf(0, 0, entry);
    }

    function test_manifestBoundaries_AcceptAtCapAndRejectAboveCap() external {
        assertEq(
            LibSlotChainEncoding.hashManifestRoot(0, LibSlotChainEncoding.hashManifestEmptyLeaf()),
            SlotChainGoldenVectors.EMPTY_MANIFEST_ROOT
        );
        assertNotEq(LibSlotChainEncoding.hashManifestRoot(2100, HASH_A), bytes32(0));
        vm.expectRevert(LibSlotChainEncoding.InvalidManifestCount.selector);
        harness.hashManifestRoot(2101, HASH_A);

        SlotChainTypes.ManifestEntryV1 memory entry = SlotChainTypes.ManifestEntryV1({
            blockOrdinal: 4095,
            sessionId: HASH_A,
            recordIndex: 0,
            chunkIndex: 0,
            chunkCount: 1,
            chunkLength: 0,
            fullBodyRoot: HASH_A,
            chunkRoot: HASH_B
        });
        assertNotEq(LibSlotChainEncoding.hashManifestLeaf(4095, 2099, entry), bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.InvalidManifestBlockOrdinal.selector, 2100)
        );
        harness.hashManifestLeaf(4095, 2100, entry);
    }

    function test_hashManifestRoot_RevertWhen_EmptyRootIsNoncanonical() external {
        vm.expectRevert(LibSlotChainEncoding.InvalidManifestEmptyRoot.selector);
        harness.hashManifestRoot(0, HASH_A);
    }

    function test_hashDispositions_RevertWhen_EndWouldOverflow() external {
        SlotChainTypes.DispositionV1[] memory rows = new SlotChainTypes.DispositionV1[](1);
        rows[0] = SlotChainTypes.DispositionV1(type(uint64).max, 0, type(uint32).max, bytes32(0));
        vm.expectRevert(LibSlotChainEncoding.InvalidDispositionRange.selector);
        harness.hashDispositions(type(uint64).max, rows);
    }

    function test_hashDispositions_RevertWhen_RowIsNoncanonical() external {
        SlotChainTypes.DispositionV1[] memory rows = new SlotChainTypes.DispositionV1[](1);
        rows[0] = SlotChainTypes.DispositionV1(8, 0, type(uint32).max, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEncoding.NonContiguousDisposition.selector, 0)
        );
        harness.hashDispositions(7, rows);

        rows[0] = SlotChainTypes.DispositionV1(7, 6, type(uint32).max, bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(LibSlotChainEncoding.InvalidDisposition.selector, 0));
        harness.hashDispositions(7, rows);
    }

    function test_emptyLists_AcceptMaximumStartWithoutNarrowingOrWrap() external pure {
        SlotChainTypes.ForcedDescriptorRowV2[] memory forcedRows =
            new SlotChainTypes.ForcedDescriptorRowV2[](0);
        SlotChainTypes.ForcedDescriptorRowV2 memory unusedBoundary;
        assertNotEq(
            LibSlotChainEncoding.hashForcedDescriptorList(
                type(uint64).max, forcedRows, false, unusedBoundary
            ),
            bytes32(0)
        );
        SlotChainTypes.DispositionV1[] memory dispositions = new SlotChainTypes.DispositionV1[](0);
        assertNotEq(
            LibSlotChainEncoding.hashDispositions(type(uint64).max, dispositions), bytes32(0)
        );
        SlotChainTypes.SessionRefV1[] memory sessions = new SlotChainTypes.SessionRefV1[](0);
        assertEq(
            LibSlotChainEncoding.hashSessionList(sessions),
            SlotChainGoldenVectors.EMPTY_SESSION_LIST
        );
    }

    function test_hashFixedPreimages_MatchGoldenVectors() external pure {
        assertEq(
            LibSlotChainEncoding.hashBaseCanonical(SlotChainGoldenVectors.CANONICAL_CORE, 1000),
            SlotChainGoldenVectors.BASE_CANONICAL
        );
        assertEq(
            LibSlotChainEncoding.hashNormalContext(
                SlotChainGoldenVectors.BASE_CANONICAL,
                12,
                SlotChainGoldenVectors.ADMISSION_ROOT,
                1000,
                _repeatByte(0x99)
            ),
            SlotChainGoldenVectors.NORMAL_CONTEXT
        );
        assertEq(
            LibSlotChainEncoding.hashSessionId(1, address(0xABCD), address(0xCAFE), 2),
            SlotChainGoldenVectors.SESSION_ID
        );

        bytes[] memory transactions = new bytes[](2);
        transactions[0] = hex"0102";
        transactions[1] = hex"030405";
        assertEq(LibSlotChainEncoding.hashBody(transactions), SlotChainGoldenVectors.BODY_ROOT);
        assertEq(
            LibSlotChainEncoding.hashBodyChunk(
                SlotChainGoldenVectors.BODY_ROOT, 0, 0, 2, bytes("alpha")
            ),
            SlotChainGoldenVectors.CHUNK_ROOT_0
        );
        bytes[] memory emptyTransactions = new bytes[](0);
        assertEq(
            LibSlotChainEncoding.hashBody(emptyTransactions), SlotChainGoldenVectors.EMPTY_BODY_ROOT
        );
        assertEq(
            LibSlotChainEncoding.hashMigrationData(
                1,
                16_788,
                _repeatByte(0x77),
                _repeatByte(0x66),
                SlotChainGoldenVectors.EMPTY_TERMINAL_ROOT,
                0
            ),
            SlotChainGoldenVectors.MIGRATION_DATA
        );
        assertEq(
            LibSlotChainEncoding.hashInboxCreditSlot(SlotChainGoldenVectors.BRIDGE_CREDIT_ID),
            SlotChainGoldenVectors.INBOX_CREDIT_SLOT
        );
    }

    function test_hashExecutionOutputs_MatchesGoldenVector() external pure {
        SlotChainTypes.ExecutionOutputsV2 memory outputs = SlotChainTypes.ExecutionOutputsV2({
            stateRoot: _repeatByte(0x66),
            transactionsRoot: _repeatByte(0x13),
            receiptsRoot: _repeatByte(0x14),
            logsBloomHash: _repeatByte(0x15),
            withdrawalsRoot: _repeatByte(0x16),
            terminalRoot: SlotChainGoldenVectors.EMPTY_TERMINAL_ROOT,
            terminalCount: 0
        });
        assertEq(
            LibSlotChainEncoding.hashExecutionOutputs(outputs),
            SlotChainGoldenVectors.EXECUTION_OUTPUTS
        );
    }

    function test_hashDataAndManifestPrimitives_ComposeToGoldenRoots() external pure {
        bytes32 chunk0 = SlotChainGoldenVectors.CHUNK_ROOT_0;
        bytes32 chunk1 = LibSlotChainEncoding.hashBodyChunk(
            SlotChainGoldenVectors.BODY_ROOT, 0, 1, 2, bytes("beta")
        );
        SlotChainTypes.DataRecordV1 memory record0 = _dataRecord0();
        SlotChainTypes.DataRecordV1 memory record1 = _dataRecord1();
        bytes32 leaf0 = LibSlotChainEncoding.hashDataLeaf(record0);
        bytes32 leaf1 = LibSlotChainEncoding.hashDataLeaf(record1);
        bytes32 dataNode = LibSlotChainEncoding.hashDataNode(0, leaf0, leaf1);
        assertEq(
            LibSlotChainEncoding.hashDataBag(2, 1, abi.encodePacked(uint8(1), dataNode)),
            SlotChainGoldenVectors.MMR_ROOT_2
        );

        SlotChainTypes.ManifestEntryV1 memory entry0 = SlotChainTypes.ManifestEntryV1({
            blockOrdinal: 0,
            sessionId: SlotChainGoldenVectors.SESSION_ID,
            recordIndex: 0,
            chunkIndex: 0,
            chunkCount: 2,
            chunkLength: 5,
            fullBodyRoot: SlotChainGoldenVectors.BODY_ROOT,
            chunkRoot: chunk0
        });
        SlotChainTypes.ManifestEntryV1 memory entry1 = SlotChainTypes.ManifestEntryV1({
            blockOrdinal: 0,
            sessionId: SlotChainGoldenVectors.SESSION_ID,
            recordIndex: 1,
            chunkIndex: 1,
            chunkCount: 2,
            chunkLength: 4,
            fullBodyRoot: SlotChainGoldenVectors.BODY_ROOT,
            chunkRoot: chunk1
        });
        bytes32 manifestNode = LibSlotChainEncoding.hashManifestNode(
            0,
            LibSlotChainEncoding.hashManifestLeaf(0, 0, entry0),
            LibSlotChainEncoding.hashManifestLeaf(0, 1, entry1)
        );
        assertEq(
            LibSlotChainEncoding.hashManifestRoot(2, manifestNode),
            SlotChainGoldenVectors.MANIFEST_ROOT
        );
        entry0.blockOrdinal = 1;
        entry1.blockOrdinal = 1;
        manifestNode = LibSlotChainEncoding.hashManifestNode(
            0,
            LibSlotChainEncoding.hashManifestLeaf(1, 0, entry0),
            LibSlotChainEncoding.hashManifestLeaf(1, 1, entry1)
        );
        assertEq(
            LibSlotChainEncoding.hashManifestRoot(2, manifestNode),
            SlotChainGoldenVectors.MANIFEST_ROOT_BLOCK_1
        );
    }

    function test_hashAsymmetricDataAndManifestPrimitives_MatchGoldenVectors() external pure {
        SlotChainTypes.DataRecordV1 memory record = _asymmetricDataRecord();
        bytes32 dataLeaf = LibSlotChainEncoding.hashDataLeaf(record);
        assertEq(dataLeaf, SlotChainGoldenVectors.ASYMMETRIC_DATA_LEAF);
        assertEq(
            LibSlotChainEncoding.hashDataNode(7, dataLeaf, _repeatByte(0xA7)),
            SlotChainGoldenVectors.DATA_NODE_HEIGHT_7
        );

        SlotChainTypes.ManifestEntryV1 memory entry = _asymmetricManifestEntry(record);
        bytes32 manifestLeaf = LibSlotChainEncoding.hashManifestLeaf(3, 11, entry);
        assertEq(manifestLeaf, SlotChainGoldenVectors.ASYMMETRIC_MANIFEST_LEAF);
        assertEq(
            LibSlotChainEncoding.hashManifestNode(5, manifestLeaf, _repeatByte(0xB5)),
            SlotChainGoldenVectors.MANIFEST_NODE_HEIGHT_5
        );
    }

    function test_hashDataBag_MatchesEmptyAndMultiPeakGoldenVectors() external pure {
        assertEq(
            LibSlotChainEncoding.hashDataBag(0, 0, bytes("")), SlotChainGoldenVectors.EMPTY_DATA_BAG
        );

        bytes32 leaf0 = LibSlotChainEncoding.hashDataLeaf(_dataRecord0());
        bytes32 leaf1 = LibSlotChainEncoding.hashDataLeaf(_dataRecord1());
        bytes32 leaf2 = LibSlotChainEncoding.hashDataLeaf(_dataRecord2());
        bytes32 node01 = LibSlotChainEncoding.hashDataNode(0, leaf0, leaf1);
        bytes memory ascendingPeaks = abi.encodePacked(uint8(0), leaf2, uint8(1), node01);
        assertEq(
            LibSlotChainEncoding.hashDataBag(3, 2, ascendingPeaks),
            SlotChainGoldenVectors.MMR_ROOT_3
        );
    }

    function test_hashDataBag_AcceptsCountBoundaries() external pure {
        uint16[7] memory counts = [uint16(0), 1, 3, 2047, 2048, 2099, 2100];
        for (uint256 i; i < counts.length; ++i) {
            uint16 count = counts[i];
            assertNotEq(
                LibSlotChainEncoding.hashDataBag(count, _popcount(count), _syntheticPeaks(count)),
                bytes32(0)
            );
        }
    }

    function test_hashDataBag_RevertWhen_PeaksDoNotMatchRecordCount() external {
        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(2, 1, abi.encodePacked(uint8(0), HASH_A));

        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(3, 1, abi.encodePacked(uint8(1), HASH_A));

        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(0, 1, abi.encodePacked(uint8(0), HASH_A));

        bytes memory height0 = abi.encodePacked(uint8(0), HASH_A);
        bytes memory height1 = abi.encodePacked(uint8(1), HASH_B);
        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(3, 2, bytes.concat(height1, height0));

        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(3, 2, bytes.concat(height0, height0));

        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(3, 1, height0);

        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(
            3, 3, bytes.concat(height0, height1, abi.encodePacked(uint8(2), HASH_A))
        );

        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(1, 1, new bytes(32));

        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(1, 1, new bytes(34));

        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(0, 13, new bytes(13 * 33));

        vm.expectRevert(LibSlotChainEncoding.InvalidDataBag.selector);
        harness.hashDataBag(2101, 0, bytes(""));
    }

    function test_hashSettlementStatement_MatchesGoldenVector() external pure {
        SlotChainTypes.SettlementStatementV2 memory statement = SlotChainTypes.SettlementStatementV2({
            settlementChainId: 1,
            l2ChainId: 16_788,
            protocolVersion: 2,
            executionProfileHash: SlotChainGoldenVectors.EXECUTION_PROFILE_HASH,
            verifyingContract: address(0xABCD),
            releaseProtocolVersion: 2,
            releaseManifestHash: _repeatByte(0xB7),
            tier: 1,
            baseCanonicalHash: SlotChainGoldenVectors.BASE_CANONICAL,
            candidateCommitment: SlotChainGoldenVectors.CANDIDATE_COMMITMENT,
            blockCount: 1,
            firstSlot: 8001,
            tipHash: _repeatByte(0x88),
            tipSlot: 8001,
            endL2BlockNumber: 8001,
            endStateRoot: _repeatByte(0x66),
            endTerminalRoot: SlotChainGoldenVectors.EMPTY_TERMINAL_ROOT,
            endTerminalCount: 0,
            endCursor: 66,
            winningDataCommitment: SlotChainGoldenVectors.WINNING_DATA,
            nextDueAt: 2121,
            nextBaseFee: 101,
            nextExcessBlobGas: 0,
            anchorNumber: 1000,
            anchorHash: _repeatByte(0x99),
            anchorStateRoot: _repeatByte(0xAA),
            anchorTimestamp: 999,
            forceRoot: SlotChainGoldenVectors.FORCED_ROOT,
            forceCutoff: 70,
            forcedDescriptorCommitment: SlotChainGoldenVectors.FORCED_DESCRIPTORS,
            startCursor: 2,
            admissionVersion: 12,
            admissionRoot: SlotChainGoldenVectors.ADMISSION_ROOT,
            episode: 0,
            recoveryRevision: 0,
            recoveryId: bytes32(0),
            scheduleRootsCommitment: SlotChainGoldenVectors.SCHEDULE_LIST,
            scheduleWindowCount: 1,
            sessionRefsCommitment: SlotChainGoldenVectors.SESSION_LIST,
            sessionCount: 1,
            dataRecordCount: 2,
            rewardExecutionGas: 12_345_678,
            rewardPublishedBytes: 9,
            executionOutputsCommitment: SlotChainGoldenVectors.EXECUTION_OUTPUTS,
            proofBeneficiary: address(0xCAFE)
        });
        assertEq(
            LibSlotChainEncoding.hashSettlementStatement(statement),
            SlotChainGoldenVectors.STATEMENT_HASH
        );
    }

    function test_hashRewardAndBridgeContexts_MatchGoldenVectors() external pure {
        SlotChainTypes.RewardReceiptV1 memory receipt = SlotChainTypes.RewardReceiptV1({
            candidateId: SlotChainGoldenVectors.STATEMENT_HASH,
            beneficiary: address(0xCAFE),
            rewardClass: 1,
            rewardExecutionGas: 12_345_678,
            rewardPublishedBytes: 9,
            executionProfileHash: SlotChainGoldenVectors.EXECUTION_PROFILE_HASH,
            committedAtBlock: 1_234_567,
            committedAtTimestamp: 1_800_000_000,
            claimUntil: 1_800_086_400,
            claimed: true
        });
        assertEq(
            LibSlotChainEncoding.hashRewardReceipt(receipt),
            SlotChainGoldenVectors.REWARD_RECEIPT_V1_COMMITMENT
        );

        SlotChainTypes.SourceContextV2 memory source = SlotChainTypes.SourceContextV2({
            protocolVersion: 2,
            kind: 1,
            creditId: SlotChainGoldenVectors.BRIDGE_CREDIT_ID,
            msgHash: _repeatByte(0x21),
            sourceDomainId: SlotChainGoldenVectors.SOURCE_DOMAIN_ID,
            sourceRegistrationEpoch: 7,
            sourceBridge: address(0xFfF25F997872E08385a4Dc63163E60181C213F62),
            sourceBridgeExecutionHash: SlotChainGoldenVectors.BRIDGE_EXECUTION_HASH,
            emittedAtBlock: 12_300,
            queueIndex: 70
        });
        assertEq(
            LibSlotChainEncoding.hashSourceContext(source),
            SlotChainGoldenVectors.SOURCE_CONTEXT_HASH
        );

        SlotChainTypes.DestinationContextV2 memory destination = SlotChainTypes.DestinationContextV2({
            destinationChainId: 16_788,
            destinationDomainId: SlotChainGoldenVectors.DESTINATION_DOMAIN_ID,
            destinationBridge: address(0xB200),
            releaseManifestHash: SlotChainGoldenVectors.RELEASE_MANIFEST_HASH,
            executionProfileHash: SlotChainGoldenVectors.EXECUTION_PROFILE_HASH
        });
        assertEq(
            LibSlotChainEncoding.hashDestinationContext(destination),
            SlotChainGoldenVectors.DESTINATION_CONTEXT_HASH
        );
        assertEq(
            LibSlotChainEncoding.hashBridgeCreditId(
                1,
                SlotChainGoldenVectors.SOURCE_DOMAIN_ID,
                7,
                address(0xFfF25F997872E08385a4Dc63163E60181C213F62),
                SlotChainGoldenVectors.DESTINATION_DOMAIN_ID,
                _repeatByte(0x21),
                5678
            ),
            SlotChainGoldenVectors.BRIDGE_CREDIT_ID
        );
        assertEq(
            LibSlotChainEncoding.hashBridgeEscrowId(SlotChainGoldenVectors.BRIDGE_CREDIT_ID),
            SlotChainGoldenVectors.BRIDGE_ESCROW_ID
        );
    }

    function test_hashRewardReceipt_ExcludesClaimedFlag() external pure {
        SlotChainTypes.RewardReceiptV1 memory receipt = _rewardReceipt();
        bytes32 unclaimed = LibSlotChainEncoding.hashRewardReceipt(receipt);
        receipt.claimed = true;
        assertEq(LibSlotChainEncoding.hashRewardReceipt(receipt), unclaimed);
    }

    function test_hashRewardReceipt_RevertWhen_IdentityClassOrDeadlineIsInvalid() external {
        SlotChainTypes.RewardReceiptV1 memory receipt = _rewardReceipt();
        receipt.candidateId = bytes32(0);
        vm.expectRevert(LibSlotChainEncoding.InvalidRewardReceipt.selector);
        harness.hashRewardReceipt(receipt);

        receipt = _rewardReceipt();
        receipt.beneficiary = address(0);
        vm.expectRevert(LibSlotChainEncoding.InvalidRewardReceipt.selector);
        harness.hashRewardReceipt(receipt);

        receipt = _rewardReceipt();
        receipt.rewardClass = 0;
        vm.expectRevert(LibSlotChainEncoding.InvalidRewardReceipt.selector);
        harness.hashRewardReceipt(receipt);

        receipt = _rewardReceipt();
        receipt.rewardClass = 4;
        vm.expectRevert(LibSlotChainEncoding.InvalidRewardReceipt.selector);
        harness.hashRewardReceipt(receipt);

        receipt = _rewardReceipt();
        receipt.claimUntil = receipt.committedAtTimestamp;
        vm.expectRevert(LibSlotChainEncoding.InvalidRewardReceipt.selector);
        harness.hashRewardReceipt(receipt);
    }

    function test_hashSourceAndDestinationDomains_MatchGoldenVectors() external pure {
        SlotChainTypes.SourceDomainV4 memory source = SlotChainTypes.SourceDomainV4({
            sourceChainId: 1,
            genesisHash: _repeatByte(0x25),
            creditRegistry: address(SlotChainGoldenVectors.DERIVED_SOURCE_REGISTRY_ADDRESS),
            terminalVerifier: address(0x5c37F7073592dd30a6d18144fe6df255cfC414cE),
            bridge: address(0xFfF25F997872E08385a4Dc63163E60181C213F62),
            bridgeExecutionHash: SlotChainGoldenVectors.BRIDGE_EXECUTION_HASH,
            registryNamespace: _repeatByte(0x26)
        });
        assertEq(
            LibSlotChainEncoding.hashSourceDomain(source), SlotChainGoldenVectors.SOURCE_DOMAIN_ID
        );

        SlotChainTypes.DestinationDomainV7 memory destination = SlotChainTypes.DestinationDomainV7({
            destinationChainId: 16_788,
            genesisHash: 0xf441e201b2f657c6674ad74d31a54c7de57d28b3ae53e298ac942be7f93f92c4,
            bridgeInboxAdapter: address(0x579872D0675171ADD2AcBd3E089Bc91cBD2DbA3e),
            activeSettlementRouter: address(0xcDC2324dbF31135b8Dd3135eeE745B8C5c593bB4),
            terminalVerifier: address(0x5c37F7073592dd30a6d18144fe6df255cfC414cE),
            inboxApply: address(0x1b7F5b2BF09107259Eb9c5ae86c68a9c69A2eeCb),
            inboxCreditStore: address(0x148115D0E7d513a334C68BE80e481464066Bf5d3),
            protocolReleaseAuthority: address(0x044864dE356EBC05c4cf59071dd05603d498eB76),
            terminalDomainRegistrar: address(0x75Ee683317C39404741fAF27659460825DeC4fCa),
            terminalAccumulator: address(0xf61e83Ec0ce83Ff1CFbC8dF41071C1c80468344F),
            nativeLiquidityPool: address(0xBc2C28918dF7C4dcbE1Ab3718770cb994c52f84F),
            bridge: address(0x54699030C0a49353b0eb6ec82B93c8166950175D),
            bridgeExecutionHash: SlotChainGoldenVectors.DESTINATION_BRIDGE_EXECUTION_HASH,
            infrastructureHash: SlotChainGoldenVectors.DESTINATION_INFRASTRUCTURE_HASH,
            namespace: 0x18b9a19c9e83dc91e9b5625d6414c59d8107c5e51f04acd7f9a98e5266e31fd7
        });
        assertEq(
            LibSlotChainEncoding.hashDestinationDomain(destination),
            SlotChainGoldenVectors.DESTINATION_DOMAIN_ID
        );
    }

    function test_hashBridgeContexts_RevertWhen_DomainOrVersionIsInvalid() external {
        SlotChainTypes.SourceContextV2 memory context = SlotChainTypes.SourceContextV2({
            protocolVersion: 2,
            kind: 1,
            creditId: HASH_A,
            msgHash: HASH_B,
            sourceDomainId: HASH_A,
            sourceRegistrationEpoch: 1,
            sourceBridge: address(1),
            sourceBridgeExecutionHash: HASH_B,
            emittedAtBlock: 1,
            queueIndex: 1
        });
        context.protocolVersion = 0;
        vm.expectRevert(LibSlotChainEncoding.InvalidSourceContext.selector);
        harness.hashSourceContext(context);
        context.protocolVersion = 2;
        context.kind = 0;
        vm.expectRevert(LibSlotChainEncoding.InvalidSourceContext.selector);
        harness.hashSourceContext(context);

        SlotChainTypes.SourceDomainV4 memory source = SlotChainTypes.SourceDomainV4({
            sourceChainId: 1,
            genesisHash: bytes32(0),
            creditRegistry: address(1),
            terminalVerifier: address(2),
            bridge: address(3),
            bridgeExecutionHash: HASH_A,
            registryNamespace: HASH_B
        });
        vm.expectRevert(LibSlotChainEncoding.InvalidSourceDomain.selector);
        harness.hashSourceDomain(source);

        SlotChainTypes.DestinationDomainV7 memory destination;
        destination.destinationChainId = 1;
        destination.genesisHash = HASH_A;
        destination.bridgeInboxAdapter = address(1);
        destination.activeSettlementRouter = address(2);
        destination.terminalVerifier = address(3);
        destination.inboxApply = address(4);
        destination.inboxCreditStore = address(5);
        destination.protocolReleaseAuthority = address(6);
        destination.terminalDomainRegistrar = address(7);
        destination.terminalAccumulator = address(8);
        destination.nativeLiquidityPool = address(9);
        destination.bridge = address(0);
        destination.bridgeExecutionHash = HASH_A;
        destination.infrastructureHash = HASH_B;
        destination.namespace = HASH_A;
        vm.expectRevert(LibSlotChainEncoding.InvalidDestinationDomain.selector);
        harness.hashDestinationDomain(destination);
    }

    function test_hashBridgeAndTerminalLeaves_MatchGoldenVectors() external pure {
        SlotChainTypes.Kind1ForcedDescriptorV11 memory descriptor = _bridgeDescriptor();
        assertEq(
            LibSlotChainEncoding.encodeKind1Descriptor(descriptor),
            SlotChainGoldenVectors.V11_BRIDGE_DESCRIPTOR
        );
        assertEq(
            LibSlotChainEncoding.hashForcedBridgeLeaf(70, descriptor),
            SlotChainGoldenVectors.BRIDGE_LEAF
        );
        assertEq(
            LibSlotChainEncoding.hashBridgeCreditResult(70, descriptor),
            SlotChainGoldenVectors.BRIDGE_RESULT
        );

        SlotChainTypes.LiquiditySettlementV1 memory settlement = SlotChainTypes.LiquiditySettlementV1({
            ticketId: _repeatByte(0x45),
            l1Recipient: address(0x7777),
            settlementAmount: 10 ** 18 + 1234
        });
        bytes32 settlementHash = LibSlotChainEncoding.hashLiquiditySettlement(settlement);
        assertEq(settlementHash, SlotChainGoldenVectors.LIQUIDITY_SETTLEMENT_HASH);
        assertEq(
            LibSlotChainEncoding.hashTerminalLeaf(
                0,
                SlotChainGoldenVectors.DESTINATION_DOMAIN_ID,
                address(0xB200),
                SlotChainGoldenVectors.BRIDGE_CREDIT_ID,
                1,
                settlementHash
            ),
            SlotChainGoldenVectors.TERMINAL_DONE_LEAF
        );
        assertEq(
            LibSlotChainEncoding.hashTerminalLeaf(
                1,
                SlotChainGoldenVectors.DESTINATION_DOMAIN_ID,
                address(0xB200),
                _repeatByte(0x24),
                2,
                bytes32(0)
            ),
            SlotChainGoldenVectors.TERMINAL_FAILED_LEAF
        );
    }

    function test_hashBridgeCreditResult_BindsAllVariableResultFields() external pure {
        bytes32 expected = SlotChainGoldenVectors.BRIDGE_RESULT;
        SlotChainTypes.Kind1ForcedDescriptorV11 memory descriptor = _bridgeDescriptor();

        descriptor.msgHash = HASH_A;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.srcChainId = 2;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.sourceDomainId = HASH_A;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.srcEpoch = 8;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.srcBridge = address(1);
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.bridgeExecutionHash = HASH_A;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.emittedAtBlock = 12_301;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.destinationDomainId = HASH_A;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.destChainId = 16_789;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.enqueueBy = 800_001;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.sender = address(1);
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.srcOwner = address(2);
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.destOwner = address(3);
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.value += 1;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.fee += 1;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.liquidityFee += 1;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.calldataHash = HASH_A;
        _assertBridgeResultChanged(expected, descriptor);
        descriptor = _bridgeDescriptor();
        descriptor.escrowId = HASH_A;
        _assertBridgeResultChanged(expected, descriptor);
    }

    function test_hashBridgeCreditResult_ExcludesQueueAccountingSuffix() external pure {
        SlotChainTypes.Kind1ForcedDescriptorV11 memory descriptor = _bridgeDescriptor();
        bytes32 expected = LibSlotChainEncoding.hashBridgeCreditResult(70, descriptor);

        descriptor.byteLength += 1;
        assertEq(LibSlotChainEncoding.hashBridgeCreditResult(70, descriptor), expected);
        descriptor = _bridgeDescriptor();
        descriptor.accountedGas += 1;
        assertEq(LibSlotChainEncoding.hashBridgeCreditResult(70, descriptor), expected);
        descriptor = _bridgeDescriptor();
        descriptor.refundAddress = address(1);
        assertEq(LibSlotChainEncoding.hashBridgeCreditResult(70, descriptor), expected);
        descriptor = _bridgeDescriptor();
        descriptor.enqueuedAt += 1;
        assertEq(LibSlotChainEncoding.hashBridgeCreditResult(70, descriptor), expected);
        descriptor = _bridgeDescriptor();
        descriptor.dueAt += 1;
        assertEq(LibSlotChainEncoding.hashBridgeCreditResult(70, descriptor), expected);
        descriptor = _bridgeDescriptor();
        descriptor.deposit += 1;
        assertEq(LibSlotChainEncoding.hashBridgeCreditResult(70, descriptor), expected);
    }

    function test_hashBridgeIdentifiers_RevertWhen_NarrowingOrIdentityIsInvalid() external {
        vm.expectRevert(LibSlotChainEncoding.InvalidBridgeCredit.selector);
        harness.hashBridgeCreditId(1, HASH_A, 1, address(1), HASH_B, HASH_A, 0);

        vm.expectRevert(LibSlotChainEncoding.InvalidBridgeCredit.selector);
        harness.hashInboxCreditSlot(bytes32(0));

        SlotChainTypes.Kind1ForcedDescriptorV11 memory descriptor = _bridgeDescriptor();
        descriptor.srcChainId = uint256(type(uint64).max) + 1;
        vm.expectRevert(LibSlotChainEncoding.InvalidBridgeCredit.selector);
        harness.hashBridgeCreditResult(70, descriptor);
    }

    function test_encodeKind1Descriptor_RevertWhen_RefundOrLiquidityTermsAreInvalid() external {
        SlotChainTypes.Kind1ForcedDescriptorV11 memory descriptor = _bridgeDescriptor();
        descriptor.liquidityFee = 0;
        vm.expectRevert(LibSlotChainEncoding.InvalidKind1Descriptor.selector);
        harness.encodeKind1Descriptor(descriptor);

        descriptor = _bridgeDescriptor();
        descriptor.refundMode = 0;
        vm.expectRevert(LibSlotChainEncoding.InvalidKind1Descriptor.selector);
        harness.encodeKind1Descriptor(descriptor);

        descriptor = _bridgeDescriptor();
        descriptor.refundVault = address(1);
        vm.expectRevert(LibSlotChainEncoding.InvalidKind1Descriptor.selector);
        harness.encodeKind1Descriptor(descriptor);

        descriptor = _bridgeDescriptor();
        descriptor.refundCapsuleHash = HASH_A;
        vm.expectRevert(LibSlotChainEncoding.InvalidKind1Descriptor.selector);
        harness.encodeKind1Descriptor(descriptor);

        descriptor = _bridgeDescriptor();
        descriptor.value = 0;
        descriptor.fee = 0;
        vm.expectRevert(LibSlotChainEncoding.InvalidKind1Descriptor.selector);
        harness.encodeKind1Descriptor(descriptor);

        descriptor = _bridgeDescriptor();
        descriptor.value = type(uint256).max;
        descriptor.fee = 1;
        vm.expectRevert(LibSlotChainEncoding.InvalidKind1Descriptor.selector);
        harness.encodeKind1Descriptor(descriptor);
    }

    function test_hashTerminalLeaf_RevertWhen_StateAndSettlementMismatch() external {
        vm.expectRevert(LibSlotChainEncoding.InvalidTerminalLeaf.selector);
        harness.hashTerminalLeaf(0, HASH_A, address(1), HASH_B, 0, bytes32(0));

        vm.expectRevert(LibSlotChainEncoding.InvalidTerminalLeaf.selector);
        harness.hashTerminalLeaf(0, HASH_A, address(1), HASH_B, 1, bytes32(0));

        vm.expectRevert(LibSlotChainEncoding.InvalidTerminalLeaf.selector);
        harness.hashTerminalLeaf(0, HASH_A, address(1), HASH_B, 2, HASH_A);

        vm.expectRevert(LibSlotChainEncoding.InvalidTerminalLeaf.selector);
        harness.hashTerminalLeaf(0, HASH_A, address(1), HASH_B, 3, bytes32(0));
    }

    function test_hashLiquiditySettlement_RevertWhen_IdentityOrAmountIsZero() external {
        SlotChainTypes.LiquiditySettlementV1 memory settlement =
            SlotChainTypes.LiquiditySettlementV1(HASH_A, address(1), 1);
        settlement.ticketId = bytes32(0);
        vm.expectRevert(LibSlotChainEncoding.InvalidLiquiditySettlement.selector);
        harness.hashLiquiditySettlement(settlement);

        settlement = SlotChainTypes.LiquiditySettlementV1(HASH_A, address(0), 1);
        vm.expectRevert(LibSlotChainEncoding.InvalidLiquiditySettlement.selector);
        harness.hashLiquiditySettlement(settlement);

        settlement = SlotChainTypes.LiquiditySettlementV1(HASH_A, address(1), 0);
        vm.expectRevert(LibSlotChainEncoding.InvalidLiquiditySettlement.selector);
        harness.hashLiquiditySettlement(settlement);
    }

    function test_hashRecoveryId_MatchesGoldenVector() external pure {
        SlotChainTypes.RecoveryContextV2 memory context = SlotChainTypes.RecoveryContextV2({
            chainId: 1,
            settlement: address(0xABCD),
            episode: 4,
            revision: 2,
            baseHash: SlotChainGoldenVectors.BASE_CANONICAL,
            roundStartSlot: 8000,
            anchorNumber: 1000,
            anchorHash: _repeatByte(0x88),
            forceRoot: SlotChainGoldenVectors.FORCED_ROOT,
            forceCutoff: 70,
            admissionVersion: 12,
            admissionRoot: SlotChainGoldenVectors.ADMISSION_ROOT,
            escapeSlot: 9000,
            causes: 3
        });
        assertEq(LibSlotChainEncoding.hashRecoveryId(context), SlotChainGoldenVectors.RECOVERY_ID);
    }

    function test_hashForcedUserAndDispositionRows_MatchGoldenVectors() external pure {
        SlotChainTypes.Kind0ForcedDescriptorV2 memory descriptor =
            SlotChainTypes.Kind0ForcedDescriptorV2({
                sender: address(0xCAFE),
                nonce: 0,
                l2ChainId: 16_788,
                rawTxHash: keccak256(abi.encodePacked(uint64(0))),
                byteLength: 123,
                gasLimit: 80_000,
                accountedGas: 80_000,
                maxFee: 10 ** 12,
                validUntil: 9999,
                refundAddress: address(0xBEEF),
                enqueuedAt: 555,
                dueAt: 2055,
                deposit: 10 ** 15
            });
        assertEq(
            LibSlotChainEncoding.hashForcedUserLeaf(0, descriptor),
            SlotChainGoldenVectors.FORCED_LEAF
        );

        SlotChainTypes.DispositionV1[] memory rows = new SlotChainTypes.DispositionV1[](2);
        rows[0] = SlotChainTypes.DispositionV1(2, 1, type(uint32).max, bytes32(0));
        rows[1] = SlotChainTypes.DispositionV1(3, 4, 2, keccak256("raw-signed-tx"));
        assertEq(
            LibSlotChainEncoding.hashDispositions(2, rows), SlotChainGoldenVectors.DISPOSITIONS
        );
    }

    function test_hashTrancheLeaf_MatchesGoldenVector() external pure {
        SlotChainTypes.TrancheLeafV1 memory leaf =
            SlotChainTypes.TrancheLeafV1(7, 519, 2, 10 ** 17, 999_999);
        assertEq(LibSlotChainEncoding.hashTrancheLeaf(leaf), SlotChainGoldenVectors.TRANCHE_LEAF);
    }

    function test_hashRegistryAdmissionAndRankedPrimitives_ComposeToGoldenRoots() external pure {
        SlotChainTypes.RegistryCellV1 memory cell = _registryCell();

        bytes32[] memory registryLeaves = new bytes32[](64);
        for (uint256 i; i < registryLeaves.length; ++i) {
            registryLeaves[i] = LibSlotChainEncoding.hashRegistryLeaf(uint8(i), i == 3, cell);
        }
        assertEq(_foldRegistry(registryLeaves), SlotChainGoldenVectors.REGISTRY_ROOT);

        bytes32[] memory admissionLeaves = new bytes32[](2048);
        for (uint256 i; i < admissionLeaves.length; ++i) {
            bool occupied = i == 3 || i == 64;
            uint8 location = i == 3 ? 1 : (i == 64 ? 2 : 0);
            admissionLeaves[i] =
                LibSlotChainEncoding.hashAdmissionLeaf(uint16(i), occupied, location, cell);
        }
        assertEq(_foldAdmission(admissionLeaves), SlotChainGoldenVectors.ADMISSION_ROOT);

        bytes32[] memory rankedLeaves = new bytes32[](64);
        for (uint256 i; i < rankedLeaves.length; ++i) {
            rankedLeaves[i] = LibSlotChainEncoding.hashRankedEntry(
                uint8(i), i == 0, cell, SlotChainGoldenVectors.TRANCHE_LEAF
            );
        }
        assertEq(_foldRanked(rankedLeaves), SlotChainGoldenVectors.ENTRY_ROOT);
    }

    function test_hashFixedTreeEmptyPrimitives_ComposeToGoldenRoots() external pure {
        bytes32 forcedNode = LibSlotChainEncoding.hashForcedEmptyLeaf();
        for (uint8 height; height < 64; ++height) {
            forcedNode = LibSlotChainEncoding.hashForcedNode(height, forcedNode, forcedNode);
        }
        assertEq(
            LibSlotChainEncoding.hashForcedRoot(0, forcedNode),
            SlotChainGoldenVectors.EMPTY_FORCED_ROOT
        );

        bytes32 terminalNode = LibSlotChainEncoding.hashTerminalEmptyLeaf();
        for (uint8 height; height < 64; ++height) {
            terminalNode = LibSlotChainEncoding.hashTerminalNode(height, terminalNode, terminalNode);
        }
        assertEq(
            LibSlotChainEncoding.hashTerminalRoot(0, terminalNode),
            SlotChainGoldenVectors.EMPTY_TERMINAL_ROOT
        );
    }

    function test_hashAdmissionAndTrancheLeaves_RevertWhen_EnumIsInvalid() external {
        SlotChainTypes.RegistryCellV1 memory cell = _registryCell();
        vm.expectRevert(LibSlotChainEncoding.InvalidAdmissionLocation.selector);
        harness.hashAdmissionLeaf(0, true, 0, cell);

        SlotChainTypes.TrancheLeafV1 memory leaf = SlotChainTypes.TrancheLeafV1(0, 0, 6, 0, 0);
        vm.expectRevert(LibSlotChainEncoding.InvalidTrancheState.selector);
        harness.hashTrancheLeaf(leaf);
    }

    function test_hashTrancheNode_UsesExactDomainAndFieldWidths() external pure {
        assertEq(
            LibSlotChainEncoding.hashTrancheNode(8, HASH_A, HASH_B),
            keccak256(abi.encodePacked("slot-chain-tranche-node-v1", uint8(8), HASH_A, HASH_B))
        );
    }

    function _candidateRows(uint256 _count)
        private
        pure
        returns (SlotChainTypes.CandidateBlockV2[] memory rows_)
    {
        rows_ = new SlotChainTypes.CandidateBlockV2[](_count);
        for (uint256 i; i < _count; ++i) {
            rows_[i] = SlotChainTypes.CandidateBlockV2({
                slot: uint64(i),
                blockStructHash: HASH_A,
                blockHash: HASH_B,
                bodyRoot: HASH_A,
                dataManifestRoot: HASH_B,
                messageEnd: uint64(i)
            });
        }
    }

    function _dataRecord0() private pure returns (SlotChainTypes.DataRecordV1 memory record_) {
        record_ = SlotChainTypes.DataRecordV1({
            sessionId: SlotChainGoldenVectors.SESSION_ID,
            recordIndex: 0,
            versionedHash: _repeatByte(0x33),
            fullBodyRoot: SlotChainGoldenVectors.BODY_ROOT,
            blockOrdinal: 0,
            chunkIndex: 0,
            chunkCount: 2,
            chunkLength: 5,
            chunkRoot: SlotChainGoldenVectors.CHUNK_ROOT_0,
            publisher: address(0xCAFE),
            validUntil: 9999,
            z: 5,
            y: 6
        });
    }

    function _dataRecord1() private pure returns (SlotChainTypes.DataRecordV1 memory record_) {
        record_ = SlotChainTypes.DataRecordV1({
            sessionId: SlotChainGoldenVectors.SESSION_ID,
            recordIndex: 1,
            versionedHash: _repeatByte(0x55),
            fullBodyRoot: SlotChainGoldenVectors.BODY_ROOT,
            blockOrdinal: 0,
            chunkIndex: 1,
            chunkCount: 2,
            chunkLength: 4,
            chunkRoot: LibSlotChainEncoding.hashBodyChunk(
                SlotChainGoldenVectors.BODY_ROOT, 0, 1, 2, bytes("beta")
            ),
            publisher: address(0xCAFE),
            validUntil: 9999,
            z: 7,
            y: 8
        });
    }

    function _dataRecord2() private pure returns (SlotChainTypes.DataRecordV1 memory record_) {
        record_ = SlotChainTypes.DataRecordV1({
            sessionId: SlotChainGoldenVectors.SESSION_ID,
            recordIndex: 2,
            versionedHash: _repeatByte(0x77),
            fullBodyRoot: SlotChainGoldenVectors.BODY_ROOT,
            blockOrdinal: 1,
            chunkIndex: 0,
            chunkCount: 1,
            chunkLength: 5,
            chunkRoot: LibSlotChainEncoding.hashBodyChunk(
                SlotChainGoldenVectors.BODY_ROOT, 1, 0, 1, bytes("gamma")
            ),
            publisher: address(0xBEEF),
            validUntil: 10_001,
            z: 9,
            y: 10
        });
    }

    function _asymmetricDataRecord()
        private
        pure
        returns (SlotChainTypes.DataRecordV1 memory record_)
    {
        bytes memory chunk = bytes("asymmetric-data-record");
        bytes32 bodyRoot = _repeatByte(0x61);
        record_ = SlotChainTypes.DataRecordV1({
            sessionId: SlotChainGoldenVectors.SESSION_ID,
            recordIndex: 7,
            versionedHash: _repeatByte(0x57),
            fullBodyRoot: bodyRoot,
            blockOrdinal: 3,
            chunkIndex: 1,
            chunkCount: 9,
            chunkLength: uint32(chunk.length),
            chunkRoot: LibSlotChainEncoding.hashBodyChunk(bodyRoot, 3, 1, 9, chunk),
            publisher: address(0xDADA),
            validUntil: 65_535,
            z: 11,
            y: 13
        });
    }

    function _asymmetricManifestEntry(SlotChainTypes.DataRecordV1 memory _record)
        private
        pure
        returns (SlotChainTypes.ManifestEntryV1 memory entry_)
    {
        entry_ = SlotChainTypes.ManifestEntryV1({
            blockOrdinal: _record.blockOrdinal,
            sessionId: _record.sessionId,
            recordIndex: _record.recordIndex,
            chunkIndex: _record.chunkIndex,
            chunkCount: _record.chunkCount,
            chunkLength: _record.chunkLength,
            fullBodyRoot: _record.fullBodyRoot,
            chunkRoot: _record.chunkRoot
        });
    }

    function _popcount(uint16 _value) private pure returns (uint8 count_) {
        for (uint8 height; height < 12; ++height) {
            if ((_value & (uint16(1) << height)) != 0) ++count_;
        }
    }

    function _syntheticPeaks(uint16 _count) private pure returns (bytes memory encoded_) {
        for (uint8 height; height < 12; ++height) {
            if ((_count & (uint16(1) << height)) != 0) {
                encoded_ = bytes.concat(
                    encoded_, abi.encodePacked(height, bytes32(uint256(height) + 1))
                );
            }
        }
    }

    function _foldRegistry(bytes32[] memory _nodes) private pure returns (bytes32 root_) {
        uint256 width = _nodes.length;
        uint8 height;
        while (width > 1) {
            for (uint256 i; i < width; i += 2) {
                _nodes[i / 2] =
                    LibSlotChainEncoding.hashRegistryNode(height, _nodes[i], _nodes[i + 1]);
            }
            width /= 2;
            ++height;
        }
        return _nodes[0];
    }

    function _foldAdmission(bytes32[] memory _nodes) private pure returns (bytes32 root_) {
        uint256 width = _nodes.length;
        uint8 height;
        while (width > 1) {
            for (uint256 i; i < width; i += 2) {
                _nodes[i / 2] =
                    LibSlotChainEncoding.hashAdmissionNode(height, _nodes[i], _nodes[i + 1]);
            }
            width /= 2;
            ++height;
        }
        return _nodes[0];
    }

    function _foldRanked(bytes32[] memory _nodes) private pure returns (bytes32 root_) {
        uint256 width = _nodes.length;
        uint8 height;
        while (width > 1) {
            for (uint256 i; i < width; i += 2) {
                _nodes[i / 2] =
                    LibSlotChainEncoding.hashRankedEntryNode(height, _nodes[i], _nodes[i + 1]);
            }
            width /= 2;
            ++height;
        }
        return _nodes[0];
    }

    function _registryCell() private pure returns (SlotChainTypes.RegistryCellV1 memory cell_) {
        cell_ = SlotChainTypes.RegistryCellV1({
            builder: address(0x1234),
            bond: 10 ** 18,
            registrationIndex: 9,
            effectiveL2Slot: 777,
            trancheRoot: _repeatByte(0x11),
            tombstonedAtL2Slot: type(uint64).max
        });
    }

    function _forcedDescriptor(uint64 _nonce)
        private
        pure
        returns (SlotChainTypes.Kind0ForcedDescriptorV2 memory descriptor_)
    {
        descriptor_ = SlotChainTypes.Kind0ForcedDescriptorV2({
            sender: address(0xCAFE),
            nonce: _nonce,
            l2ChainId: 16_788,
            rawTxHash: keccak256(abi.encodePacked(_nonce)),
            byteLength: 123,
            gasLimit: 80_000,
            accountedGas: 80_000,
            maxFee: 10 ** 12,
            validUntil: 9999,
            refundAddress: address(0xBEEF),
            enqueuedAt: 555,
            dueAt: 2055 + _nonce,
            deposit: 10 ** 15
        });
    }

    function _bridgeDescriptor()
        private
        pure
        returns (SlotChainTypes.Kind1ForcedDescriptorV11 memory descriptor_)
    {
        descriptor_.msgHash = _repeatByte(0x21);
        descriptor_.srcChainId = 1;
        descriptor_.sourceDomainId = SlotChainGoldenVectors.SOURCE_DOMAIN_ID;
        descriptor_.srcEpoch = 7;
        descriptor_.srcBridge = address(0xFfF25F997872E08385a4Dc63163E60181C213F62);
        descriptor_.bridgeExecutionHash = SlotChainGoldenVectors.BRIDGE_EXECUTION_HASH;
        descriptor_.emittedAtBlock = 12_300;
        descriptor_.destinationDomainId = SlotChainGoldenVectors.DESTINATION_DOMAIN_ID;
        descriptor_.destChainId = 16_788;
        descriptor_.enqueueBy = 800_000;
        descriptor_.sender = address(0x3333);
        descriptor_.srcOwner = address(0x1111);
        descriptor_.destOwner = address(0x2222);
        descriptor_.value = 10 ** 18;
        descriptor_.fee = 1234;
        descriptor_.liquidityFee = 5678;
        descriptor_.calldataHash = _repeatByte(0x22);
        descriptor_.refundMode = 1;
        descriptor_.refundVault = address(0);
        descriptor_.refundCapsuleHash = bytes32(0);
        descriptor_.escrowId = SlotChainGoldenVectors.BRIDGE_ESCROW_ID;
        descriptor_.byteLength = 96;
        descriptor_.accountedGas = 120_000;
        descriptor_.refundAddress = address(0xBEEF);
        descriptor_.enqueuedAt = 700;
        descriptor_.dueAt = 2200;
        descriptor_.deposit = 10 ** 16;
    }

    function _assertBridgeResultChanged(
        bytes32 _expected,
        SlotChainTypes.Kind1ForcedDescriptorV11 memory _descriptor
    )
        private
        pure
    {
        assertNotEq(LibSlotChainEncoding.hashBridgeCreditResult(70, _descriptor), _expected);
    }

    function _rewardReceipt()
        private
        pure
        returns (SlotChainTypes.RewardReceiptV1 memory receipt_)
    {
        receipt_ =
            SlotChainTypes.RewardReceiptV1({
                candidateId: HASH_A,
                beneficiary: address(0xCAFE),
                rewardClass: 1,
                rewardExecutionGas: 0,
                rewardPublishedBytes: 0,
                executionProfileHash: HASH_B,
                committedAtBlock: 1,
                committedAtTimestamp: 2,
                claimUntil: 3,
                claimed: false
            });
    }

    function _signedBlock() private pure returns (SlotChainTypes.SlotChainBlock memory block_) {
        block_ = SlotChainTypes.SlotChainBlock({
            settlementChainId: 1,
            l2ChainId: 16_788,
            protocolVersion: 2,
            verifyingContract: address(0xABCD),
            slot: 8001,
            parentHash: _repeatByte(0x77),
            blockHash: _repeatByte(0x88),
            stateRoot: _repeatByte(0x66),
            bodyRoot: SlotChainGoldenVectors.BODY_ROOT,
            anchorNumber: 1000,
            anchorHash: _repeatByte(0x99),
            forceRoot: SlotChainGoldenVectors.FORCED_ROOT,
            forceCutoff: 70,
            messageStart: 2,
            messageEnd: 66,
            dataManifestRoot: SlotChainGoldenVectors.MANIFEST_ROOT,
            coinbase: address(0xCAFE),
            tier: 1,
            contextId: SlotChainGoldenVectors.NORMAL_CONTEXT,
            admissionVersion: 12,
            admissionRoot: SlotChainGoldenVectors.ADMISSION_ROOT,
            episode: 0,
            recoveryRevision: 0,
            recoveryId: bytes32(0)
        });
    }

    function _repeatByte(uint8 _value) private pure returns (bytes32 value_) {
        return bytes32(type(uint256).max / 255 * uint256(_value));
    }
}

contract EncodingHarness {
    function hashCandidate(
        bytes32 _baseHash,
        SlotChainTypes.CandidateBlockV2[] memory _rows
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashCandidate(_baseHash, _rows);
    }

    function hashScheduleList(SlotChainTypes.ScheduleEntryV1[] memory _rows)
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashScheduleList(_rows);
    }

    function hashSessionList(SlotChainTypes.SessionRefV1[] memory _rows)
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashSessionList(_rows);
    }

    function hashForcedDescriptorList(
        uint64 _start,
        SlotChainTypes.ForcedDescriptorRowV2[] memory _rows,
        bool _hasBoundary,
        SlotChainTypes.ForcedDescriptorRowV2 memory _boundary
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashForcedDescriptorList(_start, _rows, _hasBoundary, _boundary);
    }

    function hashManifestLeaf(
        uint16 _expectedBlockOrdinal,
        uint16 _position,
        SlotChainTypes.ManifestEntryV1 memory _entry
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashManifestLeaf(_expectedBlockOrdinal, _position, _entry);
    }

    function hashManifestRoot(
        uint16 _count,
        bytes32 _treeRoot
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashManifestRoot(_count, _treeRoot);
    }

    function hashDataBag(
        uint16 _recordCount,
        uint8 _peakCount,
        bytes memory _encodedPeaks
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashDataBag(_recordCount, _peakCount, _encodedPeaks);
    }

    function hashDispositions(
        uint64 _start,
        SlotChainTypes.DispositionV1[] memory _rows
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashDispositions(_start, _rows);
    }

    function hashRewardReceipt(SlotChainTypes.RewardReceiptV1 memory _receipt)
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashRewardReceipt(_receipt);
    }

    function hashAdmissionLeaf(
        uint16 _index,
        bool _occupied,
        uint8 _location,
        SlotChainTypes.RegistryCellV1 memory _cell
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashAdmissionLeaf(_index, _occupied, _location, _cell);
    }

    function hashTrancheLeaf(SlotChainTypes.TrancheLeafV1 memory _leaf)
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashTrancheLeaf(_leaf);
    }

    function encodeKind1Descriptor(SlotChainTypes.Kind1ForcedDescriptorV11 memory _descriptor)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibSlotChainEncoding.encodeKind1Descriptor(_descriptor);
    }

    function hashTerminalLeaf(
        uint64 _index,
        bytes32 _destinationDomainId,
        address _destinationBridge,
        bytes32 _creditId,
        uint8 _terminal,
        bytes32 _liquiditySettlementHash
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashTerminalLeaf(
            _index,
            _destinationDomainId,
            _destinationBridge,
            _creditId,
            _terminal,
            _liquiditySettlementHash
        );
    }

    function hashBridgeCreditId(
        uint64 _sourceChainId,
        bytes32 _sourceDomainId,
        uint64 _sourceEpoch,
        address _sourceBridge,
        bytes32 _destinationDomainId,
        bytes32 _messageHash,
        uint64 _liquidityFee
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashBridgeCreditId(
            _sourceChainId,
            _sourceDomainId,
            _sourceEpoch,
            _sourceBridge,
            _destinationDomainId,
            _messageHash,
            _liquidityFee
        );
    }

    function hashInboxCreditSlot(bytes32 _creditId) external pure returns (bytes32 hash_) {
        return LibSlotChainEncoding.hashInboxCreditSlot(_creditId);
    }

    function hashBridgeCreditResult(
        uint64 _index,
        SlotChainTypes.Kind1ForcedDescriptorV11 memory _descriptor
    )
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashBridgeCreditResult(_index, _descriptor);
    }

    function hashSourceContext(SlotChainTypes.SourceContextV2 memory _context)
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashSourceContext(_context);
    }

    function hashSourceDomain(SlotChainTypes.SourceDomainV4 memory _domain)
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashSourceDomain(_domain);
    }

    function hashDestinationDomain(SlotChainTypes.DestinationDomainV7 memory _domain)
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashDestinationDomain(_domain);
    }

    function hashLiquiditySettlement(SlotChainTypes.LiquiditySettlementV1 memory _settlement)
        external
        pure
        returns (bytes32 hash_)
    {
        return LibSlotChainEncoding.hashLiquiditySettlement(_settlement);
    }
}
