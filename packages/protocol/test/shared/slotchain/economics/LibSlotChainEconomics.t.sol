// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    LibSlotChainEconomics
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainEconomics.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { stdError } from "forge-std/src/StdError.sol";
import { Test } from "forge-std/src/Test.sol";

contract LibSlotChainEconomicsTest is Test {
    EconomicsHarness private harness;

    function setUp() external {
        harness = new EconomicsHarness();
    }

    function test_ceilDiv_HandlesZeroAndMaximumNumerator() external pure {
        assertEq(LibSlotChainEconomics.ceilDiv(0, type(uint256).max), 0);
        assertEq(LibSlotChainEconomics.ceilDiv(type(uint256).max, 1), type(uint256).max);
        assertEq(LibSlotChainEconomics.ceilDiv(type(uint256).max, 2), type(uint256).max / 2 + 1);
    }

    function test_ceilDiv_RevertWhen_DivisorIsZero() external {
        vm.expectRevert(LibSlotChainEconomics.DivisionByZero.selector);
        harness.ceilDiv(1, 0);
    }

    function test_mulDivDown_ComputesFullPrecisionProduct() external pure {
        uint256 maximum = type(uint256).max;
        assertEq(LibSlotChainEconomics.mulDivDown(maximum, maximum, maximum), maximum);
        assertEq(LibSlotChainEconomics.mulDivDown(1 << 200, 1 << 100, 1 << 128), 1 << 172);
        assertEq(
            LibSlotChainEconomics.mulDivDown((1 << 200) + 123, (1 << 100) + 321, (1 << 128) + 1),
            0x10000000000000000000000140fffffff00000000000
        );
    }

    function test_mulDivDown_RevertWhen_ResultOverflows() external {
        vm.expectRevert(LibSlotChainEconomics.MulDivOverflow.selector);
        harness.mulDivDown(type(uint256).max, type(uint256).max, type(uint256).max - 1);
    }

    function test_mulDivDown_RevertWhen_DivisorIsZero() external {
        vm.expectRevert(LibSlotChainEconomics.DivisionByZero.selector);
        harness.mulDivDown(1, 1, 0);
    }

    function test_mulDivUp_RoundsOnlyNonintegralProduct() external pure {
        assertEq(LibSlotChainEconomics.mulDivUp(5, 4, 2), 10);
        assertEq(LibSlotChainEconomics.mulDivUp(5, 4, 3), 7);
        assertEq(LibSlotChainEconomics.mulDivUp(0, type(uint256).max, 7), 0);
        assertEq(
            LibSlotChainEconomics.mulDivUp(type(uint256).max, type(uint256).max, type(uint256).max),
            type(uint256).max
        );
    }

    function test_mulDivUp_RevertWhen_CeilingOverflows() external {
        uint256 denominator = 1 << 255;
        assertEq(
            LibSlotChainEconomics.mulDivDown(type(uint256).max - 1, denominator + 1, denominator),
            type(uint256).max
        );
        vm.expectRevert(LibSlotChainEconomics.MulDivOverflow.selector);
        harness.mulDivUp(type(uint256).max - 1, denominator + 1, denominator);
    }

    function testFuzz_mulDiv_MatchesBoundedReference(
        uint128 _a,
        uint128 _b,
        uint128 _d
    )
        external
        pure
    {
        uint256 denominator = uint256(_d) + 1;
        uint256 product = uint256(_a) * uint256(_b);
        assertEq(LibSlotChainEconomics.mulDivDown(_a, _b, denominator), product / denominator);
        uint256 expectedUp = product / denominator + (product % denominator == 0 ? 0 : 1);
        assertEq(LibSlotChainEconomics.mulDivUp(_a, _b, denominator), expectedUp);
    }

    function testFuzz_mulDiv_MatchesIndependentFullWidthReference(
        uint256 _a,
        uint256 _b,
        uint256 _denominator
    )
        external
        pure
    {
        uint256 productHigh;
        assembly ("memory-safe") {
            let mm := mulmod(_a, _b, not(0))
            let productLow := mul(_a, _b)
            productHigh := sub(sub(mm, productLow), lt(mm, productLow))
        }
        vm.assume(_denominator > productHigh);

        uint256 expectedDown = Math.mulDiv(_a, _b, _denominator);
        assertEq(LibSlotChainEconomics.mulDivDown(_a, _b, _denominator), expectedDown);

        uint256 remainder = mulmod(_a, _b, _denominator);
        vm.assume(expectedDown != type(uint256).max || remainder == 0);
        uint256 expectedUp = Math.mulDiv(_a, _b, _denominator, Math.Rounding.Up);
        assertEq(LibSlotChainEconomics.mulDivUp(_a, _b, _denominator), expectedUp);
    }

    function test_dataSessionPostRent_UsesExactUpwardBlobRounding() external pure {
        assertEq(LibSlotChainEconomics.dataSessionPostRent(0, 1, 0, 1, 1), 14);
        assertEq(LibSlotChainEconomics.dataSessionPostRent(9, 1, 3, 0, 1), 27);
        assertEq(
            LibSlotChainEconomics.dataSessionPostRent(2, 6, 7, 10_000, 11), 14 + 6 * 131_072 * 11
        );
    }

    function test_dataSessionPostRent_RevertWhen_BpsIsAboveMaximum() external {
        vm.expectRevert(LibSlotChainEconomics.InvalidBps.selector);
        harness.dataSessionPostRent(0, 1, 0, 10_001, 1);
    }

    function test_dataSessionPostRent_RevertWhen_IntermediateOverflows() external {
        vm.expectRevert(stdError.arithmeticError);
        harness.dataSessionPostRent(type(uint256).max, 1, 2, 0, 0);

        vm.expectRevert(stdError.arithmeticError);
        harness.dataSessionPostRent(0, type(uint256).max, 0, 1, 0);
    }

    function test_dataSessionOpenPayment_IsExactAndChecked() external {
        assertEq(LibSlotChainEconomics.dataSessionOpenPayment(7, 11), 18);
        vm.expectRevert(stdError.arithmeticError);
        harness.dataSessionOpenPayment(type(uint256).max, 1);
    }

    function test_forcedEnvelopeDeposit_UsesExactCheckedSchedule() external pure {
        assertEq(LibSlotChainEconomics.forcedEnvelopeDeposit(10, 5, 2, 3, 4, 7, 63), 63);
        assertEq(LibSlotChainEconomics.forcedEnvelopeDeposit(0, 0, 0, 0, 0, 0, 0), 0);
    }

    function test_forcedEnvelopeDeposit_RevertWhen_DepositExceedsCap() external {
        vm.expectRevert(
            abi.encodeWithSelector(LibSlotChainEconomics.FeeCapExceeded.selector, 63, 62)
        );
        harness.forcedEnvelopeDeposit(10, 5, 2, 3, 4, 7, 62);
    }

    function test_forcedEnvelopeDeposit_RevertWhen_ArithmeticOverflows() external {
        vm.expectRevert(stdError.arithmeticError);
        harness.forcedEnvelopeDeposit(0, 1, type(uint256).max, 1, 0, 0, type(uint256).max);

        vm.expectRevert(stdError.arithmeticError);
        harness.forcedEnvelopeDeposit(0, 2, type(uint256).max, 0, 0, 0, type(uint256).max);

        vm.expectRevert(stdError.arithmeticError);
        harness.forcedEnvelopeDeposit(0, 0, 0, 0, 2, type(uint256).max, type(uint256).max);
    }

    function test_seatPremiumProducts_UseCheckedMonotonicDurations() external {
        assertEq(LibSlotChainEconomics.seatPremiumReserve(7, 11), 77);
        assertEq(LibSlotChainEconomics.seatPremiumAccrual(7, 10, 21), 77);
        assertEq(LibSlotChainEconomics.seatPremiumAccrual(type(uint256).max, 10, 10), 0);

        vm.expectRevert(LibSlotChainEconomics.InvalidTimeRange.selector);
        harness.seatPremiumAccrual(1, 11, 10);

        vm.expectRevert(stdError.arithmeticError);
        harness.seatPremiumReserve(type(uint256).max, 2);
    }

    function test_rewardAmount_CapsWithoutOverflowingProducts() external pure {
        assertEq(LibSlotChainEconomics.rewardAmount(3, 5, 7, 11, 13, 1000), 181);
        assertEq(
            LibSlotChainEconomics.rewardAmount(
                1, type(uint256).max, type(uint256).max, type(uint256).max, type(uint256).max, 10
            ),
            10
        );
        assertEq(LibSlotChainEconomics.rewardAmount(100, 1, 1, 1, 1, 50), 50);
        assertEq(LibSlotChainEconomics.rewardAmount(0, 0, 0, 0, 0, 0), 0);
    }

    function test_reporterRewardSplit_HandlesZeroCapAndSlashBoundary() external pure {
        (uint256 reporter, uint256 penalty) = LibSlotChainEconomics.reporterRewardSplit(100, 30);
        assertEq(reporter, 30);
        assertEq(penalty, 70);

        (reporter, penalty) = LibSlotChainEconomics.reporterRewardSplit(30, 100);
        assertEq(reporter, 30);
        assertEq(penalty, 0);

        (reporter, penalty) = LibSlotChainEconomics.reporterRewardSplit(0, 0);
        assertEq(reporter, 0);
        assertEq(penalty, 0);
    }

    function test_requiredAskImprovement_PreservesZeroAskReplacement() external pure {
        assertEq(LibSlotChainEconomics.requiredAskImprovement(10, 100, 100), 10);
        assertTrue(LibSlotChainEconomics.improvesAsk(10, 0, 100, 100));
        assertFalse(LibSlotChainEconomics.improvesAsk(10, 1, 100, 100));
        assertFalse(LibSlotChainEconomics.improvesAsk(0, 0, 1, 100));
    }

    function test_requiredAskImprovement_RoundsRelativeFloorUp() external pure {
        assertEq(LibSlotChainEconomics.requiredAskImprovement(101, 0, 100), 2);
        assertTrue(LibSlotChainEconomics.improvesAsk(101, 99, 0, 100));
        assertFalse(LibSlotChainEconomics.improvesAsk(101, 100, 0, 100));
    }

    function test_requiredAskImprovement_RevertWhen_BpsIsAboveMaximum() external {
        vm.expectRevert(LibSlotChainEconomics.InvalidBps.selector);
        harness.requiredAskImprovement(1, 1, 10_001);

        vm.expectRevert(LibSlotChainEconomics.InvalidBps.selector);
        harness.improvesAsk(0, 0, 1, 10_001);
    }

    function test_saturatingAdd64_HandlesExactAndOverflowBoundaries() external pure {
        assertEq(LibSlotChainEconomics.saturatingAdd64(type(uint64).max - 1, 1), type(uint64).max);
        assertEq(LibSlotChainEconomics.saturatingAdd64(type(uint64).max - 1, 2), type(uint64).max);
        assertEq(LibSlotChainEconomics.saturatingAdd64(0, 0), 0);
    }

    function test_toUint64_HandlesExactBoundaryAndRejectsOnePast() external {
        assertEq(LibSlotChainEconomics.toUint64(type(uint64).max), type(uint64).max);
        vm.expectRevert(LibSlotChainEconomics.Uint64Overflow.selector);
        harness.toUint64(uint256(type(uint64).max) + 1);
    }
}

contract EconomicsHarness {
    function ceilDiv(uint256 _a, uint256 _b) external pure returns (uint256) {
        return LibSlotChainEconomics.ceilDiv(_a, _b);
    }

    function mulDivDown(uint256 _a, uint256 _b, uint256 _d) external pure returns (uint256) {
        return LibSlotChainEconomics.mulDivDown(_a, _b, _d);
    }

    function mulDivUp(uint256 _a, uint256 _b, uint256 _d) external pure returns (uint256) {
        return LibSlotChainEconomics.mulDivUp(_a, _b, _d);
    }

    function dataSessionPostRent(
        uint256 _bytes,
        uint256 _blobs,
        uint256 _rate,
        uint256 _bps,
        uint256 _baseFee
    )
        external
        pure
        returns (uint256)
    {
        return LibSlotChainEconomics.dataSessionPostRent(_bytes, _blobs, _rate, _bps, _baseFee);
    }

    function dataSessionOpenPayment(
        uint256 _bond,
        uint256 _rent
    )
        external
        pure
        returns (uint256)
    {
        return LibSlotChainEconomics.dataSessionOpenPayment(_bond, _rent);
    }

    function forcedEnvelopeDeposit(
        uint256 _fixed,
        uint256 _gas,
        uint256 _executionRate,
        uint256 _proofRate,
        uint256 _bytes,
        uint256 _byteRate,
        uint256 _cap
    )
        external
        pure
        returns (uint256)
    {
        return LibSlotChainEconomics.forcedEnvelopeDeposit(
            _fixed, _gas, _executionRate, _proofRate, _bytes, _byteRate, _cap
        );
    }

    function seatPremiumReserve(
        uint256 _ask,
        uint256 _duration
    )
        external
        pure
        returns (uint256)
    {
        return LibSlotChainEconomics.seatPremiumReserve(_ask, _duration);
    }

    function seatPremiumAccrual(
        uint256 _ask,
        uint64 _from,
        uint64 _to
    )
        external
        pure
        returns (uint256)
    {
        return LibSlotChainEconomics.seatPremiumAccrual(_ask, _from, _to);
    }

    function requiredAskImprovement(
        uint256 _ask,
        uint256 _absolute,
        uint256 _bps
    )
        external
        pure
        returns (uint256)
    {
        return LibSlotChainEconomics.requiredAskImprovement(_ask, _absolute, _bps);
    }

    function improvesAsk(
        uint256 _ask,
        uint256 _candidate,
        uint256 _absolute,
        uint256 _bps
    )
        external
        pure
        returns (bool)
    {
        return LibSlotChainEconomics.improvesAsk(_ask, _candidate, _absolute, _bps);
    }

    function toUint64(uint256 _value) external pure returns (uint64) {
        return LibSlotChainEconomics.toUint64(_value);
    }
}
