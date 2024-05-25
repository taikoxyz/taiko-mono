// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/tko/BridgedTaikoToken.sol";
import "../contracts/tokenvault/ERC20Vault.sol";

contract DeployTaikoTokenOnL2 is DeployCapability {
    address public vaultOwner = vm.envAddress("VAULT_OWNER");
    address public l2Erc20Vault = vm.envAddress("ERC20_VAULT_ON_L2");

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Change BridgedToken
        ERC20Vault vault = ERC20Vault(l2Erc20Vault);

        // Deploy the TaikoToken contract on L2
        address deployedTkoProxy = deployProxy({
            name: "taiko_token",
            impl: address(new BridgedTaikoToken()),
            data: abi.encodeCall(BridgedTaikoToken.init, (vaultOwner, vault.addressManager()))
        });
    }
}