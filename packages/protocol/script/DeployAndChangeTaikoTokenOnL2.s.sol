// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/tko/BridgedTaikoToken.sol";
import "../contracts/tokenvault/ERC20Vault.sol";

contract DeployTaikoToken is DeployCapability {
    // If the private key to deploy proxy shall be different to the private key to changing the
    // vault's bridge address(changeBridgedToken) then we need 2 private keys.
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    // L2 related
    address public bridgedTkoOwner = vm.envAddress("BRIDGED_TKO_OWNER");
    address public l2AddressManager = vm.envAddress("L2_ADDRESS_MANAGER");
    address public l2Erc20Vault = vm.envAddress("ERC20_VAULT_ON_L2");

    // L1 related
    address public l1TaikoToken = vm.envAddress("TKO_ADDRESS_ON_L1");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Deploy the TaikoToken contract on L2
        address deployedTkoProxy = deployProxy({
            name: "taiko_token",
            impl: address(new BridgedTaikoToken()),
            data: abi.encodeCall(BridgedTaikoToken.init, (bridgedTkoOwner, l2AddressManager))
        });

        // Change BridgedToken
        ERC20Vault vault = ERC20Vault(l2Erc20Vault);

        address currBridgedtoken = vault.canonicalToBridged(1, l1TaikoToken);
        console2.log("current btoken for tko:", currBridgedtoken);

        vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: l1TaikoToken,
                decimals: 18,
                symbol: "TKO",
                name: "Taiko Token"
            }),
            deployedTkoProxy
        );
        if (vault.paused()) {
            vault.unpause();
        }

        address newBridgedToken = vault.canonicalToBridged(1, l1TaikoToken);
        console2.log("new btoken for tko:", newBridgedToken);

        require(deployedTkoProxy == newBridgedToken, "unexpected result");
    }
}
