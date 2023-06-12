// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "../../contracts/bridge/TokenVault.sol";
import "./UpgradeScript.s.sol";

contract UpgradeTokenVault is UpgradeScript {
    function run() external setUp {
        TokenVault newTokenVault = new ProxiedTokenVault();
        proxy.upgradeTo(address(newTokenVault));
        console2.log(
            "proxy upgraded TokenVault implementation to",
            address(newTokenVault)
        );
    }
}
