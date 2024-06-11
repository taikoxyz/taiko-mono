// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/L1/TaikoL1.sol";
import "./UpgradeScript.s.sol";

contract UpgradeTaikoL1 is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading TaikoL1");
        TaikoL1 newTaikoL1 = new TaikoL1();
        upgrade(address(newTaikoL1));

        console2.log("upgraded TaikoL1 to", address(newTaikoL1));
    }
}
