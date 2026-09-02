// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    LibScheduleForkVerifierCallV1
} from "../../../../contracts/layer1/slotchain/libs/LibScheduleForkVerifierCallV1.sol";
import {
    LibScheduleSealWitnessV1
} from "../../../../contracts/layer1/slotchain/libs/LibScheduleSealWitnessV1.sol";
import {
    LibScheduleSnapshotEvaluatorV1
} from "../../../../contracts/layer1/slotchain/libs/LibScheduleSnapshotEvaluatorV1.sol";
import { LibMptProof } from "../../../../contracts/shared/slotchain/libs/LibMptProof.sol";
import { CanonicalTrieFixtures } from "../../../shared/slotchain/utils/CanonicalTrieFixtures.sol";
import { Test } from "forge-std/src/Test.sol";

contract ScheduleSnapshotEvaluatorHarness {
    function evaluate(
        bytes calldata _witness,
        LibScheduleSnapshotEvaluatorV1.SnapshotContext calldata _context,
        LibScheduleForkVerifierCallV1.Carrier calldata _carrier
    )
        external
        pure
        returns (bytes32 entryRoot_)
    {
        return LibScheduleSnapshotEvaluatorV1.evaluate(_witness, _context, _carrier);
    }
}

contract LibScheduleSnapshotEvaluatorV1Test is Test {
    bytes32 private constant _HEADER_KEY =
        0x3dc336ad17079f9525d2b0708a8773321ab29957d522a6f2d10fc522b7362aec;
    bytes32 private constant _ROOT_KEY =
        0x04bafd6333ae949248e59a002ce1fbccb8a4bc8da3a0c3228ae523d727170880;
    bytes4 private constant _HEADER_MAGIC = 0x42524831;
    uint64 private constant _LIVE = type(uint64).max;
    uint256 private constant _CELL_BYTES = 101;
    uint256 private constant _RECORD_BYTES = 329;

    struct CellInput {
        bool present;
        address builder;
        uint192 bond;
        uint64 registrationIndex;
        uint64 effectiveL2Slot;
        uint64 tombstonedAtL2Slot;
        uint64 trancheWindow;
        uint8 trancheState;
        uint192 trancheAmount;
        uint64 liableUntil;
    }

    struct HeaderInput {
        bytes4 magic;
        uint8 version;
        uint8 activeCount;
        uint16 reserved;
        uint64 registryMutationVersion;
        uint64 admissionVersion;
        uint64 nextRegistrationIndex;
    }

    struct Fixture {
        bytes witness;
        LibScheduleSnapshotEvaluatorV1.SnapshotContext context;
        LibScheduleForkVerifierCallV1.Carrier carrier;
        bytes32 expectedEntryRoot;
        uint256 accountSegmentOffset;
        uint256 accountSegmentLength;
        uint256 headerSegmentOffset;
        uint256 headerSegmentLength;
        uint256 rootSegmentOffset;
        uint256 rootSegmentLength;
        uint256 cellsOffset;
        uint256 recordsOffset;
    }

    struct ProofParts {
        bytes accountPath;
        bytes headerPath;
        bytes rootPath;
        bytes32 stateRoot;
        uint256 accountSegmentOffset;
        uint256 headerSegmentOffset;
        uint256 rootSegmentOffset;
        uint256 cellsOffset;
    }

    ScheduleSnapshotEvaluatorHarness private _harness;

    function setUp() external {
        _harness = new ScheduleSnapshotEvaluatorHarness();
    }

    function test_evaluate_AuthenticatesEmptySnapshotUnderParentPayloadStateRoot() external {
        CellInput[64] memory cells;
        Fixture memory fixture = _canonicalFixture(cells, _baseContext(7), 1050, 100);

        assertEq(
            _harness.evaluate(fixture.witness, fixture.context, fixture.carrier),
            fixture.expectedEntryRoot
        );
        assertEq(fixture.expectedEntryRoot, _emptyEntryRootOracle());

        LibScheduleForkVerifierCallV1.Carrier memory wrongCarrier = fixture.carrier;
        wrongCarrier.stateRoot = bytes32(uint256(wrongCarrier.stateRoot) ^ 1);
        vm.expectRevert(LibMptProof.MptReferenceMismatch.selector);
        _harness.evaluate(fixture.witness, fixture.context, wrongCarrier);
    }

    function test_evaluate_RejectsWrongRegistryAddressAndRuntimeHash() external {
        CellInput[64] memory cells;
        Fixture memory fixture = _canonicalFixture(cells, _baseContext(7), 1050, 100);

        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = fixture.context;
        context.builderRegistry = address(uint160(context.builderRegistry) ^ 1);
        vm.expectRevert(LibMptProof.MptKeyMismatch.selector);
        _harness.evaluate(fixture.witness, context, fixture.carrier);

        context = fixture.context;
        context.builderRegistry = address(0xB01D);
        context.builderRegistryRuntimeHash =
            bytes32(uint256(context.builderRegistryRuntimeHash) ^ 1);
        vm.expectRevert(LibMptProof.InvalidMptAccount.selector);
        _harness.evaluate(fixture.witness, context, fixture.carrier);
    }

    function test_evaluate_BothStorageKeysShareOneRootAndSwappedPathsFail() external {
        CellInput[64] memory cells;
        Fixture memory fixture = _canonicalFixture(cells, _baseContext(7), 1050, 100);
        assertEq(fixture.headerSegmentLength, fixture.rootSegmentLength);

        bytes memory swapped = _copy(fixture.witness);
        _swapEqualSegments(
            swapped,
            fixture.headerSegmentOffset,
            fixture.rootSegmentOffset,
            fixture.headerSegmentLength
        );
        vm.expectRevert(LibMptProof.MptReferenceMismatch.selector);
        _harness.evaluate(swapped, fixture.context, fixture.carrier);

        bytes memory wrongRootPath = _copy(fixture.witness);
        wrongRootPath[fixture.rootSegmentOffset + 3] =
            bytes1(uint8(wrongRootPath[fixture.rootSegmentOffset + 3]) ^ 1);
        vm.expectRevert();
        _harness.evaluate(wrongRootPath, fixture.context, fixture.carrier);
    }

    function test_evaluate_DecodesExactBigEndianHeaderAndNextIndexBoundary() external view {
        CellInput[64] memory cells;
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        cells[0] = _reservedCell(1, 0x0102030405060707, 1050, context);
        HeaderInput memory header = HeaderInput({
            magic: _HEADER_MAGIC,
            version: 1,
            activeCount: 1,
            reserved: 0,
            registryMutationVersion: 0x1112131415161718,
            admissionVersion: 0x2122232425262728,
            nextRegistrationIndex: 0x0102030405060708
        });
        Fixture memory fixture = _build(cells, context, 1050, header);
        assertEq(
            _harness.evaluate(fixture.witness, context, fixture.carrier), fixture.expectedEntryRoot
        );
    }

    function test_evaluate_RejectsHeaderMagicVersionReservedAndActiveCount() external {
        CellInput[64] memory cells;
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        HeaderInput memory header = _canonicalHeader(0, 100);

        header.magic = 0x42524830;
        _expectInvalidHeader(_build(cells, context, 1050, header));
        header = _canonicalHeader(0, 100);
        header.version = 2;
        _expectInvalidHeader(_build(cells, context, 1050, header));
        header = _canonicalHeader(0, 100);
        header.reserved = 1;
        _expectInvalidHeader(_build(cells, context, 1050, header));
        header = _canonicalHeader(0, 100);
        header.activeCount = 65;
        _expectInvalidHeader(_build(cells, context, 1050, header));

        header = _canonicalHeader(1, 100);
        Fixture memory countMismatch = _build(cells, context, 1050, header);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSnapshotEvaluatorV1.ActiveBuilderCountMismatch.selector, 1, 0
            )
        );
        _harness.evaluate(countMismatch.witness, context, countMismatch.carrier);
    }

    function test_evaluate_AcceptsPresentCellsAtBothTreeOrientationBoundaries() external view {
        CellInput[64] memory cells;
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(511);
        cells[0] = _reservedCell(10, 1000, 1050, context);
        cells[63] = _reservedCell(11, 1100, 1050, context);
        Fixture memory fixture = _canonicalFixture(cells, context, 1050, 12);

        assertEq(
            _harness.evaluate(fixture.witness, context, fixture.carrier), fixture.expectedEntryRoot
        );
        assertEq(fixture.cellsOffset + 63 * _CELL_BYTES, fixture.recordsOffset - _CELL_BYTES);
    }

    function test_evaluate_RejectsMutatedCellAtExactLastCellOffset() external {
        CellInput[64] memory cells;
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        cells[63] = _reservedCell(1, 1000, 1050, context);
        Fixture memory fixture = _canonicalFixture(cells, context, 1050, 2);
        bytes memory mutated = _copy(fixture.witness);
        uint256 bondLastByte = fixture.cellsOffset + 63 * _CELL_BYTES + 44;
        mutated[bondLastByte] = bytes1(uint8(mutated[bondLastByte]) ^ 1);

        vm.expectRevert(LibScheduleSnapshotEvaluatorV1.BuilderRegistryRootMismatch.selector);
        _harness.evaluate(mutated, context, fixture.carrier);
    }

    function test_evaluate_RegistrationIndexNextMinusOneAcceptedAndNextRejected() external {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _reservedCell(4, 1000, 1050, context);
        Fixture memory accepted = _canonicalFixture(cells, context, 1050, 5);
        assertEq(
            _harness.evaluate(accepted.witness, context, accepted.carrier),
            accepted.expectedEntryRoot
        );

        cells[0].registrationIndex = 5;
        Fixture memory rejected = _canonicalFixture(cells, context, 1050, 5);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSnapshotEvaluatorV1.InvalidBuilderRegistryCell.selector, 0
            )
        );
        _harness.evaluate(rejected.witness, context, rejected.carrier);
    }

    function test_evaluate_BondLeaseBoundaryAndExactTrancheLease() external {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _reservedCell(1, context.leasePerWindowAtomic, 1050, context);
        Fixture memory exact = _canonicalFixture(cells, context, 1050, 2);
        assertEq(_harness.evaluate(exact.witness, context, exact.carrier), exact.expectedEntryRoot);

        cells[0].bond = context.leasePerWindowAtomic - 1;
        Fixture memory belowBond = _canonicalFixture(cells, context, 1050, 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSnapshotEvaluatorV1.InvalidBuilderRegistryCell.selector, 0
            )
        );
        _harness.evaluate(belowBond.witness, context, belowBond.carrier);

        cells[0].bond = context.leasePerWindowAtomic;
        cells[0].trancheAmount = context.leasePerWindowAtomic - 1;
        Fixture memory belowTranche = _canonicalFixture(cells, context, 1050, 2);
        vm.expectRevert(
            abi.encodeWithSelector(LibScheduleSnapshotEvaluatorV1.InvalidBuilderTranche.selector, 0)
        );
        _harness.evaluate(belowTranche.witness, context, belowTranche.carrier);
    }

    function test_evaluate_RejectsZeroBuilderAndZeroTrancheRoot() external {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _reservedCell(1, 1000, 1050, context);
        cells[0].builder = address(0);
        Fixture memory zeroBuilder = _canonicalFixture(cells, context, 1050, 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSnapshotEvaluatorV1.InvalidBuilderRegistryCell.selector, 0
            )
        );
        _harness.evaluate(zeroBuilder.witness, context, zeroBuilder.carrier);

        cells[0].builder = address(0x1001);
        Fixture memory zeroRoot = _canonicalFixture(cells, context, 1050, 2);
        for (uint256 i; i < 32; ++i) {
            zeroRoot.witness[zeroRoot.cellsOffset + 61 + i] = 0;
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSnapshotEvaluatorV1.InvalidBuilderRegistryCell.selector, 0
            )
        );
        _harness.evaluate(zeroRoot.witness, context, zeroRoot.carrier);
    }

    function test_evaluate_RejectsDuplicateBuilderEvenWhenSecondIsIneligible() external {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _reservedCell(1, 1000, 1050, context);
        cells[1] = _reservedCell(2, 1001, 1050, context);
        cells[1].builder = cells[0].builder;
        cells[1].effectiveL2Slot = 51;
        Fixture memory fixture = _canonicalFixture(cells, context, 1050, 3);

        vm.expectRevert(
            abi.encodeWithSelector(LibScheduleSnapshotEvaluatorV1.DuplicateBuilder.selector, 1)
        );
        _harness.evaluate(fixture.witness, context, fixture.carrier);
    }

    function test_evaluate_RejectsDuplicateRegistrationIndexEvenWhenSecondIsIneligible() external {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _reservedCell(1, 1000, 1050, context);
        cells[1] = _reservedCell(2, 1001, 1050, context);
        cells[1].registrationIndex = cells[0].registrationIndex;
        cells[1].tombstonedAtL2Slot = 50;
        Fixture memory fixture = _canonicalFixture(cells, context, 1050, 3);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSnapshotEvaluatorV1.DuplicateRegistrationIndex.selector, 1
            )
        );
        _harness.evaluate(fixture.witness, context, fixture.carrier);
    }

    function test_evaluate_AcceptsEveryCanonicalTrancheState() external view {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        for (uint8 state; state <= 5; ++state) {
            CellInput[64] memory cells;
            cells[0] = _cellForState(state, context);
            Fixture memory fixture = _canonicalFixture(cells, context, 1050, 2);
            assertEq(
                _harness.evaluate(fixture.witness, context, fixture.carrier),
                fixture.expectedEntryRoot,
                string.concat("state ", vm.toString(state))
            );
        }
    }

    function test_evaluate_RejectsInvalidTrancheStateAndNonCanonicalStatePayloads() external {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;

        cells[0] = _cellForState(6, context);
        _expectInvalidTranche(_canonicalFixture(cells, context, 1050, 2));

        cells[0] = _cellForState(0, context);
        cells[0].trancheWindow = context.window;
        _expectInvalidTranche(_canonicalFixture(cells, context, 1050, 2));
        cells[0] = _cellForState(0, context);
        cells[0].trancheAmount = 1;
        _expectInvalidTranche(_canonicalFixture(cells, context, 1050, 2));

        cells[0] = _cellForState(1, context);
        cells[0].liableUntil = 1;
        _expectInvalidTranche(_canonicalFixture(cells, context, 1050, 2));

        cells[0] = _cellForState(2, context);
        cells[0].trancheAmount -= 1;
        _expectInvalidTranche(_canonicalFixture(cells, context, 1050, 2));
        cells[0] = _cellForState(3, context);
        cells[0].liableUntil += 1;
        _expectInvalidTranche(_canonicalFixture(cells, context, 1050, 2));

        cells[0] = _cellForState(4, context);
        cells[0].trancheAmount = 1;
        _expectInvalidTranche(_canonicalFixture(cells, context, 1050, 2));
        cells[0] = _cellForState(5, context);
        cells[0].liableUntil -= 1;
        _expectInvalidTranche(_canonicalFixture(cells, context, 1050, 2));
    }

    function test_evaluate_PinsModuloWindows511And512AndHighManagedWindow() external view {
        CellInput[64] memory cells;
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(511);
        cells[0] = _reservedCell(1, 1000, 1050, context);
        Fixture memory w511 = _canonicalFixture(cells, context, 1050, 2);
        assertEq(_harness.evaluate(w511.witness, context, w511.carrier), w511.expectedEntryRoot);

        context = _baseContext(512);
        cells[0] = _reservedCell(1, 1000, 1050, context);
        Fixture memory w512 = _canonicalFixture(cells, context, 1050, 2);
        assertEq(_harness.evaluate(w512.witness, context, w512.carrier), w512.expectedEntryRoot);

        context = _baseContext(type(uint64).max - 1);
        context.firstManagedWindow = type(uint64).max - 1;
        context.lastManagedWindow = type(uint64).max - 1;
        cells[0] = _cellForState(1, context);
        Fixture memory high = _canonicalFixture(cells, context, 1, 2);
        assertEq(_harness.evaluate(high.witness, context, high.carrier), high.expectedEntryRoot);
    }

    function test_evaluate_RejectsModuloMismatchAndDeadlineUint64Overflow() external {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(512);
        CellInput[64] memory cells;
        cells[0] = _cellForState(1, context);
        cells[0].trancheWindow = 511;
        _expectInvalidTranche(_canonicalFixture(cells, context, 1050, 2));

        context = _baseContext(1);
        context.genesisTimestamp = type(uint64).max;
        context.firstManagedWindow = 1;
        context.lastManagedWindow = 1;
        cells[0] = _cellForState(2, context);
        cells[0].liableUntil = type(uint64).max;
        _expectInvalidTranche(_canonicalFixture(cells, context, 1, 2));
    }

    function test_evaluate_EligibilityUsesInclusiveEffectiveAndStrictTombstone() external view {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _reservedCell(1, 1000, 1050, context);
        cells[0].effectiveL2Slot = 50;
        cells[0].tombstonedAtL2Slot = 51;
        Fixture memory eligible = _canonicalFixture(cells, context, 1050, 2);
        assertEq(
            _harness.evaluate(eligible.witness, context, eligible.carrier),
            eligible.expectedEntryRoot
        );
        assertNotEq(eligible.expectedEntryRoot, _emptyEntryRootOracle());

        cells[0].tombstonedAtL2Slot = 50;
        Fixture memory exactTombstone = _canonicalFixture(cells, context, 1050, 2);
        assertEq(
            _harness.evaluate(exactTombstone.witness, context, exactTombstone.carrier),
            _emptyEntryRootOracle()
        );
    }

    function test_evaluate_LiveSentinelIsEligibleNormallyButNotAtUint64MaxSource() external view {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        context.genesisTimestamp = 0;
        CellInput[64] memory cells;
        cells[0] = _reservedCell(1, 1000, 50, context);
        cells[0].tombstonedAtL2Slot = _LIVE;
        Fixture memory ordinary = _canonicalFixture(cells, context, 50, 2);
        assertNotEq(
            _harness.evaluate(ordinary.witness, context, ordinary.carrier), _emptyEntryRootOracle()
        );

        cells[0].effectiveL2Slot = _LIVE;
        Fixture memory maximum = _canonicalFixture(cells, context, _LIVE, 2);
        assertEq(
            _harness.evaluate(maximum.witness, context, maximum.carrier), _emptyEntryRootOracle()
        );
    }

    function test_evaluate_PayloadEarlierThanGenesisSaturatesSourceSlotToZero() external view {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _reservedCell(1, 1000, 999, context);
        cells[0].effectiveL2Slot = 0;
        Fixture memory fixture = _canonicalFixture(cells, context, 999, 2);
        assertNotEq(
            _harness.evaluate(fixture.witness, context, fixture.carrier), _emptyEntryRootOracle()
        );
    }

    function test_evaluate_DoesNotInventEffectiveBeforeTombstoneCellInvariant() external view {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _reservedCell(1, 1000, 1015, context);
        cells[0].effectiveL2Slot = 20;
        cells[0].tombstonedAtL2Slot = 10;
        Fixture memory fixture = _canonicalFixture(cells, context, 1015, 2);
        assertEq(
            _harness.evaluate(fixture.witness, context, fixture.carrier), _emptyEntryRootOracle()
        );
    }

    function test_evaluate_RanksBondDescendingThenRegistrationIndexAscending() external view {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[2] = _reservedCell(7, 200, 1050, context);
        cells[9] = _reservedCell(3, 200, 1050, context);
        cells[63] = _reservedCell(2, 100, 1050, context);
        Fixture memory fixture = _canonicalFixture(cells, context, 1050, 8);

        bytes32 result = _harness.evaluate(fixture.witness, context, fixture.carrier);
        assertEq(result, fixture.expectedEntryRoot);
        uint8[64] memory wrongOrder;
        wrongOrder[0] = 2;
        wrongOrder[1] = 9;
        wrongOrder[2] = 63;
        assertNotEq(result, _entryRootForOrder(cells, context, wrongOrder, 3));
    }

    function test_evaluate_EmptyRanksArePositionBound() external view {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _reservedCell(1, 1000, 1050, context);
        Fixture memory fixture = _canonicalFixture(cells, context, 1050, 2);
        bytes32 result = _harness.evaluate(fixture.witness, context, fixture.carrier);

        bytes32[64] memory wrongLeaves;
        bytes32 rankZeroEmpty = _entryLeaf(0, false, cells[0], bytes32(0));
        for (uint256 i; i < 64; ++i) {
            wrongLeaves[i] = rankZeroEmpty;
        }
        assertNotEq(result, _foldEntry(wrongLeaves));
    }

    function test_evaluate_RecordOrdinalAdvancesForEveryPresentCell() external view {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _cellForState(1, context);
        cells[63] = _reservedCell(2, 1000, 1050, context);
        Fixture memory fixture = _canonicalFixture(cells, context, 1050, 3);
        assertEq(
            _harness.evaluate(fixture.witness, context, fixture.carrier), fixture.expectedEntryRoot
        );
    }

    function test_evaluate_VerifiesTrancheProofBeforeEligibilityFiltering() external {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        cells[0] = _reservedCell(1, 1000, 1050, context);
        cells[0].effectiveL2Slot = 51;
        Fixture memory fixture = _canonicalFixture(cells, context, 1050, 2);
        bytes memory corrupted = _copy(fixture.witness);
        corrupted[fixture.recordsOffset + 41] =
            bytes1(uint8(corrupted[fixture.recordsOffset + 41]) ^ 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSnapshotEvaluatorV1.BuilderTrancheRootMismatch.selector, 0
            )
        );
        _harness.evaluate(corrupted, context, fixture.carrier);
    }

    function test_evaluate_ReparsesExactSliceAndRejectsTrailingOrTruncatedFraming() external {
        CellInput[64] memory cells;
        Fixture memory fixture = _canonicalFixture(cells, _baseContext(7), 1050, 100);

        bytes memory prefixed = bytes.concat(hex"00", fixture.witness);
        vm.expectRevert(LibScheduleSealWitnessV1.InvalidScheduleSealWitnessVersion.selector);
        _harness.evaluate(prefixed, fixture.context, fixture.carrier);

        bytes memory trailing = bytes.concat(fixture.witness, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                LibScheduleSealWitnessV1.InvalidTrancheRecordCardinality.selector, 0, 1
            )
        );
        _harness.evaluate(trailing, fixture.context, fixture.carrier);

        bytes memory truncated = _slice(fixture.witness, 0, fixture.witness.length - 1);
        vm.expectRevert(LibScheduleSealWitnessV1.TruncatedScheduleSealWitness.selector);
        _harness.evaluate(truncated, fixture.context, fixture.carrier);
    }

    function test_evaluate_RejectsInvalidContextBeforeProofTraversal() external {
        CellInput[64] memory cells;
        Fixture memory fixture = _canonicalFixture(cells, _baseContext(7), 1050, 100);
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = fixture.context;
        context.leasePerWindowAtomic = 0;
        vm.expectRevert(LibScheduleSnapshotEvaluatorV1.InvalidScheduleSnapshotContext.selector);
        _harness.evaluate(hex"ff", context, fixture.carrier);

        context = fixture.context;
        context.firstManagedWindow = context.window + 1;
        vm.expectRevert(LibScheduleSnapshotEvaluatorV1.InvalidScheduleSnapshotContext.selector);
        _harness.evaluate(hex"ff", context, fixture.carrier);
    }

    function test_evaluate_Accepts64EligibleBuildersAndReportsGas() external {
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        CellInput[64] memory cells;
        for (uint256 i; i < 64; ++i) {
            cells[i] = _reservedCell(uint64(i), uint192(1000 + (i % 7)), 1050, context);
            cells[i].builder = address(uint160(i + 1));
        }
        Fixture memory fixture = _canonicalFixture(cells, context, 1050, 64);

        uint256 gasBefore = gasleft();
        bytes32 result = _harness.evaluate(fixture.witness, context, fixture.carrier);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("evaluate 64-present/64-eligible gas", gasUsed);
        emit log_named_uint("64-present witness bytes", fixture.witness.length);
        assertEq(result, fixture.expectedEntryRoot);
    }

    function test_evaluate_AcceptsMaximumCanonicalMptPathGeometryAndReportsGas() external {
        Fixture memory fixture = _maximumMptGeometryFixture(false);

        uint256 gasBefore = gasleft();
        bytes32 result = _harness.evaluate(fixture.witness, fixture.context, fixture.carrier);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("evaluate 3x65-node MPT gas", gasUsed);
        emit log_named_uint("3x65-node witness bytes", fixture.witness.length);
        emit log_named_uint(
            "three framed MPT paths bytes", fixture.cellsOffset - fixture.accountSegmentOffset
        );
        assertEq(result, _emptyEntryRootOracle());
    }

    function test_evaluate_ReportsCombined64BuilderMaximumMptGeometryGas() external {
        // Fixture construction intentionally builds 195 large RLP nodes in Solidity. The evaluator
        // call itself is below the L1 block gas limit, but the test transaction needs a raised
        // Foundry gas limit to include that off-chain fixture work.
        if (gasleft() < 200_000_000) return;
        Fixture memory fixture = _maximumMptGeometryFixture(true);

        uint256 gasBefore = gasleft();
        bytes32 result = _harness.evaluate(fixture.witness, fixture.context, fixture.carrier);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("evaluate 64-present plus 3x65-node MPT gas", gasUsed);
        emit log_named_uint("combined maximum witness bytes", fixture.witness.length);
        assertEq(result, fixture.expectedEntryRoot);
    }

    function _canonicalFixture(
        CellInput[64] memory _cells,
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context,
        uint64 _payloadTimestamp,
        uint64 _nextRegistrationIndex
    )
        private
        pure
        returns (Fixture memory fixture_)
    {
        uint8 count = _presentCount(_cells);
        return _build(
            _cells, _context, _payloadTimestamp, _canonicalHeader(count, _nextRegistrationIndex)
        );
    }

    function _maximumMptGeometryFixture(bool _allPresent)
        private
        pure
        returns (Fixture memory fixture_)
    {
        CellInput[64] memory cells;
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context = _baseContext(7);
        if (_allPresent) {
            for (uint256 i; i < 64; ++i) {
                cells[i] = _reservedCell(uint64(i), uint192(1000 + i), 1050, context);
                cells[i].builder = address(uint160(i + 1));
            }
        }
        uint8 count = _allPresent ? 64 : 0;
        HeaderInput memory header = _canonicalHeader(count, _allPresent ? 64 : 100);
        (bytes memory cellBytes, bytes memory records, bytes32 registryRoot) =
            _registryPayload(cells, context);
        bytes32 headerWord = _headerWord(header);
        (bytes memory headerPath, bytes memory rootPath, bytes32 storageRoot) =
            _denseStoragePaths(headerWord, registryRoot);
        (bytes memory accountPath, bytes32 stateRoot) = _denseAccountPath(context, storageRoot);

        fixture_.witness = _denseWitness(accountPath, headerPath, rootPath, cellBytes, records);
        fixture_.context = context;
        fixture_.carrier.payloadTimestamp = 1050;
        fixture_.carrier.stateRoot = stateRoot;
        fixture_.expectedEntryRoot = _expectedEntryRoot(cells, context, 1050);
        fixture_.accountSegmentOffset = 9;
        fixture_.accountSegmentLength = 1 + accountPath.length;
        fixture_.headerSegmentOffset = 9 + 1 + accountPath.length;
        fixture_.headerSegmentLength = 1 + headerPath.length;
        fixture_.rootSegmentOffset = fixture_.headerSegmentOffset + 1 + headerPath.length;
        fixture_.rootSegmentLength = 1 + rootPath.length;
        fixture_.cellsOffset = fixture_.rootSegmentOffset + 1 + rootPath.length;
        fixture_.recordsOffset = fixture_.cellsOffset + 64 * _CELL_BYTES;
    }

    function _denseWitness(
        bytes memory _accountPath,
        bytes memory _headerPath,
        bytes memory _rootPath,
        bytes memory _cellBytesValue,
        bytes memory _records
    )
        private
        pure
        returns (bytes memory witness_)
    {
        bytes memory prefix = bytes.concat(
            hex"01",
            bytes4(uint32(1)),
            hex"aa",
            bytes2(uint16(1)),
            hex"bb",
            bytes1(uint8(65)),
            _accountPath
        );
        witness_ = bytes.concat(
            prefix,
            bytes1(uint8(65)),
            _headerPath,
            bytes1(uint8(65)),
            _rootPath,
            _cellBytesValue,
            _records
        );
    }

    function _denseStoragePaths(
        bytes32 _headerWordValue,
        bytes32 _registryRoot
    )
        private
        pure
        returns (bytes memory headerPath_, bytes memory rootPath_, bytes32 storageRoot_)
    {
        bytes[] memory
            headerTail = _denseTail(_HEADER_KEY, CanonicalTrieFixtures.rlpUint(_headerWordValue), 1);
        bytes[] memory rootTail =
            _denseTail(_ROOT_KEY, CanonicalTrieFixtures.rlpUint(_registryRoot), 1);
        bytes[] memory rootItems = new bytes[](17);
        for (uint256 i; i < 17; ++i) {
            rootItems[i] = hex"80";
        }
        rootItems[3] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(keccak256(headerTail[0])));
        rootItems[0] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(keccak256(rootTail[0])));
        bytes memory rootNode = CanonicalTrieFixtures.rlpList(rootItems);
        storageRoot_ = keccak256(rootNode);
        headerPath_ =
            bytes.concat(CanonicalTrieFixtures.framedNode(rootNode), _frameNodes(headerTail));
        rootPath_ = bytes.concat(CanonicalTrieFixtures.framedNode(rootNode), _frameNodes(rootTail));
    }

    function _denseAccountPath(
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context,
        bytes32 _storageRoot
    )
        private
        pure
        returns (bytes memory path_, bytes32 stateRoot_)
    {
        bytes[] memory fields = new bytes[](4);
        fields[0] = hex"80";
        fields[1] = hex"80";
        fields[2] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(_storageRoot));
        fields[3] =
            CanonicalTrieFixtures.rlpBytes(abi.encodePacked(_context.builderRegistryRuntimeHash));
        bytes memory value = CanonicalTrieFixtures.rlpList(fields);
        bytes32 key = keccak256(abi.encodePacked(_context.builderRegistry));
        bytes[] memory nodes = _denseTail(key, value, 0);
        stateRoot_ = keccak256(nodes[0]);
        path_ = _frameNodes(nodes);
    }

    function _denseTail(
        bytes32 _key,
        bytes memory _value,
        uint256 _firstNibble
    )
        private
        pure
        returns (bytes[] memory nodes_)
    {
        uint256 branchCount = 64 - _firstNibble;
        nodes_ = new bytes[](branchCount + 1);
        nodes_[branchCount] = CanonicalTrieFixtures.leaf(_key, _value, 64, 0);
        bytes memory opaque =
            CanonicalTrieFixtures.rlpBytes(abi.encodePacked(keccak256("dense-opaque-child")));
        for (uint256 reverse = branchCount; reverse != 0; --reverse) {
            uint256 keyIndex = _firstNibble + reverse - 1;
            bytes[] memory items = new bytes[](17);
            for (uint256 i; i < 16; ++i) {
                items[i] = opaque;
            }
            bytes memory child = nodes_[reverse];
            items[CanonicalTrieFixtures.nibble(_key, keyIndex)] = child.length < 32
                ? child
                : CanonicalTrieFixtures.rlpBytes(abi.encodePacked(keccak256(child)));
            items[16] = hex"80";
            nodes_[reverse - 1] = CanonicalTrieFixtures.rlpList(items);
        }
    }

    function _frameNodes(bytes[] memory _nodes) private pure returns (bytes memory framed_) {
        for (uint256 i; i < _nodes.length; ++i) {
            framed_ = bytes.concat(framed_, CanonicalTrieFixtures.framedNode(_nodes[i]));
        }
    }

    function _build(
        CellInput[64] memory _cells,
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context,
        uint64 _payloadTimestamp,
        HeaderInput memory _header
    )
        private
        pure
        returns (Fixture memory fixture_)
    {
        (bytes memory cellBytes, bytes memory records, bytes32 registryRoot) =
            _registryPayload(_cells, _context);
        bytes32 headerWord = _headerWord(_header);
        ProofParts memory proof = _proofParts(_context, headerWord, registryRoot);

        fixture_.witness = bytes.concat(
            hex"01",
            bytes4(uint32(1)),
            hex"aa",
            bytes2(uint16(1)),
            hex"bb",
            bytes1(uint8(1)),
            proof.accountPath,
            bytes1(uint8(2)),
            proof.headerPath,
            bytes1(uint8(2)),
            proof.rootPath,
            cellBytes,
            records
        );
        fixture_.context = _context;
        fixture_.carrier.payloadTimestamp = _payloadTimestamp;
        fixture_.carrier.stateRoot = proof.stateRoot;
        fixture_.expectedEntryRoot = _expectedEntryRoot(_cells, _context, _payloadTimestamp);
        fixture_.accountSegmentOffset = proof.accountSegmentOffset;
        fixture_.accountSegmentLength = 1 + proof.accountPath.length;
        fixture_.headerSegmentOffset = proof.headerSegmentOffset;
        fixture_.headerSegmentLength = 1 + proof.headerPath.length;
        fixture_.rootSegmentOffset = proof.rootSegmentOffset;
        fixture_.rootSegmentLength = 1 + proof.rootPath.length;
        fixture_.cellsOffset = proof.cellsOffset;
        fixture_.recordsOffset = proof.cellsOffset + 64 * _CELL_BYTES;
    }

    function _proofParts(
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context,
        bytes32 _encodedHeader,
        bytes32 _registryRoot
    )
        private
        pure
        returns (ProofParts memory proof_)
    {
        bytes memory headerLeaf =
            CanonicalTrieFixtures.storageLeaf(_HEADER_KEY, _encodedHeader, 1, 63);
        bytes memory rootLeaf = CanonicalTrieFixtures.storageLeaf(_ROOT_KEY, _registryRoot, 1, 63);
        bytes[] memory branchItems = new bytes[](17);
        for (uint256 i; i < 17; ++i) {
            branchItems[i] = hex"80";
        }
        branchItems[3] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(keccak256(headerLeaf)));
        branchItems[0] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(keccak256(rootLeaf)));
        bytes memory storageBranch = CanonicalTrieFixtures.rlpList(branchItems);
        bytes32 storageRoot = keccak256(storageBranch);
        proof_.headerPath = bytes.concat(
            CanonicalTrieFixtures.framedNode(storageBranch),
            CanonicalTrieFixtures.framedNode(headerLeaf)
        );
        proof_.rootPath = bytes.concat(
            CanonicalTrieFixtures.framedNode(storageBranch),
            CanonicalTrieFixtures.framedNode(rootLeaf)
        );

        bytes[] memory accountFields = new bytes[](4);
        accountFields[0] = hex"80";
        accountFields[1] = hex"80";
        accountFields[2] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(storageRoot));
        accountFields[3] =
            CanonicalTrieFixtures.rlpBytes(abi.encodePacked(_context.builderRegistryRuntimeHash));
        bytes memory accountValue = CanonicalTrieFixtures.rlpList(accountFields);
        bytes32 accountKey = keccak256(abi.encodePacked(_context.builderRegistry));
        bytes memory accountLeaf = CanonicalTrieFixtures.leaf(accountKey, accountValue, 0, 64);
        proof_.accountPath = CanonicalTrieFixtures.framedNode(accountLeaf);
        proof_.stateRoot = keccak256(accountLeaf);

        proof_.accountSegmentOffset = 9;
        proof_.headerSegmentOffset = proof_.accountSegmentOffset + 1 + proof_.accountPath.length;
        proof_.rootSegmentOffset = proof_.headerSegmentOffset + 1 + proof_.headerPath.length;
        proof_.cellsOffset = proof_.rootSegmentOffset + 1 + proof_.rootPath.length;
    }

    function _registryPayload(
        CellInput[64] memory _cells,
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context
    )
        private
        pure
        returns (bytes memory cellBytes_, bytes memory records_, bytes32 registryRoot_)
    {
        uint8 count = _presentCount(_cells);
        cellBytes_ = new bytes(64 * _CELL_BYTES);
        records_ = new bytes(uint256(count) * _RECORD_BYTES);
        bytes32[64] memory leaves;
        uint256 ordinal;
        for (uint256 i; i < 64; ++i) {
            if (!_cells[i].present) {
                leaves[i] = _registryLeaf(uint8(i), false, _cells[i], bytes32(0));
                continue;
            }
            (bytes memory record, bytes32 trancheRoot,) =
                _trancheRecord(_cells[i], uint8(i), _context);
            _writeCell(cellBytes_, i * _CELL_BYTES, _cells[i], trancheRoot);
            _writeBytes(records_, ordinal * _RECORD_BYTES, record);
            leaves[i] = _registryLeaf(uint8(i), true, _cells[i], trancheRoot);
            ++ordinal;
        }
        registryRoot_ = _foldRegistry(leaves);
    }

    function _trancheRecord(
        CellInput memory _cell,
        uint8 _cellIndex,
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context
    )
        private
        pure
        returns (bytes memory record_, bytes32 root_, bytes32 leafHash_)
    {
        uint16 index = uint16(uint256(_context.window) & 511);
        leafHash_ = keccak256(
            abi.encodePacked(
                "slot-chain-tranche-leaf-v1",
                index,
                _cell.trancheWindow,
                _cell.trancheState,
                _cell.trancheAmount,
                _cell.liableUntil
            )
        );
        record_ = new bytes(_RECORD_BYTES);
        _writeU64(record_, 0, _cell.trancheWindow);
        record_[8] = bytes1(_cell.trancheState);
        _writeU192(record_, 9, _cell.trancheAmount);
        _writeU64(record_, 33, _cell.liableUntil);
        root_ = leafHash_;
        for (uint8 height; height < 9; ++height) {
            bytes32 sibling =
                keccak256(abi.encodePacked("snapshot-test-sibling", _cellIndex, height));
            _writeBytes32(record_, 41 + uint256(height) * 32, sibling);
            root_ = ((index >> height) & 1) == 1
                ? keccak256(abi.encodePacked("slot-chain-tranche-node-v1", height, sibling, root_))
                : keccak256(abi.encodePacked("slot-chain-tranche-node-v1", height, root_, sibling));
        }
    }

    function _expectedEntryRoot(
        CellInput[64] memory _cells,
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context,
        uint64 _payloadTimestamp
    )
        private
        pure
        returns (bytes32 root_)
    {
        uint64 source = _payloadTimestamp >= _context.genesisTimestamp
            ? _payloadTimestamp - _context.genesisTimestamp
            : 0;
        uint8[64] memory order;
        uint8 count;
        for (uint8 i; i < 64; ++i) {
            CellInput memory cell = _cells[i];
            if (
                !cell.present || cell.trancheWindow != _context.window || cell.trancheState != 2
                    || cell.effectiveL2Slot > source || cell.tombstonedAtL2Slot <= source
            ) continue;
            uint256 position = count;
            while (position != 0 && _cellPrecedes(cell, _cells[order[position - 1]])) {
                order[position] = order[position - 1];
                --position;
            }
            order[position] = i;
            ++count;
        }
        return _entryRootForOrder(_cells, _context, order, count);
    }

    function _entryRootForOrder(
        CellInput[64] memory _cells,
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context,
        uint8[64] memory _order,
        uint8 _count
    )
        private
        pure
        returns (bytes32 root_)
    {
        bytes32[64] memory leaves;
        for (uint8 rank; rank < 64; ++rank) {
            if (rank < _count) {
                CellInput memory cell = _cells[_order[rank]];
                (,, bytes32 trancheLeafHash) = _trancheRecord(cell, _order[rank], _context);
                leaves[rank] = _entryLeaf(rank, true, cell, trancheLeafHash);
            } else {
                CellInput memory empty;
                leaves[rank] = _entryLeaf(rank, false, empty, bytes32(0));
            }
        }
        return _foldEntry(leaves);
    }

    function _registryLeaf(
        uint8 _index,
        bool _present,
        CellInput memory _cell,
        bytes32 _trancheRoot
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "slot-chain-registry-leaf-v1",
                _index,
                _present ? uint8(1) : uint8(0),
                _present ? _cell.builder : address(0),
                _present ? _cell.bond : uint192(0),
                _present ? _cell.registrationIndex : uint64(0),
                _present ? _cell.effectiveL2Slot : uint64(0),
                _present ? _trancheRoot : bytes32(0),
                _present ? _cell.tombstonedAtL2Slot : uint64(0)
            )
        );
    }

    function _entryLeaf(
        uint8 _rank,
        bool _present,
        CellInput memory _cell,
        bytes32 _trancheLeafHash
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "slot-chain-entry-leaf-v1",
                _rank,
                _present ? uint8(1) : uint8(0),
                _present ? _cell.builder : address(0),
                _present ? _cell.bond : uint192(0),
                _present ? _cell.registrationIndex : uint64(0),
                _present ? _cell.effectiveL2Slot : uint64(0),
                _present ? _cell.tombstonedAtL2Slot : uint64(0),
                _present ? _trancheLeafHash : bytes32(0)
            )
        );
    }

    function _foldRegistry(bytes32[64] memory _nodes) private pure returns (bytes32) {
        uint256 width = 64;
        for (uint8 height; height < 6; ++height) {
            for (uint256 i; i < width; i += 2) {
                _nodes[i / 2] = keccak256(
                    abi.encodePacked(
                        "slot-chain-registry-node-v1", height, _nodes[i], _nodes[i + 1]
                    )
                );
            }
            width >>= 1;
        }
        return _nodes[0];
    }

    function _foldEntry(bytes32[64] memory _nodes) private pure returns (bytes32) {
        uint256 width = 64;
        for (uint8 height; height < 6; ++height) {
            for (uint256 i; i < width; i += 2) {
                _nodes[i / 2] = keccak256(
                    abi.encodePacked("slot-chain-entry-node-v1", height, _nodes[i], _nodes[i + 1])
                );
            }
            width >>= 1;
        }
        return _nodes[0];
    }

    function _emptyEntryRootOracle() private pure returns (bytes32) {
        CellInput memory empty;
        bytes32[64] memory leaves;
        for (uint8 rank; rank < 64; ++rank) {
            leaves[rank] = _entryLeaf(rank, false, empty, bytes32(0));
        }
        return _foldEntry(leaves);
    }

    function _baseContext(uint64 _window)
        private
        pure
        returns (LibScheduleSnapshotEvaluatorV1.SnapshotContext memory context_)
    {
        context_.builderRegistry = address(0xB01D);
        context_.builderRegistryRuntimeHash = keccak256("builder-registry-runtime-v1");
        context_.window = _window;
        context_.genesisTimestamp = 1000;
        context_.firstManagedWindow = 0;
        context_.lastManagedWindow = type(uint64).max;
        context_.evidenceDelaySeconds = 100;
        context_.reorgMarginSeconds = 20;
        context_.leasePerWindowAtomic = 100;
    }

    function _reservedCell(
        uint64 _registrationIndex,
        uint192 _bond,
        uint64,
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context
    )
        private
        pure
        returns (CellInput memory cell_)
    {
        cell_.present = true;
        cell_.builder = address(uint160(0x1000 + _registrationIndex));
        cell_.bond = _bond;
        cell_.registrationIndex = _registrationIndex;
        cell_.effectiveL2Slot = 0;
        cell_.tombstonedAtL2Slot = _LIVE;
        cell_.trancheWindow = _context.window;
        cell_.trancheState = 2;
        cell_.trancheAmount = _context.leasePerWindowAtomic;
        cell_.liableUntil = _deadline(_context, _context.window);
    }

    function _cellForState(
        uint8 _state,
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context
    )
        private
        pure
        returns (CellInput memory cell_)
    {
        cell_ = _reservedCell(1, 1000, 1050, _context);
        cell_.trancheState = _state;
        if (_state == 0) {
            cell_.trancheWindow = _LIVE;
            cell_.trancheAmount = 0;
            cell_.liableUntil = 0;
        } else if (_state == 1) {
            cell_.trancheAmount = 0;
            cell_.liableUntil = 0;
        } else if (_state >= 4) {
            cell_.trancheAmount = 0;
        }
    }

    function _deadline(
        LibScheduleSnapshotEvaluatorV1.SnapshotContext memory _context,
        uint64 _window
    )
        private
        pure
        returns (uint64)
    {
        return uint64(
            uint256(_context.genesisTimestamp) + 384 * (uint256(_window) + 1)
                + _context.evidenceDelaySeconds + _context.reorgMarginSeconds
        );
    }

    function _canonicalHeader(
        uint8 _count,
        uint64 _next
    )
        private
        pure
        returns (HeaderInput memory header_)
    {
        header_.magic = _HEADER_MAGIC;
        header_.version = 1;
        header_.activeCount = _count;
        header_.registryMutationVersion = 0x0102030405060708;
        header_.admissionVersion = 0x1112131415161718;
        header_.nextRegistrationIndex = _next;
    }

    function _headerWord(HeaderInput memory _header) private pure returns (bytes32 word_) {
        bytes memory encoded = abi.encodePacked(
            _header.magic,
            _header.version,
            _header.activeCount,
            _header.reserved,
            _header.registryMutationVersion,
            _header.admissionVersion,
            _header.nextRegistrationIndex
        );
        assembly ("memory-safe") {
            word_ := mload(add(encoded, 32))
        }
    }

    function _writeCell(
        bytes memory _output,
        uint256 _offset,
        CellInput memory _cell,
        bytes32 _trancheRoot
    )
        private
        pure
    {
        _output[_offset] = 0x01;
        _writeAddress(_output, _offset + 1, _cell.builder);
        _writeU192(_output, _offset + 21, _cell.bond);
        _writeU64(_output, _offset + 45, _cell.registrationIndex);
        _writeU64(_output, _offset + 53, _cell.effectiveL2Slot);
        _writeBytes32(_output, _offset + 61, _trancheRoot);
        _writeU64(_output, _offset + 93, _cell.tombstonedAtL2Slot);
    }

    function _writeAddress(
        bytes memory _output,
        uint256 _offset,
        address _value
    )
        private
        pure
    {
        uint160 value = uint160(_value);
        for (uint256 i; i < 20; ++i) {
            _output[_offset + i] = bytes1(uint8(value >> ((19 - i) * 8)));
        }
    }

    function _writeU64(bytes memory _output, uint256 _offset, uint64 _value) private pure {
        for (uint256 i; i < 8; ++i) {
            _output[_offset + i] = bytes1(uint8(_value >> ((7 - i) * 8)));
        }
    }

    function _writeU192(
        bytes memory _output,
        uint256 _offset,
        uint192 _value
    )
        private
        pure
    {
        for (uint256 i; i < 24; ++i) {
            _output[_offset + i] = bytes1(uint8(_value >> ((23 - i) * 8)));
        }
    }

    function _writeBytes32(
        bytes memory _output,
        uint256 _offset,
        bytes32 _value
    )
        private
        pure
    {
        for (uint256 i; i < 32; ++i) {
            _output[_offset + i] = _value[i];
        }
    }

    function _writeBytes(
        bytes memory _output,
        uint256 _offset,
        bytes memory _value
    )
        private
        pure
    {
        for (uint256 i; i < _value.length; ++i) {
            _output[_offset + i] = _value[i];
        }
    }

    function _presentCount(CellInput[64] memory _cells) private pure returns (uint8 count_) {
        for (uint256 i; i < 64; ++i) {
            if (_cells[i].present) ++count_;
        }
    }

    function _cellPrecedes(
        CellInput memory _left,
        CellInput memory _right
    )
        private
        pure
        returns (bool)
    {
        return _left.bond > _right.bond
            || (_left.bond == _right.bond && _left.registrationIndex < _right.registrationIndex);
    }

    function _expectInvalidHeader(Fixture memory _fixture) private {
        vm.expectRevert(LibScheduleSnapshotEvaluatorV1.InvalidBuilderRegistryHeader.selector);
        _harness.evaluate(_fixture.witness, _fixture.context, _fixture.carrier);
    }

    function _expectInvalidTranche(Fixture memory _fixture) private {
        vm.expectRevert(
            abi.encodeWithSelector(LibScheduleSnapshotEvaluatorV1.InvalidBuilderTranche.selector, 0)
        );
        _harness.evaluate(_fixture.witness, _fixture.context, _fixture.carrier);
    }

    function _swapEqualSegments(
        bytes memory _buffer,
        uint256 _a,
        uint256 _b,
        uint256 _length
    )
        private
        pure
    {
        for (uint256 i; i < _length; ++i) {
            bytes1 tmp = _buffer[_a + i];
            _buffer[_a + i] = _buffer[_b + i];
            _buffer[_b + i] = tmp;
        }
    }

    function _copy(bytes memory _input) private pure returns (bytes memory output_) {
        return _slice(_input, 0, _input.length);
    }

    function _slice(
        bytes memory _input,
        uint256 _start,
        uint256 _end
    )
        private
        pure
        returns (bytes memory output_)
    {
        output_ = new bytes(_end - _start);
        for (uint256 i; i < output_.length; ++i) {
            output_[i] = _input[_start + i];
        }
    }
}
