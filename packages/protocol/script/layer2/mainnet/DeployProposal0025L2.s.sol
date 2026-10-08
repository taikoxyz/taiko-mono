// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";
import { BridgedERC1155 } from "src/shared/vault/BridgedERC1155.sol";
import { BridgedERC721 } from "src/shared/vault/BridgedERC721.sol";
import { ERC1155Vault } from "src/shared/vault/ERC1155Vault.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";
import { ERC721Vault } from "src/shared/vault/ERC721Vault.sol";

/// @title DeployProposal0025L2
/// @notice Deploys the L2 contracts Proposal0025 points at: the `Bridge`, `ERC20Vault`,
/// `ERC721Vault` and `ERC1155Vault` implementations the four proxies upgrade to, and the
/// `BridgedERC721` and `BridgedERC1155` implementations the L2 resolver registers.
/// @dev Deploys new contracts only. It does not upgrade the proxies, registers no names and calls
/// no initializer.
///
/// Every implementation reads the resolver `DeployBridgeUpgradeL2` deployed
/// (`LibL2Addrs.SHARED_RESOLVER`), which Proposal0024 populates and Proposal0025 extends with the
/// NFT names. None has a quota manager or a pauser: L2 has no Ether or token quota and only the
/// owner can pause. The bridge and ERC20 vault carry the immutables of the implementations
/// Proposal0024 installs; the only behavioural change over those is #22156: the bridge's new
/// `recallEnabled` immutable is `false`, so messages can no longer be failed or recalled on L2
/// either.
///
/// The NFT vaults move off the legacy AddressManager `0x1670…0006`, like the bridge and ERC20 vault
/// in Proposal0024. New bridged-token implementations are required, not optional: `main`'s NFT
/// vaults initialise each bridged token through the five-argument `init`, while the legacy
/// `bridged_erc721` and `bridged_erc1155` implementations only implement the six-argument,
/// AddressManager-based one.
/// @custom:security-contact security@taiko.xyz
contract DeployProposal0025L2 is Script {
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
    error ResolverOwnerMismatch();

    /// @notice Deploys the contracts and logs the addresses Proposal0025 needs.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        // Read from the live chain before broadcasting: the resolver and the NFT vault proxies
        // bake into immutables, so a wrong constant here would only surface once a proxy is
        // pointed at it.
        require(
            DefaultResolver(LibL2Addrs.SHARED_RESOLVER).owner() == LibL2Addrs.DELEGATE_CONTROLLER,
            ResolverOwnerMismatch()
        );
        require(
            ERC721Vault(LibL2Addrs.ERC721_VAULT).name() == LibNames.B_ERC721_VAULT
                && ERC1155Vault(LibL2Addrs.ERC1155_VAULT).name() == LibNames.B_ERC1155_VAULT,
            LiveProxyMismatch()
        );

        vm.startBroadcast(privateKey);
        Deployment memory deployment = _deployContracts();
        vm.stopBroadcast();

        _checkImmutables(deployment);

        console2.log("BRIDGE_NEW_IMPL_L2:", deployment.bridgeImpl);
        console2.log("ERC20_VAULT_NEW_IMPL_L2:", deployment.erc20VaultImpl);
        console2.log("ERC721_VAULT_NEW_IMPL_L2:", deployment.erc721VaultImpl);
        console2.log("ERC1155_VAULT_NEW_IMPL_L2:", deployment.erc1155VaultImpl);
        console2.log("LibL2Addrs.BRIDGED_ERC721:", deployment.bridgedErc721Impl);
        console2.log("LibL2Addrs.BRIDGED_ERC1155:", deployment.bridgedErc1155Impl);
    }

    /// @dev Deploys the six contracts against the resolver Proposal0024 populates.
    /// @return deployment_ The newly deployed addresses.
    function _deployContracts() private returns (Deployment memory deployment_) {
        deployment_.bridgeImpl = address(
            new Bridge(
                LibL2Addrs.SHARED_RESOLVER, LibL2Addrs.SIGNAL_SERVICE, address(0), address(0), false
            )
        );
        deployment_.erc20VaultImpl = address(new ERC20Vault(LibL2Addrs.SHARED_RESOLVER, address(0)));
        deployment_.erc721VaultImpl = address(new ERC721Vault(LibL2Addrs.SHARED_RESOLVER));
        deployment_.erc1155VaultImpl = address(new ERC1155Vault(LibL2Addrs.SHARED_RESOLVER));
        deployment_.bridgedErc721Impl = address(new BridgedERC721(LibL2Addrs.ERC721_VAULT));
        deployment_.bridgedErc1155Impl = address(new BridgedERC1155(LibL2Addrs.ERC1155_VAULT));
    }

    /// @dev Aborts if an immutable did not take the intended value.
    /// @param _deployment The freshly deployed contracts.
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
        require(
            ERC721Vault(_deployment.erc721VaultImpl).resolver() == LibL2Addrs.SHARED_RESOLVER
                && ERC1155Vault(_deployment.erc1155VaultImpl).resolver()
                    == LibL2Addrs.SHARED_RESOLVER
                && BridgedERC721(_deployment.bridgedErc721Impl).erc721Vault()
                    == LibL2Addrs.ERC721_VAULT
                && BridgedERC1155(_deployment.bridgedErc1155Impl).erc1155Vault()
                    == LibL2Addrs.ERC1155_VAULT,
            ImmutableMismatch()
        );
    }
}
