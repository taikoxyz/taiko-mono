// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../contracts/tokenvault/ERC1155Vault.sol";
import "./UpgradeScript.s.sol";

contract UpgradeERC1155Vault is UpgradeScript {
    function run() external setUp {
        ERC1155Vault newERC1155Vault = new ProxiedERC1155Vault();
        proxy.upgradeTo(address(newERC1155Vault));
        console2.log(
            "proxy upgraded ERC1155Vault implementation to",
            address(newERC1155Vault)
        );
    }
}
