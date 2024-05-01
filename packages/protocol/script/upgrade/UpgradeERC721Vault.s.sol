// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/tokenvault/ERC721Vault.sol";
import "./UpgradeScript.s.sol";

contract UpgradeERC721Vault is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading ERC721Vault");
        ERC721Vault newERC721Vault = new ERC721Vault();
        upgrade(address(newERC721Vault));

        console2.log("upgraded ERC721Vault to", address(newERC721Vault));
    }
}
