// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/tokenvault/ERC1155Vault.sol";
import "./UpgradeScript.s.sol";

contract UpgradeERC1155Vault is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading ERC1155Vault");
        ERC1155Vault newERC1155Vault = new ERC1155Vault();
        upgrade(address(newERC1155Vault));

        console2.log("upgraded ERC1155Vault to", address(newERC1155Vault));
    }
}
