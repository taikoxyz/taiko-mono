// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/L1/TaikoToken.sol";
import "./UpgradeScript.s.sol";

contract UpgradeTaikoToken is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading TaikoToken");

        upgrade(0x087F33bF5141033BBf7A2AcEf5d8fAdCE9204ecA);

        console2.log("upgraded TaikoToken to", 0x087F33bF5141033BBf7A2AcEf5d8fAdCE9204ecA);
    }
}
