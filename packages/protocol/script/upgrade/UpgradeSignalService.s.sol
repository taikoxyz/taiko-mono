// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/signal/SignalService.sol";
import "./UpgradeScript.s.sol";

contract UpgradeSignalService is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading SignalService");
        SignalService newSignalService = new SignalService();
        upgrade(address(newSignalService));

        console2.log("upgraded SignalService to", address(newSignalService));
    }
}
