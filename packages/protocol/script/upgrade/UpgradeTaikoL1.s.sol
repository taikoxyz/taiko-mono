// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/L1/TaikoL1Hekla.sol";
import "./UpgradeScript.s.sol";

contract UpgradeTaikoL1 is UpgradeScript {
    function run() external setUp {
        upgrade("TaikoL1", address(new TaikoL1Hekla()));
    }
}
