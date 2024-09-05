// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/tokenvault/ERC721Vault.sol";
import "./UpgradeScript.s.sol";

contract UpgradeERC721Vault is UpgradeScript {
    function run() external setUp {
        upgrade("ERC721Vault", address(new ERC721Vault()));
    }
}
