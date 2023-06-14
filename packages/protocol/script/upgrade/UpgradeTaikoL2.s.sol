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
import "../../contracts/L2/TaikoL2.sol";
import "./UpgradeScript.s.sol";

contract UpgradeTaikoL2 is UpgradeScript {
    function run() external setUp {
        TaikoL2 newTaikoL2 = new ProxiedTaikoL2();
        proxy.upgradeTo(address(newTaikoL2));
        console2.log(
            "proxy upgraded TaikoL2 implementation to", address(newTaikoL2)
        );
    }
}
