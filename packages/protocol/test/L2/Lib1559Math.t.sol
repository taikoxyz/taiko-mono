// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { StringsUpgradeable as Strings } from
    "@ozu/utils/StringsUpgradeable.sol";
import { console2 } from "forge-std/console2.sol";
import { TestBase } from "../TestBase.sol";
import { Lib1559Math } from "../../contracts/L2/Lib1559Math.sol";
import { Lib1559MathTestData as Data } from "./Lib1559MathTest.d.sol";

contract Lib1559MathTest is TestBase {
    uint256 private _nonce;

    function test_1559_new() public {
        // // -----
        // uint256 constAvgBlockTime = 3;
        // uint256 baseFeePerGas1 = 10 * 1_000_000_000; // 10 Gwei

        // // Vanilla 1559 variables
        // uint256 blockGasTarget = 4_300_000; // 4.3 million

        // // AMM 1559 variables
        // uint256 gasInPool = blockGasTarget * 50;
        // uint256 poolUpdatedAt = 0;

        // uint256 poolProduct = baseFeePerGas1 * gasInPool * gasInPool;
        // uint256 gasIssuePerSecond = blockGasTarget / constAvgBlockTime;
        // uint256 maxGasInPool = gasInPool * 8;

        // -----
        uint256 time;
        uint256 last;
        uint256 baseFeePerGas2;
        uint256 blocktime;

        console2.log(
            "time,time2,blocktime,gasUsed,baseFeePerGas1,baseFeePerGas2,gasInPool"
        );

        uint32[2][100] memory blocks = Data.blocks();

        for (uint256 i; i < blocks.length; i++) {
            {
                uint256 _time = time + blocks[i][0];
                blocktime = _regtime(_time) - _regtime(time);
                time = _time;
            }
            // console2.log("time:", _regtime(time), "blocktime:", blocktime);

            uint256 gasUsed = blocks[i][1];

            // baseFeePerGas1 = Lib1559Math.calcBaseFeePerGas(
            //     baseFeePerGas1, gasUsed, blockGasTarget
            // );

            // (baseFeePerGas2, gasInPool) =
            // Lib1559Math.calcBaseFeePerGasFromPool(
            //     poolProduct,
            //     gasIssuePerSecond,
            //     maxGasInPool,
            //     gasInPool,
            //     blocktime,
            //     gasUsed
            // );

            // poolUpdatedAt = _regtime(time);
            _print(
                time,
                blocktime,
                gasUsed,
                0, //  baseFeePerGas1,
                baseFeePerGas2,
                0 // gasInPool
            );
        }
    }

    function _print(
        uint256 time,
        uint256 blocktime,
        uint256 gasUsed,
        uint256 baseFeePerGas1,
        uint256 baseFeePerGas2,
        uint256 gasInPool
    )
        private
        view
    {
        string memory str = string.concat(
            Strings.toString(time),
            ",",
            Strings.toString(_regtime(time)),
            ",",
            Strings.toString(blocktime),
            ",",
            Strings.toString(gasUsed),
            ",",
            Strings.toString(baseFeePerGas1),
            ",",
            Strings.toString(baseFeePerGas2),
            ",",
            Strings.toString(gasInPool)
        );

        console2.log(str);
    }

    function _regtime(uint256 time) private pure returns (uint256) {
        return (1 + time / 12) * 12;
    }
}
