// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/tokenvault/ERC1155Vault.sol";
import "./UpgradeScript.s.sol";

contract UpgradeERC1155Vault is UpgradeScript {
    function run() external setUp {
        upgrade("ERC1155Vault", address(new ERC1155Vault()));
    }
}
