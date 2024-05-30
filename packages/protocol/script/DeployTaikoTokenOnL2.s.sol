// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/tko/BridgedTaikoToken.sol";
import "../contracts/tokenvault/ERC20Vault.sol";

contract DeployTaikoTokenOnL2 is DeployCapability {
    address public vaultOwner = 0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be; //vm.envAddress("VAULT_OWNER");
    address public l2Erc20Vault = 0x1670000000000000000000000000000000000002; //vm.envAddress("ERC20_VAULT_ON_L2");

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // For correct address manager
        ERC20Vault vault = ERC20Vault(l2Erc20Vault);

        // Deploy the TaikoToken contract on L2
        deployProxy({
            name: "taiko_token",
            impl: address(new BridgedTaikoToken()),
            data: abi.encodeCall(BridgedTaikoToken.init, (vaultOwner, vault.addressManager()))
        });
    }
}
