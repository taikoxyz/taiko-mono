// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { StringsUpgradeable as Strings } from
    "@ozu/utils/StringsUpgradeable.sol";
import { console2 } from "forge-std/console2.sol";
import { TestBase } from "../TestBase.sol";
import { Lib1559Math } from "../../contracts/L2/Lib1559Math.sol";
import { Lib1559MathTestData as Data } from "./Lib1559MathTest.d.sol";

contract Lib1559MathTest is TestBase {
    uint256 public constant __constAvgBlockTime = 3;
    uint256 public constant __blockGasTarget = 4_300_000; // 4.3 million
    uint256 public constant __bfpg = 10 * 1_000_000_000; // 10 Gwei
    uint256 public constant __gasInPool = __blockGasTarget * 1000;
    uint256 public constant __poolProduct = __bfpg * __gasInPool * __gasInPool;
    uint256 public constant __gasIssuePerSecond =
        __blockGasTarget / __constAvgBlockTime;

    function test_1559() public view {
        uint256 baseFeePerGasVanilla = __bfpg;
        uint256 gasInPool = __gasInPool;
        uint256 maxGasInPool = type(uint256).max; // __gasInPool * 100000;

        uint256 time;

        console2.log(
            "time, delay, gasUsed, gasInPool, baseFeePerGasAMM, baseFeePerGasVanilla"
        );

        uint32[2][] memory blocks = Data.blocks();

        for (uint256 i; i < blocks.length; i++) {
            uint256 delay = _regtime(time + blocks[i][0]) - _regtime(time);
            time += blocks[i][0];

            baseFeePerGasVanilla = Lib1559Math.calcBaseFeePerGas(
                baseFeePerGasVanilla, blocks[i][1], __blockGasTarget
            );

            uint256 baseFeePerGasAMM;
            (baseFeePerGasAMM, gasInPool) = Lib1559Math.calcBaseFeePerGasAMM(
                __poolProduct,
                __gasIssuePerSecond,
                maxGasInPool,
                gasInPool,
                delay,
                blocks[i][1]
            );

            _print(
                time,
                delay,
                blocks[i][1],
                baseFeePerGasVanilla,
                baseFeePerGasAMM,
                gasInPool
            );
        }
    }

    function _print(
        uint256 time,
        uint256 delay,
        uint256 gasUsed,
        uint256 baseFeePerGasVanilla,
        uint256 baseFeePerGasAMM,
        uint256 gasInPool
    )
        private
        view
    {
        string memory str = string.concat(
            Strings.toString(_regtime(time)),
            ", ",
            Strings.toString(delay),
            ", ",
            Strings.toString(gasUsed),
            ", ",
            Strings.toString(gasInPool),
            ", ",
            Strings.toString(baseFeePerGasAMM),
            ", ",
            Strings.toString(baseFeePerGasVanilla),
            ""
        );

        console2.log(str);
    }

    function _regtime(uint256 time) private pure returns (uint256) {
        return (1 + time / 12) * 12;
    }
}
