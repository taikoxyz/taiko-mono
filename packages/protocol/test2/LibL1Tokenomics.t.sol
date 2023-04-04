// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {LibL1Tokenomics} from "../contracts/L1/libs/LibL1Tokenomics.sol";

contract TestLibL1Tokenomics is Test {
    struct FeeConfig {
        uint64 avgTimeMAF;
        uint64 avgTimeCap;
        uint64 gracePeriodPctg;
        uint64 maxPeriodPctg;
        // extra fee/reward on top of baseFee
        uint64 multiplerPctg;
    }

    function testTokenomicsFeeCalcWithNonZeroStartBips() public {
        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 0 seconds,
            dampingFactorBips: 4000, // 40%
            expectedFeeBase: 140 ether,
            expectedPreimumRate: 0
        });

        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 20 seconds,
            dampingFactorBips: 4000, // 40%
            expectedFeeBase: 120 ether,
            expectedPreimumRate: 0
        });

        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 40 seconds,
            dampingFactorBips: 4000, // 40%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 60 seconds,
            dampingFactorBips: 4000, // 40%
            expectedFeeBase: 80 ether,
            expectedPreimumRate: 0
        });

        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 80 seconds,
            dampingFactorBips: 4000, // 40%
            expectedFeeBase: 60 ether,
            expectedPreimumRate: 0
        });

        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 81 seconds,
            dampingFactorBips: 4000, // 40%
            expectedFeeBase: 60 ether,
            expectedPreimumRate: 0
        });
    }

    function testTokenomicsFeeCalcWithZeroStartBips() public {
        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 0 seconds,
            dampingFactorBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 20 seconds,
            dampingFactorBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 40 seconds,
            dampingFactorBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 60 seconds,
            dampingFactorBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 80 seconds,
            dampingFactorBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        testTimeAdjustedFee({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 81 seconds,
            dampingFactorBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });
    }

    function testTimeAdjustedFee(
        uint256 feeBase,
        uint256 timeAverageSec,
        uint256 timeUsedSec,
        uint16 dampingFactorBips,
        uint256 expectedFeeBase,
        uint256 expectedPreimumRate
    ) private {
        TaikoData.FeeConfig memory feeConfig = TaikoData.FeeConfig({
            avgTimeMAF: 1024,
            dampingFactorBips: dampingFactorBips
        });

        (uint256 _feeBase, uint256 _premiumRate) = LibL1Tokenomics
            .getTimeAdjustedFee(
                feeConfig,
                feeBase,
                timeUsedSec,
                timeAverageSec * 1000
            );

        assertEq(_premiumRate, expectedPreimumRate);
        assertEq(_feeBase, expectedFeeBase);
    }
}
