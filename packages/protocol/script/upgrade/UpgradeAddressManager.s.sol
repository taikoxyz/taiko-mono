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
import "../../contracts/common/AddressManager.sol";
import "./UpgradeScript.s.sol";

contract UpgradeAddressManager is UpgradeScript {
    function run() external setUp {
        AddressManager newAddressManager = new ProxiedAddressManager();
        proxy.upgradeTo(address(newAddressManager));
        console2.log(
            "proxy upgraded AddressManager implementation to",
            address(newAddressManager)
        );
    }
}
