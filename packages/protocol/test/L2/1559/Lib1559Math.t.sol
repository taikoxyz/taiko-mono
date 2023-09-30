// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { StringsUpgradeable as Strings } from
    "@ozu/utils/StringsUpgradeable.sol";
import { console2 } from "forge-std/console2.sol";

import { Lib1559Math } from "../../../contracts/L2/1559/Lib1559Math.sol";
import { TestBase } from "../../TestBase.sol";
import { Lib1559MathTestData as Data } from "./Lib1559MathTest.d.sol";

contract Lib1559MathTest is TestBase {
    // WARNING:
    // AVG_BLOCK_TIME and BLOCK_GAS_TARGET should match the values in
    // blocktime_gasused_gen.py
    uint256 public constant AVG_BLOCK_TIME = 3;
    uint256 public constant BLOCK_GAS_TARGET = 4_300_000; // 4.3 million

    uint256 public constant INIT_BASEFEE_PER_GAS = 10 * 1_000_000_000; // 10
        // Gwei
    uint256 public constant INIT_GAS_IN_POOL = BLOCK_GAS_TARGET * 1000;
    uint256 public constant POOL_AMM_PRODUCT =
        INIT_BASEFEE_PER_GAS * INIT_GAS_IN_POOL * INIT_GAS_IN_POOL;
    uint256 public constant GAS_ISSUE_PER_SECOND =
        BLOCK_GAS_TARGET / AVG_BLOCK_TIME;

    function test_1559() public view {
        uint256 baseFeePerGasVanilla = INIT_BASEFEE_PER_GAS;
        uint256 gasInPool = INIT_GAS_IN_POOL;
        uint256 maxGasInPool = type(uint256).max; // INIT_GAS_IN_POOL * 100000;

        uint256 time;

        console2.log(
            "time, delay, gasUsed, gasInPool, baseFeePerGasAMM, baseFeePerGasVanilla"
        );

        uint32[2][] memory blocks = Data.blocks();

        for (uint256 i; i < blocks.length; i++) {
            // blocks[i][0] is the block delay
            // blocks[i][1] is the parent gas used
            uint256 delay = _regtime(time + blocks[i][0]) - _regtime(time);
            time += blocks[i][0];

            baseFeePerGasVanilla = Lib1559Math.calcBaseFeePerGas(
                baseFeePerGasVanilla, blocks[i][1], BLOCK_GAS_TARGET
            );

            uint256 baseFeePerGasAMM;
            (baseFeePerGasAMM, gasInPool) = Lib1559Math.calcBaseFeePerGasAMM(
                POOL_AMM_PRODUCT,
                GAS_ISSUE_PER_SECOND,
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
