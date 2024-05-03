// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/tko/BridgedTaikoToken.sol";
import "../contracts/tokenvault/ERC20Vault.sol";

contract DeployAndChangeTaikoTokenOnL2 is DeployCapability {
    // If the private key to deploy proxy shall be different to the private key to changing the
    // vault's bridge address(changeBridgedToken) then we need 2 private keys.

    address public vaultOwner = vm.envAddress("VAULT_OWNER");
    uint256 public vaultOwnerPrivateKey = vm.envUint("VAULT_OWNER_PRIVATE_KEY");
    address public l2Erc20Vault = vm.envAddress("ERC20_VAULT_ON_L2");

    modifier broadcast() {
        require(vaultOwnerPrivateKey != 0, "invalid private key");
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

        (address canonicalTkoAddress, uint256 chainId) =
            BridgedTaikoToken(deployedTkoProxy).canonical();

        address currBridgedtoken = vault.canonicalToBridged(chainId, canonicalTkoAddress);
        assert(currBridgedtoken == address(0));

        vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: uint64(chainId),
                addr: canonicalTkoAddress,
                decimals: 18,
                symbol: "TKO",
                name: "Taiko Token"
            }),
            deployedTkoProxy
        );
        if (vault.paused()) {
            vault.unpause();
        }

        address newBridgedToken = vault.canonicalToBridged(chainId, canonicalTkoAddress);
        console2.log("new btoken for tko:", newBridgedToken);

        require(deployedTkoProxy == newBridgedToken, "unexpected result");
    }
}
