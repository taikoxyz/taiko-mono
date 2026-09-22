// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BuildProposal } from "../governance/BuildProposal.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { Controller } from "src/shared/governance/Controller.sol";

// To print the proposal action data: `P=0025 pnpm proposal`
// To dryrun the proposal on L1: `P=0025 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0025 pnpm proposal:dryrun:l2`
/// @title Proposal0025
/// @notice Upgrades the L1 and L2 bridges and ERC20 vaults to implementations built after #22156,
/// which exempts recalls from the Ether and token withdrawal quotas. Executes after Proposal0024,
/// which installs the implementations these replace and populates the L2 resolver they read.
/// @custom:security-contact security@taiko.xyz
contract Proposal0025 is BuildProposal {
    /// @dev The implementations the L1 leg points at. A struct with named fields rather than
    /// positional parameters: both members are addresses, so a transposed pair would compile
    /// silently.
    struct L1Deployment {
        // The `Bridge` implementation the L1 bridge proxy upgrades to.
        address bridgeImpl;
        // The `ERC20Vault` implementation the L1 ERC20 vault proxy upgrades to.
        address erc20VaultImpl;
    }

    /// @dev The implementations the L2 leg points at.
    struct L2Deployment {
        // The `Bridge` implementation the L2 bridge proxy upgrades to.
        address bridgeImpl;
        // The `ERC20Vault` implementation the L2 ERC20 vault proxy upgrades to.
        address erc20VaultImpl;
    }

    // TODO(@davidtaikocha): deploy the four implementations, `DeployProposal0025L1` on Ethereum
    // and `DeployProposal0025L2` on Taiko (Proposal0025.md, "Deployment"), then replace the four
    // zero placeholders below with the logged addresses, mirror them in the `DEPLOYED_*` literals
    // of `test/layer1/proposals/Proposal0025.t.sol`, regenerate `Proposal0025.action.md` with
    // `P=0025 pnpm proposal`, and run both dry runs and `Proposal0025ForkTest`. Every builder
    // below reverts `ImplementationNotDeployed` while a placeholder is still zero, so the proposal
    // cannot be encoded by accident before then.

    // The codediff links compare each new implementation against the one Proposal0024 installs
    // (`addr`), not against the proxy, which still runs the pre-Proposal0024 code until then.
    // Replace `[new-impl-placeholder]` with the deployed address alongside the constant.

    /// @dev Deployed by `DeployProposal0025L1` on Ethereum mainnet.
    /// https://codediff.taiko.xyz/?addr=0xA15dca0A72da684f20e0FC708DECFb230a715462&newimpl=[new-impl-placeholder]&chainid=1
    address public constant BRIDGE_NEW_IMPL_L1 = address(0);

    /// @dev Deployed by `DeployProposal0025L1` on Ethereum mainnet.
    /// https://codediff.taiko.xyz/?addr=0x32E47c04E8c329E8c10062731448e7658aDEEB8e&newimpl=[new-impl-placeholder]&chainid=1
    address public constant ERC20_VAULT_NEW_IMPL_L1 = address(0);

    /// @dev Deployed by `DeployProposal0025L2` on Taiko.
    /// https://codediff.taiko.xyz/?addr=0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb&newimpl=[new-impl-placeholder]&chainid=167000
    address public constant BRIDGE_NEW_IMPL_L2 = address(0);

    /// @dev Deployed by `DeployProposal0025L2` on Taiko.
    /// https://codediff.taiko.xyz/?addr=0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3&newimpl=[new-impl-placeholder]&chainid=167000
    address public constant ERC20_VAULT_NEW_IMPL_L2 = address(0);

    error ImplementationNotDeployed();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        return buildL1Actions(
            L1Deployment({
                bridgeImpl: BRIDGE_NEW_IMPL_L1, erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L1
            })
        );
    }

    /// @dev Encodes the L1 leg against injectable addresses so tests can assert the encoding
    /// while a constant above is still a placeholder.
    /// @param _d The implementations the two L1 proxies upgrade to.
    /// @return actions The two L1 actions, in execution order.
    function buildL1Actions(L1Deployment memory _d)
        internal
        pure
        returns (Controller.Action[] memory actions)
    {
        require(
            _d.bridgeImpl != address(0) && _d.erc20VaultImpl != address(0),
            ImplementationNotDeployed()
        );

        actions = new Controller.Action[](2);

        // 0: Upgrade the mainnet bridge. The `sendMessage` that `BuildProposal` appends after the
        // L1 actions then leaves through the new implementation in the same transaction it goes
        // live, exactly as in Proposal0024.
        actions[0] = buildUpgradeAction(L1.BRIDGE, _d.bridgeImpl);

        // 1: Upgrade the mainnet ERC20 vault. The new implementation is built with the same
        // resolver and quota manager immutables the live one carries, and the L1 shared resolver
        // already holds every name it reads.
        actions[1] = buildUpgradeAction(L1.ERC20_VAULT, _d.erc20VaultImpl);
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        return buildL2Actions(
            L2Deployment({
                bridgeImpl: BRIDGE_NEW_IMPL_L2, erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L2
            })
        );
    }

    /// @dev Encodes the L2 leg against injectable addresses, for the same reason as the L1
    /// overload.
    /// @param _d The implementations the two L2 proxies upgrade to.
    /// @return l2ExecutionId The DelegateController execution id; zero means unordered.
    /// @return l2GasLimit The gas limit carried by the L1 to L2 message.
    /// @return actions The two L2 actions, in execution order.
    function buildL2Actions(L2Deployment memory _d)
        internal
        pure
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        require(
            _d.bridgeImpl != address(0) && _d.erc20VaultImpl != address(0),
            ImplementationNotDeployed()
        );

        l2ExecutionId = 0;
        l2GasLimit = 5_000_000;
        actions = new Controller.Action[](2);

        // 0: Upgrade the L2 ERC20 vault. The vault proxy is owned by the DelegateController, which
        // executes this batch, and the vault is not on the call stack, so this is a plain owner
        // upgrade. Both new implementations read `LibL2Addrs.SHARED_RESOLVER`, which Proposal0024
        // populates.
        actions[0] = buildUpgradeAction(L2.ERC20_VAULT, _d.erc20VaultImpl);

        // 1: Upgrade the L2 bridge. This executes inside the bridge's own processMessage frame,
        // which is safe for the same reasons as in Proposal0024: _authorizeUpgrade carries no
        // reentrancy guard, the DelegateController reads the call context before executing
        // actions, and the outgoing and incoming implementations keep the call context and the
        // reentrancy lock in the same transient slots. It is deliberately the last action so the
        // batch makes no further call after the bridge's own code has been swapped under its
        // frame.
        actions[1] = buildUpgradeAction(L2.BRIDGE, _d.bridgeImpl);
    }
}
