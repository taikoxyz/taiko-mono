// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Lib1559Math as T} from "../contracts/libs/Lib1559Math.sol";
import {TaikoL2} from "../contracts/L2/TaikoL2.sol";
import {SafeCastUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

contract TestTaiko1559Params is Test {
    using SafeCastUpgradeable for uint256;

    function run() external {
        this.testAndVerifyTaiko1559Params();
    }

    // We make gasIssuedPerSecond 2,000,000 gas/s == 4 L2 blocks of 6M gas/L1 block,
    // and leave the costFactor as it is.
    function testAndVerifyTaiko1559Params() external {
        // Assume we lower the L1 transaction cost by 25 times.
        uint64 costFactor = 25;

        // Calculate gas space issuance per second
        uint64 ethereumBlockTime = 12;

        // https://ultrasound.money/
        uint64 ethereumBasefeeNow = 28000000000; // 28Gwei

        uint64 gasIssuedPerSecond = 4 * 6000000 / ethereumBlockTime; // We make gasIssuedPerSecond 2,000,000 gas/s == 4 L2 blocks of 6M gas/L1 block

        // Tune this number manually so ratio2x1x is ~112.5%.
        uint64 maxSeconds = 7272;

        uint64 gasExcessMax = gasIssuedPerSecond * maxSeconds;

        uint64 initialBasefee = ethereumBasefeeNow / costFactor;

        TaikoL2.EIP1559Params memory param1559 = TaikoL2.EIP1559Params({
            basefee: initialBasefee,
            gasIssuedPerSecond: gasIssuedPerSecond,
            gasExcessMax: gasExcessMax,
            gasTarget: gasIssuedPerSecond * ethereumBlockTime,
            ratio2x1x: 11250 // ~12.5% increase
        });

        TaikoL2 L2 = new TaikoL2();
        L2.init(address(1), param1559); // Dummy address manager address.

        console2.log("basefee           :", param1559.basefee);
        console2.log("gasIssuedPerSecond:", param1559.gasIssuedPerSecond);
        console2.log("gasExcessMax      :", param1559.gasExcessMax);
        console2.log("gasTarget         :", param1559.gasTarget);
        console2.log("ratio2x1x         :", param1559.ratio2x1x);
        console2.log("yscale            :", L2.yscale());
        console2.log("xscale            :", L2.xscale());
        console2.log("gasExcess         :", L2.gasExcess());

        // basefee           : 1120000000
        // gasIssuedPerSecond: 2000000
        // gasExcessMax      : 14544000000
        // gasTarget         : 24000000
        // ratio2x1x         : 11250
        // yscale            : 2239367572216867291982809680751
        // xscale            : 9303217778
        // gasExcess         : 7272000000
    }
}
