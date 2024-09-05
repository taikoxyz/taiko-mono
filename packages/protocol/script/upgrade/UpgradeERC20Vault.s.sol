// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "../../contracts/tokenvault/ERC20Vault.sol";
import "./UpgradeScript.s.sol";

contract UpgradeERC20Vault is UpgradeScript {
    function run() external setUp {
        upgrade("ERC20Vault", address(new ERC20Vault()));
    }
}
