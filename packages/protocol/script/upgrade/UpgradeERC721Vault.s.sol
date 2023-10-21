// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../../contracts/tokenvault/ERC721Vault.sol";
import "./UpgradeScript.s.sol";

contract UpgradeERC721Vault is UpgradeScript {
    function run() external setUp {
        ERC721Vault newERC721Vault = new ProxiedERC721Vault();
        proxy.upgradeTo(address(newERC721Vault));
        console2.log(
            "proxy upgraded ERC721Vault implementation to",
            address(newERC721Vault)
        );
    }
}
