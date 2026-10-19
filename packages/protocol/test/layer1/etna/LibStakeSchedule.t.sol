// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/src/Test.sol";
import { LibStakeSchedule } from "src/layer1/etna/libs/LibStakeSchedule.sol";

contract StakeScheduleHarness {
    using LibStakeSchedule for LibStakeSchedule.Tree;
    LibStakeSchedule.Tree internal _tree;

    function add(uint64 _block, uint256 _amount) external {
        _tree.add(_block, _amount);
    }

    function remove(uint64 _block, uint256 _amount) external {
        _tree.remove(_block, _amount);
    }

    function prefix(uint64 _block) external view returns (uint256) {
        return _tree.prefix(_block);
    }
}

contract LibStakeScheduleTest is Test {
    StakeScheduleHarness internal tree = new StakeScheduleHarness();

    function test_schedule_FullWidthAndEndpointRoundTrip() external {
        uint256 amount = uint256(1) << 255;
        tree.add(0, amount);
        tree.add(type(uint64).max, amount - 1);
        assertEq(tree.prefix(0), amount);
        assertEq(tree.prefix(type(uint64).max - 1), amount);
        assertEq(tree.prefix(type(uint64).max), type(uint256).max);
        tree.remove(0, amount);
        assertEq(tree.prefix(type(uint64).max - 1), 0);
        tree.remove(type(uint64).max, amount - 1);
        assertEq(tree.prefix(type(uint64).max), 0);
    }

    function test_schedule_IndexBoundariesAndNaivePrefixes() external {
        uint64[] memory coordinates = new uint64[](194);
        coordinates[0] = 0;
        coordinates[1] = type(uint64).max;
        for (uint256 bit; bit < 64; ++bit) {
            uint64 power = uint64(uint256(1) << bit);
            coordinates[2 + bit * 3] = power - 1;
            coordinates[3 + bit * 3] = power;
            coordinates[4 + bit * 3] = power + 1;
        }
        for (uint256 i; i < coordinates.length; ++i) {
            tree.add(coordinates[i], i + 1);
        }
        for (uint256 i; i < coordinates.length; ++i) {
            uint256 expected;
            for (uint256 j; j < coordinates.length; ++j) {
                if (coordinates[j] <= coordinates[i]) expected += j + 1;
            }
            assertEq(tree.prefix(coordinates[i]), expected);
        }
        // Reverse cancellation also covers shared paths and same-coordinate aggregation.
        for (uint256 i = coordinates.length; i != 0; --i) {
            tree.remove(coordinates[i - 1], i);
        }
        for (uint256 i; i < coordinates.length; ++i) {
            assertEq(tree.prefix(coordinates[i]), 0);
        }
    }

    function test_schedule_ExactStorageAccessBounds() external {
        vm.record();
        tree.add(0, 1);
        (, bytes32[] memory writes) = vm.accesses(address(tree));
        assertEq(writes.length, 65, "block zero updates 65 unique cells");
        vm.record();
        tree.prefix(type(uint64).max - 1);
        (bytes32[] memory reads,) = vm.accesses(address(tree));
        assertEq(reads.length, 64, "maximum inclusive prefix reads 64 cells");
        vm.record();
        tree.prefix(type(uint64).max);
        (reads,) = vm.accesses(address(tree));
        assertEq(reads.length, 1, "endpoint reads the root without wrapping");
    }

    function testFuzz_schedule_IndependentEventSum(
        uint64 _a,
        uint64 _b,
        uint64 _q,
        uint128 _amount
    )
        external
    {
        tree.add(_a, _amount);
        tree.add(_b, uint256(_amount) + 1);
        uint256 expected = (_a <= _q ? uint256(_amount) : 0) + (_b <= _q ? uint256(_amount) + 1 : 0);
        assertEq(tree.prefix(_q), expected);
        tree.remove(_a, _amount);
        assertEq(tree.prefix(_q), _b <= _q ? uint256(_amount) + 1 : 0);
    }
}
