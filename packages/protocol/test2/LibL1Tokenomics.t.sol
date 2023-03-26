// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";
import {LibL1Tokenomics} from "../contracts/L1/libs/LibL1Tokenomics.sol";

contract TaikoL1WithConfig is Test {
    struct FeeConfig {
        uint64 avgTimeMAF;
        uint64 avgTimeCap;
        uint64 gracePeriodPctg;
        uint64 maxPeriodPctg;
        // extra fee/reward on top of baseFee
        uint64 multiplerPctg;
    }

    function test_getTimeAdjustedFee() public {
        uint256 feeBase = 10 * 1E8;
        uint256 tLast = 100000;
        uint256 tAvg = 40;
        uint256 tNow = tLast + tAvg;

        TaikoData.FeeConfig memory feeConfig = TaikoData.FeeConfig({
            avgTimeMAF: 1024,
            avgTimeCap: uint16(tAvg * 1000),
            gracePeriodPctg: 100,
            maxPeriodPctg: 400,
            multiplerPctg: 200
        });

        (uint256 newFeeBase, uint256 tRelBp) = LibL1Tokenomics
            .getTimeAdjustedFee(
                feeConfig,
                feeBase,
                true,
                tNow, // seconds
                tLast, // seconds
                (tAvg * 1000) // miliseconds
            );

        assertEq(newFeeBase, feeBase);
        assertEq(tRelBp, 0);
    }
}
