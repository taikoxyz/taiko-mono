// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {LibTokenomics} from "../contracts/L1/libs/LibTokenomics.sol";

contract TaikoL1WithConfig is Test {
    struct FeeConfig {
        uint64 avgTimeMAF;
        uint64 avgTimeCap;
        uint64 gracePeriodPctg;
        uint64 maxPeriodPctg;
        // extra fee/reward on top of baseFee
        uint64 multiplerPctg;
    }

    function testTokenomicsFeeCalcWithNonZeroStartBips() public {
        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 0 seconds,
            isProposal: true,
            startBips: 4000, // 40%
            expectedFeeBase: 140 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 20 seconds,
            isProposal: true,
            startBips: 4000, // 40%
            expectedFeeBase: 120 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 40 seconds,
            isProposal: true,
            startBips: 4000, // 40%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 60 seconds,
            isProposal: true,
            startBips: 4000, // 40%
            expectedFeeBase: 80 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 80 seconds,
            isProposal: true,
            startBips: 4000, // 40%
            expectedFeeBase: 60 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 81 seconds,
            isProposal: true,
            startBips: 4000, // 40%
            expectedFeeBase: 60 ether,
            expectedPreimumRate: 0
        });
    }

    function testTokenomicsFeeCalcWithZeroStartBips() public {
        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 0 seconds,
            isProposal: true,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 20 seconds,
            isProposal: true,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 40 seconds,
            isProposal: true,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 60 seconds,
            isProposal: true,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 80 seconds,
            isProposal: true,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 81 seconds,
            isProposal: true,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });
    }

    function testTokenomicsRewardCalcWithNonZeroStartBips() public {
        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 0 seconds,
            isProposal: false,
            startBips: 4000, // 40%
            expectedFeeBase: 60 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 20 seconds,
            isProposal: false,
            startBips: 4000, // 40%
            expectedFeeBase: 80 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 40 seconds,
            isProposal: false,
            startBips: 4000, // 40%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 60 seconds,
            isProposal: false,
            startBips: 4000, // 40%
            expectedFeeBase: 120 ether,
            expectedPreimumRate: 5000
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 80 seconds,
            isProposal: false,
            startBips: 4000, // 40%
            expectedFeeBase: 140 ether,
            expectedPreimumRate: 10000
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 81 seconds,
            isProposal: false,
            startBips: 4000, // 40%
            expectedFeeBase: 140 ether,
            expectedPreimumRate: 10000
        });
    }

    function testTokenomicsRewardCalcWithZeroStartBips() public {
        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 0 seconds,
            isProposal: false,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 20 seconds,
            isProposal: false,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 40 seconds,
            isProposal: false,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 60 seconds,
            isProposal: false,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 80 seconds,
            isProposal: false,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });

        _oneTest({
            feeBase: 100 ether,
            timeAverageSec: 40 seconds,
            timeUsedSec: 81 seconds,
            isProposal: false,
            startBips: 0, // 0%
            expectedFeeBase: 100 ether,
            expectedPreimumRate: 0
        });
    }

    function _oneTest(
        uint256 feeBase,
        uint256 timeAverageSec,
        uint256 timeUsedSec,
        bool isProposal,
        uint16 startBips,
        uint256 expectedFeeBase,
        uint256 expectedPreimumRate
    ) internal {
        TaikoData.FeeConfig memory feeConfig = TaikoData.FeeConfig({
            avgTimeMAF: 1024,
            startBips: startBips
        });

        (uint256 _feeBase, uint256 _premiumRate) = LibTokenomics
            .getTimeAdjustedFee(
                feeConfig,
                feeBase,
                isProposal,
                timeUsedSec,
                timeAverageSec * 1000
            );

        assertEq(_premiumRate, expectedPreimumRate);
        assertEq(_feeBase, expectedFeeBase);
    }
}
