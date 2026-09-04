// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { BridgedERC20 } from "src/shared/vault/BridgedERC20.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";

/// @title DeployERC20VaultUpgradeL2
/// @notice Deploys the L2 `ERC20Vault` implementation that Proposal0023 upgrades the L2 vault proxy
/// to, plus a plain `BridgedERC20` that the proposal no longer uses.
/// @dev Deploys new contracts only. It does not upgrade the vault proxy and registers no names:
/// Proposal0023 registers `bridged_erc20` and both `erc20_vault` entries on the resolver as DAO
/// actions. The `BridgedERC20` this script deployed on 2026-09-02 (`0x3505a070…`) was superseded the
/// same day by the `BridgedERC20V2` from `DeployBridgedERC20V2L2`, which adds the EIP-2612 `permit`
/// the vault's new `sendTokenWithPermit` relies on; the script is kept as it ran, because the vault
/// implementation it deployed is the one the proposal points at.
///
/// The vault implementation reads the resolver `DeployBridgeUpgradeL2` deployed on 2026-08-31
/// (`LibL2Addrs.SHARED_RESOLVER`). The live L2 vault implementation (`0xb96AbB41…`, protocol
/// 1.10.0) predates the resolver refactor for the same reason the live bridge does, so the vault
/// moves onto the new resolver alongside the bridge.
///
/// A new `BridgedERC20` implementation is required, not optional. `ERC20Vault` on `main`
/// initialises each bridged token it deploys through the six-argument
/// `IBridgedERC20Initializable.init` and the token authorises minting through its `erc20Vault`
/// immutable. The legacy `bridged_erc20` implementation `0x98161D67…` on the old registry only
/// implements the seven-argument, address-manager based `init`, so registering it on the new
/// resolver would make every first-time token delivery to L2 revert. The immutable is the vault
/// PROXY, which the upgrade does not change, so tokens deployed after the proposal survive future
/// vault upgrades too.
/// @custom:security-contact security@taiko.xyz
contract DeployERC20VaultUpgradeL2 is Script {
    struct Deployment {
        address bridgedErc20Impl;
        address erc20VaultImpl;
    }

    error ImmutableMismatch();
    error ResolverOwnerMismatch();

    /// @notice Deploys the contracts and logs the addresses Proposal0023 needs.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        // Read from the live chain before broadcasting: the resolver address bakes into the vault's
        // immutable, so a wrong constant here would only surface once the proxy is pointed at it.
        require(
            DefaultResolver(LibL2Addrs.SHARED_RESOLVER).owner() == LibL2Addrs.DELEGATE_CONTROLLER,
            ResolverOwnerMismatch()
        );

        vm.startBroadcast(privateKey);
        Deployment memory deployment = _deployContracts();
        vm.stopBroadcast();

        _checkDeployment(deployment);

        console2.log("BRIDGED_ERC20_NEW_IMPL_L2:", deployment.bridgedErc20Impl);
        console2.log("ERC20_VAULT_NEW_IMPL_L2:", deployment.erc20VaultImpl);
    }

    /// @dev Deploys the bridged-token implementation bound to the vault proxy, then the vault
    /// implementation that reads the new resolver.
    /// @return deployment_ The two newly deployed addresses.
    function _deployContracts() private returns (Deployment memory deployment_) {
        deployment_.bridgedErc20Impl = address(new BridgedERC20(LibL2Addrs.ERC20_VAULT));

        // No quota manager on L2: `quota_manager` is unset on the legacy L2 registry, so the live
        // vault enforces no token quota today, and zero preserves that.
        deployment_.erc20VaultImpl = address(new ERC20Vault(LibL2Addrs.SHARED_RESOLVER, address(0)));
    }

    /// @dev Aborts if an immutable did not take the intended value.
    /// @param _deployment The addresses to check.
    function _checkDeployment(Deployment memory _deployment) private view {
        ERC20Vault vaultImpl = ERC20Vault(_deployment.erc20VaultImpl);
        require(
            BridgedERC20(_deployment.bridgedErc20Impl).erc20Vault() == LibL2Addrs.ERC20_VAULT
                && vaultImpl.resolver() == LibL2Addrs.SHARED_RESOLVER
                && address(vaultImpl.quotaManager()) == address(0),
            ImmutableMismatch()
        );
    }
}
