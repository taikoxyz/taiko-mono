// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/L1/gov/TaikoGovernor.sol";
import "./UpgradeScript.s.sol";

contract UpgradeTaikoGovernor is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading TaikoGovernor");
        TaikoGovernor newTaikoGovernor = new TaikoGovernor();
        upgrade(address(newTaikoGovernor));

        console2.log("upgraded TaikoGovernor to", address(newTaikoGovernor));
    }
}
