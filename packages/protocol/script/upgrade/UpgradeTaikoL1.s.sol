// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "../../contracts/hekla/HeklaTaikoL1.sol";
import "./UpgradeScript.s.sol";

contract UpgradeTaikoL1 is UpgradeScript {
    function run() external setUp {
        upgrade("HeklaTaikoL1", address(new HeklaTaikoL1()));
    }
}
