// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import { TestBase } from "../TestBase.sol";
import { TaikoL2 } from "../../contracts/L2/TaikoL2.sol";

contract TestTaikoL2_1559 is TestBase {
    function test_1559ParamCalculation() external {
        // Assume we scale L1 throughput by 10 times.
        uint64 scaleFactor = 10;

        // Assume we lower the L1 transaction cost by 25 times.
        uint64 costFactor = 25;

        // Calculate gas space issuance per second
        uint64 ethereumBlockGasTarget = 15_000_000;
        uint64 ethereumBlockTime = 12;

        // https://ultrasound.money/
        uint64 ethereumBasefeeNow = 28_000_000_000; // 28Gwei

        uint32 gasIssuedPerSecond =
            uint32(scaleFactor * ethereumBlockGasTarget / ethereumBlockTime);

        // Tune this number manually so ratio2x1x is ~112.5%.
        uint64 maxSeconds = 7272;

        uint64 gasExcessMax = gasIssuedPerSecond * maxSeconds;

        uint64 initialBasefee = ethereumBasefeeNow / costFactor;
        uint64 ratio2x1x = 11_250; // ~12.5% increase
        uint64 gasTarget = gasIssuedPerSecond * ethereumBlockTime;

        console2.log("basefee           :", initialBasefee);
        console2.log("gasIssuedPerSecond:", gasIssuedPerSecond);
        console2.log("gasExcessMax      :", gasExcessMax);
        console2.log("gasTarget         :", gasTarget);
        console2.log("ratio2x1x         :", ratio2x1x);

        // basefee           : 1120000000
        // gasIssuedPerSecond: 12500000
        // gasExcessMax      : 90900000000
        // gasTarget         : 150000000
        // ratio2x1x         : 11250

        TaikoL2 L2 = new TaikoL2();
        L2.init(getRandomAddress());

        TaikoL2.EIP1559Config memory config = L2.calcEIP1559Config(
            initialBasefee,
            gasIssuedPerSecond,
            gasExcessMax,
            gasTarget,
            ratio2x1x
        );

        console2.log("config.xscale            : ", config.xscale);
        console2.log("config.yscale            : ", config.yscale);
        console2.log("config.gasIssuedPerSecond: ", config.gasIssuedPerSecond);
    }
}
