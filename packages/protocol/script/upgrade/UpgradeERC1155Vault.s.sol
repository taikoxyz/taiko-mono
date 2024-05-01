// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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
