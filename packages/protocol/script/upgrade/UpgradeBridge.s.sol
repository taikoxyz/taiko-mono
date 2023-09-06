// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../contracts/bridge/Bridge.sol";
import "./UpgradeScript.s.sol";

contract UpgradeBridge is UpgradeScript {
    function run() external setUp {
        Bridge newBridge = new ProxiedBridge();
        proxy.upgradeTo(address(newBridge));
        console2.log(
            "proxy upgraded Bridge implementation to", address(newBridge)
        );
    }
}
