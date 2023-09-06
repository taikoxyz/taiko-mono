// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../contracts/tokenvault/ERC20Vault.sol";
import "./UpgradeScript.s.sol";

contract UpgradeERC20Vault is UpgradeScript {
    function run() external setUp {
        ERC20Vault newERC20Vault = new ProxiedERC20Vault();
        proxy.upgradeTo(address(newERC20Vault));
        console2.log(
            "proxy upgraded ERC20Vault implementation to",
            address(newERC20Vault)
        );
    }
}
