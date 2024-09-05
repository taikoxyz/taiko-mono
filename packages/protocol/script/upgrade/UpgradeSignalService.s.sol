// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/signal/SignalService.sol";
import "./UpgradeScript.s.sol";

contract UpgradeSignalService is UpgradeScript {
    function run() external setUp {
        upgrade("SignalService", address(new SignalService()));
    }
}
