// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/tokenvault/ERC20Vault.sol";
import "./UpgradeScript.s.sol";

contract UpgradeERC20Vault is UpgradeScript {
    function run() external setUp {
        console2.log("upgrading ERC20Vault");
        ERC20Vault newERC20Vault = new ERC20Vault();
        upgrade(address(newERC20Vault));

        console2.log("upgraded ERC20Vault to", address(newERC20Vault));
    }
}
