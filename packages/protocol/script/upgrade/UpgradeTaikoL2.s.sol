// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "./UpgradeScript.s.sol";
import "../../contracts/devnet/DevnetTaikoL2.sol";

contract UpgradeTaikoL2 is UpgradeScript {
    function run() external setUp {
        upgrade("DevnetTaikoL2", address(new DevnetTaikoL2()));
    }
}
