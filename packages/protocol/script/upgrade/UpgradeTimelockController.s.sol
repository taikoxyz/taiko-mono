// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/L1/gov/TaikoTimelockController.sol";
import "./UpgradeScript.s.sol";

contract UpgradeTaikoTimelockController is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading TaikoTimelockController");
        TaikoTimelockController newTaikoTimelockController = new TaikoTimelockController();
        upgrade(address(newTaikoTimelockController));

        console2.log("upgraded TaikoTimelockController to", address(newTaikoTimelockController));
    }
}
