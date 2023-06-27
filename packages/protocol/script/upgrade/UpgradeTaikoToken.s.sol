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
import "../../contracts/L1/TaikoToken.sol";
import "./UpgradeScript.s.sol";

contract UpgradeTaikoToken is UpgradeScript {
    function run() external setUp {
        TaikoToken newTaikoToken = new ProxiedTaikoToken();
        proxy.upgradeTo(address(newTaikoToken));
        console2.log(
            "proxy upgraded TaikoToken implementation to",
            address(newTaikoToken)
        );
    }
}
