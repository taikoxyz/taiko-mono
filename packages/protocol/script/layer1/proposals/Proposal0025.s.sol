// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BuildProposal } from "../governance/BuildProposal.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";

// To print the proposal action data: `P=0025 pnpm proposal`
// To dryrun the proposal on L1: `P=0025 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0025 pnpm proposal:dryrun:l2`
/// @title Proposal0025
/// @notice Upgrades the bridge and all three vaults on L1 and L2 to implementations built after
/// #22156, which switches off failing and recalling messages, and moves the ERC721 and ERC1155
/// vaults off the legacy AddressManagers onto the shared resolvers. Executes after Proposal0024,
/// which installs the bridge and ERC20 vault implementations these replace and populates the L2
/// resolver they read.
/// @custom:security-contact security@taiko.xyz
contract Proposal0025 is BuildProposal {
    /// @dev The contracts the L1 leg points at. A struct with named fields rather than positional
    /// parameters: every member is an address, so a transposed pair would compile silently.
    struct L1Deployment {
        // The `Bridge` implementation the L1 bridge proxy upgrades to.
        address bridgeImpl;
        // The `ERC20Vault` implementation the L1 ERC20 vault proxy upgrades to.
        address erc20VaultImpl;
        // The `ERC721Vault` implementation the L1 ERC721 vault proxy upgrades to.
        address erc721VaultImpl;
        // The `ERC1155Vault` implementation the L1 ERC1155 vault proxy upgrades to.
        address erc1155VaultImpl;
        // The `BridgedERC721` implementation the L1 resolver registers as `bridged_erc721`.
        address bridgedErc721Impl;
        // The `BridgedERC1155` implementation the L1 resolver registers as `bridged_erc1155`.
        address bridgedErc1155Impl;
    }

    /// @dev The contracts the L2 leg points at.
    struct L2Deployment {
        // The `Bridge` implementation the L2 bridge proxy upgrades to.
        address bridgeImpl;
        // The `ERC20Vault` implementation the L2 ERC20 vault proxy upgrades to.
        address erc20VaultImpl;
        // The `ERC721Vault` implementation the L2 ERC721 vault proxy upgrades to.
        address erc721VaultImpl;
        // The `ERC1155Vault` implementation the L2 ERC1155 vault proxy upgrades to.
        address erc1155VaultImpl;
        // The `BridgedERC721` implementation the L2 resolver registers as `bridged_erc721`.
        address bridgedErc721Impl;
        // The `BridgedERC1155` implementation the L2 resolver registers as `bridged_erc1155`.
        address bridgedErc1155Impl;
    }

    // Only the proxy implementations are proposal-local. The bridged-token implementations the
    // resolvers name from this proposal on live in `LibL1Addrs.BRIDGED_ERC721`,
    // `LibL1Addrs.BRIDGED_ERC1155`, `LibL2Addrs.BRIDGED_ERC721` and `LibL2Addrs.BRIDGED_ERC1155`,
    // updated ahead of execution.

    // The codediff links compare each new implementation against the one it replaces (`addr`):
    // for the bridges and ERC20 vaults the one Proposal0024 installs, which the proxies do not run
    // until then; for the NFT vaults the one the proxy runs today.

    /// @dev Deployed by `DeployProposal0025L1` on Ethereum mainnet.
    /// https://codediff.taiko.xyz/?addr=0xA15dca0A72da684f20e0FC708DECFb230a715462&newimpl=0xe6BF63dCc936063caD2300f32DaA67d9eE5c57b6&chainid=1
    address public constant BRIDGE_NEW_IMPL_L1 = 0xe6BF63dCc936063caD2300f32DaA67d9eE5c57b6;

    /// @dev Deployed by `DeployProposal0025L1` on Ethereum mainnet.
    /// https://codediff.taiko.xyz/?addr=0x32E47c04E8c329E8c10062731448e7658aDEEB8e&newimpl=0xd429A698d19b5789ce6Eb72d8B3ae9fad3b28A92&chainid=1
    address public constant ERC20_VAULT_NEW_IMPL_L1 = 0xd429A698d19b5789ce6Eb72d8B3ae9fad3b28A92;

    /// @dev Deployed by `DeployProposal0025L1` on Ethereum mainnet.
    /// https://codediff.taiko.xyz/?addr=0xA4C5c20aB33C96B1c281Dca37D03E23609274C49&newimpl=0x611f3Dc278A14b6ED14410Cd9d56E1721cf33802&chainid=1
    address public constant ERC721_VAULT_NEW_IMPL_L1 = 0x611f3Dc278A14b6ED14410Cd9d56E1721cf33802;

    /// @dev Deployed by `DeployProposal0025L1` on Ethereum mainnet.
    /// https://codediff.taiko.xyz/?addr=0x838ed469db456b67EB3b0B74D759Be4DA999b9c8&newimpl=0xca775D0Bb8CEFe388E344f75De91Aebd0E73c58E&chainid=1
    address public constant ERC1155_VAULT_NEW_IMPL_L1 = 0xca775D0Bb8CEFe388E344f75De91Aebd0E73c58E;

    /// @dev Deployed by `DeployProposal0025L2` on Taiko.
    /// https://codediff.taiko.xyz/?addr=0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb&newimpl=0xF372Db3F06AcaB3347697866d2047a54D1BA8eB3&chainid=167000
    address public constant BRIDGE_NEW_IMPL_L2 = 0xF372Db3F06AcaB3347697866d2047a54D1BA8eB3;

    /// @dev Deployed by `DeployProposal0025L2` on Taiko.
    /// https://codediff.taiko.xyz/?addr=0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3&newimpl=0x25D8465fD0C8D89bfdE910E47c41f4E465672B5c&chainid=167000
    address public constant ERC20_VAULT_NEW_IMPL_L2 = 0x25D8465fD0C8D89bfdE910E47c41f4E465672B5c;

    /// @dev Deployed by `DeployProposal0025L2` on Taiko.
    /// https://codediff.taiko.xyz/?addr=0xd532f20a4751156C566Da7745db95E7f80145B36&newimpl=0x4cAb75DBE321084fD15c7AA9f7398e073A7EaBd0&chainid=167000
    address public constant ERC721_VAULT_NEW_IMPL_L2 = 0x4cAb75DBE321084fD15c7AA9f7398e073A7EaBd0;

    /// @dev Deployed by `DeployProposal0025L2` on Taiko.
    /// https://codediff.taiko.xyz/?addr=0xBBBC4ad39488b990E095042fa6c59A90d3817846&newimpl=0xe148CceFFcd5494301c20e047634995C60611e57&chainid=167000
    address public constant ERC1155_VAULT_NEW_IMPL_L2 = 0xe148CceFFcd5494301c20e047634995C60611e57;

    uint256 private constant _L1_CHAIN_ID = 1;
    uint256 private constant _L2_CHAIN_ID = 167_000;

    error ImplementationNotDeployed();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        return buildL1Actions(_l1Deployment());
    }

    /// @dev Encodes the L1 leg against injectable addresses so tests can assert the encoding
    /// while a constant above is still a placeholder.
    /// @param _d The implementations the four L1 proxies upgrade to, and the bridged-token
    /// implementations the L1 resolver registers.
    /// @return actions The six L1 actions, in execution order.
    function buildL1Actions(L1Deployment memory _d)
        internal
        pure
        returns (Controller.Action[] memory actions)
    {
        require(
            _d.bridgeImpl != address(0) && _d.erc20VaultImpl != address(0)
                && _d.erc721VaultImpl != address(0) && _d.erc1155VaultImpl != address(0)
                && _d.bridgedErc721Impl != address(0) && _d.bridgedErc1155Impl != address(0),
            ImplementationNotDeployed()
        );

        actions = new Controller.Action[](6);

        // 0: Upgrade the mainnet bridge. The `sendMessage` that `BuildProposal` appends after the
        // L1 actions then leaves through the new implementation in the same transaction it goes
        // live, exactly as in Proposal0024.
        actions[0] = buildUpgradeAction(L1.BRIDGE, _d.bridgeImpl);

        // 1: Upgrade the mainnet ERC20 vault. The new implementation is built with the same
        // resolver and quota manager immutables the live one carries, and the L1 shared resolver
        // already holds every name it reads.
        actions[1] = buildUpgradeAction(L1.ERC20_VAULT, _d.erc20VaultImpl);

        // 2-3: Point the L1 shared resolver's `bridged_erc721` and `bridged_erc1155` at
        // implementations built from `main`, before actions 4 and 5 make the NFT vaults that read
        // them live. Both entries still name the May 2024 implementations, which only have the
        // six-argument, AddressManager-based init, while the new vaults initialise every bridged
        // token they deploy through the five-argument one and the token authorises minting through
        // its vault immutable. Keeping the old entries would make the first delivery to L1 of an
        // NFT collection canonical on another chain revert, the fault Proposal0024 fixed for
        // `bridged_erc20`. The resolver already names both vaults and both bridges on both chains.
        actions[2] = _registerAction(
            L1.SHARED_RESOLVER, _L1_CHAIN_ID, LibNames.B_BRIDGED_ERC721, _d.bridgedErc721Impl
        );
        actions[3] = _registerAction(
            L1.SHARED_RESOLVER, _L1_CHAIN_ID, LibNames.B_BRIDGED_ERC1155, _d.bridgedErc1155Impl
        );

        // 4-5: Upgrade the mainnet ERC721 and ERC1155 vaults. The live implementations resolve
        // through the legacy shared AddressManager `0xEf9EaA1d…`; the new ones read the L1 shared
        // resolver, so after this batch no bridge or vault on L1 reads the AddressManager.
        // Bridged tokens the old vaults deployed keep resolving their vault through it, and it
        // still names the unchanged proxies, so they keep working.
        actions[4] = buildUpgradeAction(L1.ERC721_VAULT, _d.erc721VaultImpl);
        actions[5] = buildUpgradeAction(L1.ERC1155_VAULT, _d.erc1155VaultImpl);
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        return buildL2Actions(_l2Deployment());
    }

    /// @dev Encodes the L2 leg against injectable addresses, for the same reason as the L1
    /// overload.
    /// @param _d The implementations the four L2 proxies upgrade to, and the bridged-token
    /// implementations the L2 resolver registers.
    /// @return l2ExecutionId The DelegateController execution id; zero means unordered.
    /// @return l2GasLimit The gas limit carried by the L1 to L2 message.
    /// @return actions The ten L2 actions, in execution order.
    function buildL2Actions(L2Deployment memory _d)
        internal
        pure
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        require(
            _d.bridgeImpl != address(0) && _d.erc20VaultImpl != address(0)
                && _d.erc721VaultImpl != address(0) && _d.erc1155VaultImpl != address(0)
                && _d.bridgedErc721Impl != address(0) && _d.bridgedErc1155Impl != address(0),
            ImplementationNotDeployed()
        );

        l2ExecutionId = 0;
        l2GasLimit = 5_000_000;
        actions = new Controller.Action[](10);

        // 0-5: Add the NFT names to the resolver Proposal0024 populates, before actions 6 and 7
        // make the NFT vaults that read it live. The legacy registry `0x1670…0006` predates
        // IResolver and cannot serve these lookups, so a missing entry reverts the call that
        // needs it. The `bridge` entries the new vaults read (chain 167000 for the
        // `onlyFromNamed` guard and every send) are Proposal0024's.
        //
        // 0-1: `erc721_vault` and `erc1155_vault` for chain 1 -- what the new vaults read on
        //      every delivery (the message must come from the L1 vault), every send (the message
        //      goes to the L1 vault) and every recipient check.
        actions[0] = _registerAction(
            L2.SHARED_RESOLVER, _L1_CHAIN_ID, LibNames.B_ERC721_VAULT, L1.ERC721_VAULT
        );
        actions[1] = _registerAction(
            L2.SHARED_RESOLVER, _L1_CHAIN_ID, LibNames.B_ERC1155_VAULT, L1.ERC1155_VAULT
        );
        // 2-3: The same names for chain 167000 -- read by nothing today, registered for symmetry
        //      with the L1 resolver, which carries its own chain's vaults, as Proposal0024 did
        //      for `erc20_vault`.
        actions[2] = _registerAction(
            L2.SHARED_RESOLVER, _L2_CHAIN_ID, LibNames.B_ERC721_VAULT, L2.ERC721_VAULT
        );
        actions[3] = _registerAction(
            L2.SHARED_RESOLVER, _L2_CHAIN_ID, LibNames.B_ERC1155_VAULT, L2.ERC1155_VAULT
        );
        // 4-5: `bridged_erc721` and `bridged_erc1155` for chain 167000 -- the implementations
        //      behind every bridged token the new vaults deploy, read on the first delivery of a
        //      collection they have not seen before. Built from `main` for the same reason as L1
        //      actions 2 and 3: the legacy implementations `0x0167…010097` and `0x0167…010098`
        //      only implement the six-argument, AddressManager-based init.
        actions[4] = _registerAction(
            L2.SHARED_RESOLVER, _L2_CHAIN_ID, LibNames.B_BRIDGED_ERC721, _d.bridgedErc721Impl
        );
        actions[5] = _registerAction(
            L2.SHARED_RESOLVER, _L2_CHAIN_ID, LibNames.B_BRIDGED_ERC1155, _d.bridgedErc1155Impl
        );

        // 6-8: Upgrade the three L2 vaults. Each proxy is owned by the DelegateController, which
        // executes this batch, and no vault is on the call stack, so these are plain owner
        // upgrades. Bridged tokens the old NFT vaults deployed keep resolving their vault through
        // the legacy registry, which still names the unchanged proxies.
        actions[6] = buildUpgradeAction(L2.ERC721_VAULT, _d.erc721VaultImpl);
        actions[7] = buildUpgradeAction(L2.ERC1155_VAULT, _d.erc1155VaultImpl);
        actions[8] = buildUpgradeAction(L2.ERC20_VAULT, _d.erc20VaultImpl);

        // 9: Upgrade the L2 bridge. This executes inside the bridge's own processMessage frame,
        // which is safe for the same reasons as in Proposal0024: _authorizeUpgrade carries no
        // reentrancy guard, the DelegateController reads the call context before executing
        // actions, and the outgoing and incoming implementations keep the call context and the
        // reentrancy lock in the same transient slots. It is deliberately the last action so the
        // batch makes no further call after the bridge's own code has been swapped under its
        // frame.
        actions[9] = buildUpgradeAction(L2.BRIDGE, _d.bridgeImpl);
    }

    /// @dev The L1 contracts the no-argument builder encodes: the implementation constants above
    /// and the bridged-token implementations `LibL1Addrs` names.
    /// @return The L1 deployment.
    function _l1Deployment() internal pure returns (L1Deployment memory) {
        return L1Deployment({
            bridgeImpl: BRIDGE_NEW_IMPL_L1,
            erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L1,
            erc721VaultImpl: ERC721_VAULT_NEW_IMPL_L1,
            erc1155VaultImpl: ERC1155_VAULT_NEW_IMPL_L1,
            bridgedErc721Impl: L1.BRIDGED_ERC721,
            bridgedErc1155Impl: L1.BRIDGED_ERC1155
        });
    }

    /// @dev The L2 contracts the no-argument builder encodes.
    /// @return The L2 deployment.
    function _l2Deployment() internal pure returns (L2Deployment memory) {
        return L2Deployment({
            bridgeImpl: BRIDGE_NEW_IMPL_L2,
            erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L2,
            erc721VaultImpl: ERC721_VAULT_NEW_IMPL_L2,
            erc1155VaultImpl: ERC1155_VAULT_NEW_IMPL_L2,
            bridgedErc721Impl: L2.BRIDGED_ERC721,
            bridgedErc1155Impl: L2.BRIDGED_ERC1155
        });
    }

    /// @dev Encodes a `DefaultResolver.registerAddress` call.
    /// @param _resolver The resolver proxy to register on.
    /// @param _chainId The chain id the name is registered for.
    /// @param _name The name to register.
    /// @param _addr The address to register.
    /// @return The action.
    function _registerAction(
        address _resolver,
        uint256 _chainId,
        bytes32 _name,
        address _addr
    )
        private
        pure
        returns (Controller.Action memory)
    {
        return Controller.Action({
            target: _resolver,
            value: 0,
            data: abi.encodeCall(DefaultResolver.registerAddress, (_chainId, _name, _addr))
        });
    }
}
