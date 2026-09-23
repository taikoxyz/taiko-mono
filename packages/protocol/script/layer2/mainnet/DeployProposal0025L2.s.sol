// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";

/// @title DeployProposal0025L2
/// @notice Deploys the L2 `Bridge` and `ERC20Vault` implementations that Proposal0025 upgrades the
/// L2 bridge and ERC20 vault proxies to.
/// @dev Deploys new implementations only. It does not upgrade the proxies, registers no names and
/// calls no initializer.
///
/// Both implementations carry the immutables of the ones Proposal0024 installs: they read the
/// resolver `DeployBridgeUpgradeL2` deployed (`LibL2Addrs.SHARED_RESOLVER`), which Proposal0024
/// populates, and have neither a quota manager nor a pauser, since L2 has no Ether or token quota
/// and only the owner can pause. The only behavioural change over those implementations is
/// #22156: the bridge's new `recallEnabled` immutable is `false`, so messages can no longer be
/// failed or recalled on L2 either.
/// @custom:security-contact security@taiko.xyz
contract DeployProposal0025L2 is Script {
    struct Deployment {
        address bridgeImpl;
        address erc20VaultImpl;
    }

    error ImmutableMismatch();
    error ResolverOwnerMismatch();

    /// @notice Deploys the implementations and logs the addresses Proposal0025 needs.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        // Read from the live chain before broadcasting: the resolver address bakes into both
        // immutables, so a wrong constant here would only surface once a proxy is pointed at it.
        require(
            DefaultResolver(LibL2Addrs.SHARED_RESOLVER).owner() == LibL2Addrs.DELEGATE_CONTROLLER,
            ResolverOwnerMismatch()
        );

        vm.startBroadcast(privateKey);
        Deployment memory deployment = _deployContracts();
        vm.stopBroadcast();

        _checkImmutables(deployment);

        console2.log("BRIDGE_NEW_IMPL_L2:", deployment.bridgeImpl);
        console2.log("ERC20_VAULT_NEW_IMPL_L2:", deployment.erc20VaultImpl);
    }

    /// @dev Deploys the two implementations against the resolver Proposal0024 populates.
    /// @return deployment_ The two newly deployed addresses.
    function _deployContracts() private returns (Deployment memory deployment_) {
        deployment_.bridgeImpl = address(
            new Bridge(
                LibL2Addrs.SHARED_RESOLVER, LibL2Addrs.SIGNAL_SERVICE, address(0), address(0), false
            )
        );
        deployment_.erc20VaultImpl = address(new ERC20Vault(LibL2Addrs.SHARED_RESOLVER, address(0)));
    }

    /// @dev Aborts if an immutable did not take the intended value.
    /// @param _deployment The freshly deployed implementations.
    function _checkImmutables(Deployment memory _deployment) private view {
        Bridge bridgeImpl = Bridge(payable(_deployment.bridgeImpl));
        ERC20Vault vaultImpl = ERC20Vault(_deployment.erc20VaultImpl);
        require(
            bridgeImpl.resolver() == LibL2Addrs.SHARED_RESOLVER
                && address(bridgeImpl.signalService()) == LibL2Addrs.SIGNAL_SERVICE
                && address(bridgeImpl.quotaManager()) == address(0)
                && bridgeImpl.pauser() == address(0) && !bridgeImpl.recallEnabled()
                && vaultImpl.resolver() == LibL2Addrs.SHARED_RESOLVER
                && address(vaultImpl.quotaManager()) == address(0),
            ImmutableMismatch()
        );
    }
}
