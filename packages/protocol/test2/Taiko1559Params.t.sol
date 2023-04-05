// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Lib1559Math as T} from "../contracts/libs/Lib1559Math.sol";
import {TaikoL2} from "../contracts/L2/TaikoL2.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

contract TestTaiko1559Params is Test {
    using SafeCastUpgradeable for uint256;

    function testAndVerifyTaiko1559Params() external {
        // Assume we scale L1 throughput by 10 times.
        uint64 scaleFactor = 10;

        // Assume we lower the L1 transaction cost by 25 times.
        uint64 costFactor = 25;

        // Calculate gas space issuance per second
        uint64 ethereumBlockGasTarget = 15000000;
        uint64 ethereumBlockTime = 12;

        // https://ultrasound.money/
        uint64 ethereumBasefeeNow = 28000000000; // 28Gwei

        uint64 gasIssuedPerSecond = (scaleFactor * ethereumBlockGasTarget) /
            ethereumBlockTime;

        // 500 is just a random number picked
        uint64 gasExcessMaxMax = gasIssuedPerSecond * 728;

        uint64 initialBasefee = ethereumBasefeeNow / costFactor;

        TaikoL2.EIP1559Params memory param1559 = TaikoL2.EIP1559Params({
            basefee: initialBasefee,
            gasIssuedPerSecond: gasIssuedPerSecond,
            gasExcessMax: gasExcessMaxMax,
            gasTarget: ethereumBlockGasTarget,
            ratio2x1x: 11249 // ~12.5% increase
        });

        console2.log("Recommended basefee           :", param1559.basefee);
        console2.log(
            "Recommended gasIssuedPerSecond:",
            param1559.gasIssuedPerSecond
        );
        console2.log("Recommended gasExcessMax      :", param1559.gasExcessMax);

        TaikoL2 L2 = new TaikoL2();
        L2.init(address(1), param1559); // Dummy address manager address.
    }
}
