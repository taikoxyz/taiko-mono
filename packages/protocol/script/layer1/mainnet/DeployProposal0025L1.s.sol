// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";

/// @title DeployProposal0025L1
/// @notice Deploys the L1 `Bridge` and `ERC20Vault` implementations that Proposal0025 upgrades the
/// mainnet bridge and ERC20 vault proxies to.
/// @dev Deploys new implementations only. It does not upgrade the proxies and does not call any
/// initializer.
///
/// Both constructors reproduce the immutables the live proxies carry, and the script reads them
/// back from the live proxies before broadcasting so a drifted `LibL1Addrs` constant aborts the
/// run instead of baking into the new immutables. The only behavioural change these
/// implementations ship over the ones Proposal0024 installs is #22156: recalls no longer consume
/// the Ether or token withdrawal quota.
/// @custom:security-contact security@taiko.xyz
contract DeployProposal0025L1 is Script {
    struct Deployment {
        address bridgeImpl;
        address erc20VaultImpl;
    }

    error ImmutableMismatch();
    error LiveProxyMismatch();

    /// @notice Deploys the implementations and logs the addresses Proposal0025 needs.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        _checkLiveProxies();

        vm.startBroadcast(privateKey);
        Deployment memory deployment = _deployContracts();
        vm.stopBroadcast();

        _checkImmutables(deployment);

        console2.log("BRIDGE_NEW_IMPL_L1:", deployment.bridgeImpl);
        console2.log("ERC20_VAULT_NEW_IMPL_L1:", deployment.erc20VaultImpl);
    }

    /// @dev Aborts unless the live proxies answer the resolver, signal service, quota manager and
    /// pauser this script is about to compile into the new implementations. All are reproduced
    /// from `LibL1Addrs`, and the whole point of the upgrade is to keep them.
    function _checkLiveProxies() private view {
        Bridge bridge = Bridge(payable(LibL1Addrs.BRIDGE));
        ERC20Vault vault = ERC20Vault(LibL1Addrs.ERC20_VAULT);
        require(
            bridge.resolver() == LibL1Addrs.SHARED_RESOLVER
                && address(bridge.signalService()) == LibL1Addrs.SIGNAL_SERVICE
                && address(bridge.quotaManager()) == LibL1Addrs.QUOTA_MANAGER
                && bridge.pauser() == LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH
                && vault.resolver() == LibL1Addrs.SHARED_RESOLVER
                && address(vault.quotaManager()) == LibL1Addrs.QUOTA_MANAGER,
            LiveProxyMismatch()
        );
    }

    /// @dev Deploys the two implementations with the live proxies' immutables.
    /// @return deployment_ The two newly deployed addresses.
    function _deployContracts() private returns (Deployment memory deployment_) {
        deployment_.bridgeImpl = address(
            new Bridge(
                LibL1Addrs.SHARED_RESOLVER,
                LibL1Addrs.SIGNAL_SERVICE,
                LibL1Addrs.QUOTA_MANAGER,
                LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH
            )
        );
        deployment_.erc20VaultImpl =
            address(new ERC20Vault(LibL1Addrs.SHARED_RESOLVER, LibL1Addrs.QUOTA_MANAGER));
    }

    /// @dev Aborts if a constructor argument landed in the wrong position. Every argument is an
    /// address, so a swapped pair compiles cleanly and would otherwise only surface once a proxy
    /// is pointed at it.
    /// @param _deployment The freshly deployed implementations.
    function _checkImmutables(Deployment memory _deployment) private view {
        Bridge bridgeImpl = Bridge(payable(_deployment.bridgeImpl));
        ERC20Vault vaultImpl = ERC20Vault(_deployment.erc20VaultImpl);
        require(
            bridgeImpl.resolver() == LibL1Addrs.SHARED_RESOLVER
                && address(bridgeImpl.signalService()) == LibL1Addrs.SIGNAL_SERVICE
                && address(bridgeImpl.quotaManager()) == LibL1Addrs.QUOTA_MANAGER
                && bridgeImpl.pauser() == LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH
                && vaultImpl.resolver() == LibL1Addrs.SHARED_RESOLVER
                && address(vaultImpl.quotaManager()) == LibL1Addrs.QUOTA_MANAGER,
            ImmutableMismatch()
        );
    }
}
