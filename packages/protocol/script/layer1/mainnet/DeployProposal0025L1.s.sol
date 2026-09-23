// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IResolver } from "src/shared/common/IResolver.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";
import { BridgedERC1155 } from "src/shared/vault/BridgedERC1155.sol";
import { BridgedERC721 } from "src/shared/vault/BridgedERC721.sol";
import { ERC1155Vault } from "src/shared/vault/ERC1155Vault.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";
import { ERC721Vault } from "src/shared/vault/ERC721Vault.sol";

/// @title DeployProposal0025L1
/// @notice Deploys the L1 contracts Proposal0025 points at: the `Bridge`, `ERC20Vault`,
/// `ERC721Vault` and `ERC1155Vault` implementations the four proxies upgrade to, and the
/// `BridgedERC721` and `BridgedERC1155` implementations the L1 resolver registers.
/// @dev Deploys new contracts only. It does not upgrade the proxies, registers no names and calls
/// no initializer.
///
/// The bridge and ERC20 vault reproduce the immutables of the live proxies, which the script reads
/// back before broadcasting so a drifted `LibL1Addrs` constant aborts the run instead of baking
/// into the new immutables. Their only behavioural change over the implementations Proposal0024
/// installs is #22156: the bridge's new `recallEnabled` immutable is `false`, so messages can no
/// longer be failed or recalled.
///
/// The NFT vaults move from the legacy shared AddressManager onto `LibL1Addrs.SHARED_RESOLVER`,
/// which already names every counterpart they read. New bridged-token implementations are
/// required, not optional: `main`'s NFT vaults initialise each bridged token through the
/// five-argument `init`, while the `bridged_erc721` and `bridged_erc1155` implementations the
/// resolver names today only implement the six-argument, AddressManager-based one.
/// @custom:security-contact security@taiko.xyz
contract DeployProposal0025L1 is Script {
    struct Deployment {
        address bridgeImpl;
        address erc20VaultImpl;
        address erc721VaultImpl;
        address erc1155VaultImpl;
        address bridgedErc721Impl;
        address bridgedErc1155Impl;
    }

    error ImmutableMismatch();
    error LiveProxyMismatch();

    /// @notice Deploys the contracts and logs the addresses Proposal0025 needs.
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
        console2.log("ERC721_VAULT_NEW_IMPL_L1:", deployment.erc721VaultImpl);
        console2.log("ERC1155_VAULT_NEW_IMPL_L1:", deployment.erc1155VaultImpl);
        console2.log("LibL1Addrs.BRIDGED_ERC721:", deployment.bridgedErc721Impl);
        console2.log("LibL1Addrs.BRIDGED_ERC1155:", deployment.bridgedErc1155Impl);
    }

    /// @dev Aborts unless the live proxies answer what this script is about to bake in: the
    /// resolver, signal service, quota manager and pauser of the bridge and ERC20 vault, and the
    /// NFT vault proxies the bridged-token implementations bind to, as the resolver names them.
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
        require(
            _resolve(LibNames.B_ERC721_VAULT) == LibL1Addrs.ERC721_VAULT
                && _resolve(LibNames.B_ERC1155_VAULT) == LibL1Addrs.ERC1155_VAULT,
            LiveProxyMismatch()
        );
    }

    /// @dev Deploys the six contracts.
    /// @return deployment_ The newly deployed addresses.
    function _deployContracts() private returns (Deployment memory deployment_) {
        deployment_.bridgeImpl = address(
            new Bridge(
                LibL1Addrs.SHARED_RESOLVER,
                LibL1Addrs.SIGNAL_SERVICE,
                LibL1Addrs.QUOTA_MANAGER,
                LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH,
                false
            )
        );
        deployment_.erc20VaultImpl =
            address(new ERC20Vault(LibL1Addrs.SHARED_RESOLVER, LibL1Addrs.QUOTA_MANAGER));
        deployment_.erc721VaultImpl = address(new ERC721Vault(LibL1Addrs.SHARED_RESOLVER));
        deployment_.erc1155VaultImpl = address(new ERC1155Vault(LibL1Addrs.SHARED_RESOLVER));
        deployment_.bridgedErc721Impl = address(new BridgedERC721(LibL1Addrs.ERC721_VAULT));
        deployment_.bridgedErc1155Impl = address(new BridgedERC1155(LibL1Addrs.ERC1155_VAULT));
    }

    /// @dev Aborts if a constructor argument landed in the wrong position or the bridge allows
    /// recalls. A swapped pair of address arguments compiles cleanly and would otherwise only
    /// surface once a proxy is pointed at it.
    /// @param _deployment The freshly deployed contracts.
    function _checkImmutables(Deployment memory _deployment) private view {
        Bridge bridgeImpl = Bridge(payable(_deployment.bridgeImpl));
        ERC20Vault vaultImpl = ERC20Vault(_deployment.erc20VaultImpl);
        require(
            bridgeImpl.resolver() == LibL1Addrs.SHARED_RESOLVER
                && address(bridgeImpl.signalService()) == LibL1Addrs.SIGNAL_SERVICE
                && address(bridgeImpl.quotaManager()) == LibL1Addrs.QUOTA_MANAGER
                && bridgeImpl.pauser() == LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH
                && !bridgeImpl.recallEnabled() && vaultImpl.resolver() == LibL1Addrs.SHARED_RESOLVER
                && address(vaultImpl.quotaManager()) == LibL1Addrs.QUOTA_MANAGER,
            ImmutableMismatch()
        );
        require(
            ERC721Vault(_deployment.erc721VaultImpl).resolver() == LibL1Addrs.SHARED_RESOLVER
                && ERC1155Vault(_deployment.erc1155VaultImpl).resolver()
                    == LibL1Addrs.SHARED_RESOLVER
                && BridgedERC721(_deployment.bridgedErc721Impl).erc721Vault()
                    == LibL1Addrs.ERC721_VAULT
                && BridgedERC1155(_deployment.bridgedErc1155Impl).erc1155Vault()
                    == LibL1Addrs.ERC1155_VAULT,
            ImmutableMismatch()
        );
    }

    /// @dev Reads an L1 name from the live L1 resolver.
    /// @param _name The name to resolve.
    /// @return The registered address, or zero.
    function _resolve(bytes32 _name) private view returns (address) {
        return IResolver(LibL1Addrs.SHARED_RESOLVER).resolve(1, _name, true);
    }
}
