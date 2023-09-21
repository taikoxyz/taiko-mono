// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../contracts/signal/SignalService.sol";
import "./UpgradeScript.s.sol";

contract UpgradeSignalService is UpgradeScript {
    function run() external setUp {
        SignalService newSignalService = new ProxiedSignalService();
        proxy.upgradeTo(address(newSignalService));
        console2.log(
            "proxy upgraded SignalService implementation to",
            address(newSignalService)
        );
    }
}
