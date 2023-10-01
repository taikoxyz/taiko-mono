// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { StringsUpgradeable as Strings } from
    "@ozu/utils/StringsUpgradeable.sol";
import { console2 } from "forge-std/console2.sol";

import { Lib1559AMM } from "../../../contracts/L2/1559/EIP1559ManagerAMM.sol";
import { Lib1559Exp } from "../../../contracts/L2/1559/EIP1559ManagerExp.sol";
import { Lib1559Standard } from
    "../../../contracts/L2/1559/EIP1559ManagerStandard.sol";
import { TestBase } from "../../TestBase.sol";
import { EIP1559TestData as Data } from "./EIP1559Test.d.sol";

contract EIP1559Test is TestBase {
    // WARNING:
    // AVG_BLOCK_TIME and BLOCK_GAS_TARGET should match the values in
    // blocktime_gasused_gen.py
    uint256 public constant AVG_BLOCK_TIME = 3;
    uint256 public constant BLOCK_GAS_TARGET = 5_000_000; // 4.3 million

    uint256 public constant INIT_BASEFEE_PER_GAS = 10 gwei;
    uint256 public constant INIT_GAS_IN_POOL = BLOCK_GAS_TARGET * 1000;
    uint256 public constant POOL_AMM_PRODUCT =
        INIT_BASEFEE_PER_GAS * INIT_GAS_IN_POOL * INIT_GAS_IN_POOL;
    uint256 public constant GAS_ISSUE_PER_SECOND =
        BLOCK_GAS_TARGET / AVG_BLOCK_TIME;

    uint256 public constant X_SCALE = 44_655_463_198;
    uint256 public constant Y_SCALE = 1_203_884_546_759_353_210_212_365_284_652;
    uint256 public constant GAS_EXCESS_MAX = 3_029_998_788;

    function test_1559ParamCalculation() external {
        // Tune this number manually so expectedRatio2X1X is ~112.5%.
        uint64 _multiplier_to_figure_out = 1818;
        uint64 expectedRatio2X1X = 11_250; // ~12.5% increase
        uint256 gasExcessMax = GAS_ISSUE_PER_SECOND * _multiplier_to_figure_out;

        console2.log("INIT_BASEFEE_PER_GAS.    : ", INIT_BASEFEE_PER_GAS);
        console2.log("GAS_ISSUE_PER_SECOND.    : ", GAS_ISSUE_PER_SECOND);
        console2.log("BLOCK_GAS_TARGET         : ", BLOCK_GAS_TARGET);
        console2.log("expectedRatio2X1X              : ", expectedRatio2X1X);
        console2.log("gasExcessMax             : ", gasExcessMax);

        (uint256 xscale, uint256 yscale, uint256 actualRatio) = Lib1559Exp
            .calculateScales(gasExcessMax, INIT_BASEFEE_PER_GAS, BLOCK_GAS_TARGET);

        console2.log("xscale                    : ", xscale);
        console2.log("yscale                    : ", yscale);
        console2.log("_multiplier_to_figure_out :", _multiplier_to_figure_out);
        assertEq(actualRatio, expectedRatio2X1X);

        // INIT_BASEFEE_PER_GAS.    :  10000000000
        // GAS_ISSUE_PER_SECOND.    :  1666666
        // BLOCK_GAS_TARGET         :  5000000
        // expectedRatio2X1X              :  11250
        // gasExcessMax             :  3029998788
        // xscale                    :  44655463198
        // yscale                    :  1203884546759353210212365284652
        // _multiplier_to_figure_out : 1818
    }

    function test_1559_compare() public view {
        // Variable for standard 1559
        uint256 baseFeePerGasVanilla = INIT_BASEFEE_PER_GAS;

        // Variables for AMM-based 1559
        uint256 gasInPool = INIT_GAS_IN_POOL;
        uint256 maxGasInPool =
            INIT_GAS_IN_POOL + BLOCK_GAS_TARGET * 60 / AVG_BLOCK_TIME; // INIT_GAS_IN_POOL
            // * 100000;

        // Variables for Exp 1559
        uint256 gasExcess = GAS_EXCESS_MAX / 2;

        // Other variables
        uint256 time;

        console2.log(
            "time, delay, gasUsed, baseFeePerGasStandard, baseFeePerGasAMM, baseFeePerGasExp"
        );

        uint32[2][] memory blocks = Data.blocks();

        for (uint256 i; i < blocks.length; i++) {
            // for (uint256 i; i <2; i++) {
            // blocks[i][0] is the block delay
            // blocks[i][1] is the parent gas used
            uint256 delay = _regtime(time + blocks[i][0]) - _regtime(time);
            time += blocks[i][0];

            baseFeePerGasVanilla = Lib1559Standard.calcBaseFeePerGas(
                baseFeePerGasVanilla, blocks[i][1], BLOCK_GAS_TARGET
            );

            uint256 baseFeePerGasAMM;
            (baseFeePerGasAMM, gasInPool) = Lib1559AMM.calcBaseFeePerGas(
                POOL_AMM_PRODUCT,
                GAS_ISSUE_PER_SECOND,
                maxGasInPool,
                gasInPool,
                delay,
                blocks[i][1]
            );

            uint256 baseFeePerGasExp;
            (baseFeePerGasExp, gasExcess) = Lib1559Exp.calcBaseFeePerGas(
                GAS_ISSUE_PER_SECOND,
                X_SCALE,
                Y_SCALE,
                GAS_EXCESS_MAX,
                gasExcess,
                delay,
                blocks[i][1]
            );

            _print(
                time,
                delay,
                blocks[i][1],
                baseFeePerGasVanilla,
                baseFeePerGasAMM,
                baseFeePerGasExp
            );
        }
    }

    function _print(
        uint256 time,
        uint256 delay,
        uint256 gasUsed,
        uint256 baseFeePerGasVanilla,
        uint256 baseFeePerGasAMM,
        uint256 baseFeePerGasExp
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
            Strings.toString(baseFeePerGasAMM),
            ", ",
            Strings.toString(baseFeePerGasVanilla),
            ", ",
            Strings.toString(baseFeePerGasExp),
            ""
        );

        console2.log(str);
    }

    function _regtime(uint256 time) private pure returns (uint256) {
        return (1 + time / 12) * 12;
    }
}
