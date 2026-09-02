// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BuildProposal } from "../governance/BuildProposal.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";

// To print the proposal action data: `P=0023 pnpm proposal`
// To dryrun the proposal on L1: `P=0023 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0023 pnpm proposal:dryrun:l2`
/// @custom:security-contact security@taiko.xyz
contract Proposal0023 is BuildProposal {
    /// @dev The contracts the L1 leg points at. A struct with named fields rather than positional
    /// parameters: every member is an `address`, so a transposed pair would compile silently.
    struct L1Deployment {
        // The `Bridge` implementation the L1 bridge proxy upgrades to.
        address bridgeImpl;
        // The `ERC20Vault` implementation the L1 ERC20 vault proxy upgrades to.
        address erc20VaultImpl;
        // The `BridgedERC20V2` implementation the L1 shared resolver registers as `bridged_erc20`.
        address bridgedErc20Impl;
    }

    /// @dev The contracts the L2 leg points at.
    struct L2Deployment {
        // The new L2 `DefaultResolver` proxy, owned by the DelegateController.
        address sharedResolver;
        // The `Bridge` implementation the L2 bridge proxy upgrades to.
        address bridgeImpl;
        // The `ERC20Vault` implementation the L2 ERC20 vault proxy upgrades to.
        address erc20VaultImpl;
        // The `BridgedERC20V2` implementation the new resolver registers as `bridged_erc20`.
        address bridgedErc20Impl;
    }

    /// @dev Deployed by `DeployBridgeUpgradeL1` on Ethereum mainnet.
    /// https://codediff.taiko.xyz/?addr=0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC&newimpl=0xA15dca0A72da684f20e0FC708DECFb230a715462&chainid=1
    address public constant BRIDGE_NEW_IMPL_L1 = 0xA15dca0A72da684f20e0FC708DECFb230a715462;

    /// @dev Deployed by `DeployERC20VaultUpgradeL1` on Ethereum mainnet.
    /// https://codediff.taiko.xyz/?addr=0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab&newimpl=0x32E47c04E8c329E8c10062731448e7658aDEEB8e&chainid=1
    address public constant ERC20_VAULT_NEW_IMPL_L1 = 0x32E47c04E8c329E8c10062731448e7658aDEEB8e;

    /// @dev Deployed by `DeployBridgedERC20V2L1` on Ethereum mainnet: a `BridgedERC20V2` (EIP-2612
    /// `permit` included) with the vault proxy as its `erc20Vault` immutable, registered as
    /// `bridged_erc20` on the L1 shared resolver in place of the July 2024 implementation
    /// `0x65666141…` that the live vault can no longer initialise.
    address public constant BRIDGED_ERC20_NEW_IMPL_L1 = 0x9ccB9eBa4335096c5B64f050C3c734632D497c3b;

    /// @dev Deployed by `DeployBridgeUpgradeL2` on Taiko L2.
    /// https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000000001&newimpl=0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb&chainid=167000
    address public constant BRIDGE_NEW_IMPL_L2 = 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb;

    /// @dev The new L2 resolver, an ERC1967 proxy over implementation
    /// `0x8Af4669E3068Bae96b92cD73603f5D86beD07a9a`, owned by the DelegateController. It has no
    /// predecessor to diff against: the legacy registry `0x1670…0006` is a different contract that
    /// stays in place for the L2 NFT vaults.
    address public constant L2_SHARED_RESOLVER = 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984;

    /// @dev Deployed by `DeployERC20VaultUpgradeL2` on Taiko L2.
    /// https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000000002&newimpl=0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3&chainid=167000
    address public constant ERC20_VAULT_NEW_IMPL_L2 = 0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3;

    /// @dev Deployed by `DeployBridgedERC20V2L2` on Taiko L2: a `BridgedERC20V2` (EIP-2612 `permit`
    /// included) with the vault proxy as its `erc20Vault` immutable. It is registered as
    /// `bridged_erc20` rather than set as a proxy target, so there is no predecessor to diff
    /// against.
    address public constant BRIDGED_ERC20_NEW_IMPL_L2 = 0xD6601cdea5857338EbdEE4CF38298aff43f01431;

    uint256 private constant _L1_CHAIN_ID = 1;
    uint256 private constant _L2_CHAIN_ID = 167_000;

    error ImplementationNotDeployed();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        return buildL1Actions(
            L1Deployment({
                bridgeImpl: BRIDGE_NEW_IMPL_L1,
                erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L1,
                bridgedErc20Impl: BRIDGED_ERC20_NEW_IMPL_L1
            })
        );
    }

    /// @dev Encodes the L1 leg against injectable addresses so tests can assert the encoding
    /// while a constant above is still a placeholder.
    /// @param _d The implementations the two L1 proxies upgrade to, and the bridged-token
    /// implementation the L1 resolver registers.
    /// @return actions The three L1 actions, in execution order.
    function buildL1Actions(L1Deployment memory _d)
        internal
        pure
        returns (Controller.Action[] memory actions)
    {
        require(
            _d.bridgeImpl != address(0) && _d.erc20VaultImpl != address(0)
                && _d.bridgedErc20Impl != address(0),
            ImplementationNotDeployed()
        );

        actions = new Controller.Action[](3);

        // 0: Upgrade the mainnet bridge to the implementation carrying the EIP-8037 Ether send cap.
        actions[0] = buildUpgradeAction(L1.BRIDGE, _d.bridgeImpl);

        // 1: Upgrade the mainnet ERC20 vault to the implementation carrying EIP-2612 permit and
        // Permit2 support (#22093). The new implementation is built with the same resolver and
        // quota manager immutables the live one carries, and the L1 shared resolver already holds
        // every name the vault reads, so no registration accompanies this upgrade.
        actions[1] = buildUpgradeAction(L1.ERC20_VAULT, _d.erc20VaultImpl);

        // 2: Point the L1 shared resolver's `bridged_erc20` at a `BridgedERC20V2` built from `main`.
        // The entry still names the July 2024 implementation, which only has the seven-argument,
        // address-manager based init, while the live vault has called the six-argument
        // IBridgedERC20Initializable.init since Proposal0017 — so the first delivery to L1 of a
        // token canonical on another chain reverts today. Same fix as L2 action 4; independent of
        // the two upgrades above, so its position in the batch does not matter.
        actions[2] = _registerAction(
            L1.SHARED_RESOLVER, _L1_CHAIN_ID, LibNames.B_BRIDGED_ERC20, _d.bridgedErc20Impl
        );
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        return buildL2Actions(
            L2Deployment({
                sharedResolver: L2_SHARED_RESOLVER,
                bridgeImpl: BRIDGE_NEW_IMPL_L2,
                erc20VaultImpl: ERC20_VAULT_NEW_IMPL_L2,
                bridgedErc20Impl: BRIDGED_ERC20_NEW_IMPL_L2
            })
        );
    }

    /// @dev Encodes the L2 leg against injectable addresses, for the same reason as the L1
    /// overload.
    /// @param _d The new L2 resolver proxy and the three implementations the L2 leg points at.
    /// @return l2ExecutionId The DelegateController execution id; zero means unordered.
    /// @return l2GasLimit The gas limit carried by the L1 to L2 message.
    /// @return actions The seven L2 actions, in execution order.
    function buildL2Actions(L2Deployment memory _d)
        internal
        pure
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        require(
            _d.sharedResolver != address(0) && _d.bridgeImpl != address(0)
                && _d.erc20VaultImpl != address(0) && _d.bridgedErc20Impl != address(0),
            ImplementationNotDeployed()
        );

        l2ExecutionId = 0;
        l2GasLimit = 5_000_000;
        actions = new Controller.Action[](7);

        // 0-4: Populate the new resolver before actions 5 and 6 make the implementations that read
        // it live. The legacy L2 registry `0x1670…0006` predates IResolver and cannot serve any of
        // these lookups, so a missing entry reverts the call that needs it. All seven actions
        // execute in one transaction, so the order inside the batch is defensive; what matters is
        // that the registrations and the upgrades ship in the same bundle.
        //
        // 0: `bridge` for chain 1 — what the new bridge implementation reads on every sendMessage
        //    and processMessage. Its three resolver lookups (isDestChainEnabled,
        //    _proveSignalReceived, _isSignalReceived) all pass the counterparty id, which on L2 is 1.
        actions[0] = _registerAction(_d.sharedResolver, _L1_CHAIN_ID, LibNames.B_BRIDGE, L1.BRIDGE);
        // 1: `bridge` for chain 167000 — what the new vault implementation reads: its
        //    onlyFromNamed(B_BRIDGE) guard on every delivery and recall, and the bridge it sends
        //    through on every sendToken. The bridge itself never reads this entry.
        actions[1] = _registerAction(_d.sharedResolver, _L2_CHAIN_ID, LibNames.B_BRIDGE, L2.BRIDGE);
        // 2: `erc20_vault` for chain 1 — what the new vault implementation reads on every delivery
        //    (the message must come from the L1 vault), every sendToken (the message goes to the L1
        //    vault) and every recipient check.
        actions[2] = _registerAction(
            _d.sharedResolver, _L1_CHAIN_ID, LibNames.B_ERC20_VAULT, L1.ERC20_VAULT
        );
        // 3: `erc20_vault` for chain 167000 — read by nothing today. Registered for symmetry with
        //    the L1 resolver, which carries its own chain's `erc20_vault`, and for future consumers
        //    of the block.chainid overload.
        actions[3] = _registerAction(
            _d.sharedResolver, _L2_CHAIN_ID, LibNames.B_ERC20_VAULT, L2.ERC20_VAULT
        );
        // 4: `bridged_erc20` for chain 167000 — the implementation behind every bridged token the
        //    new vault deploys, read on the first delivery of a canonical token it has not seen
        //    before. This must be built from `main`: the new vault initialises the token through
        //    the six-argument IBridgedERC20Initializable.init and the token authorises minting
        //    through its `erc20Vault` immutable, while the legacy implementation `0x98161D67…`
        //    registered on the old registry only implements the seven-argument, address-manager
        //    based init. Registering the legacy one would make every first-time token delivery to
        //    L2 revert. `BridgedERC20V2` rather than plain `BridgedERC20` so new bridged tokens keep
        //    the EIP-2612 `permit` the legacy implementation has and `sendTokenWithPermit` needs.
        actions[4] = _registerAction(
            _d.sharedResolver, _L2_CHAIN_ID, LibNames.B_BRIDGED_ERC20, _d.bridgedErc20Impl
        );

        // 5: Upgrade the L2 ERC20 vault. The vault proxy is owned by the DelegateController, which
        // executes this batch, and the vault is not on the call stack, so this is a plain owner
        // upgrade. Bridged tokens deployed by the old implementation keep resolving the vault
        // through the legacy registry, which still names the unchanged proxy address.
        actions[5] = buildUpgradeAction(L2.ERC20_VAULT, _d.erc20VaultImpl);

        // 6: Upgrade the L2 bridge. This executes inside the bridge's own processMessage frame,
        // which is safe: _authorizeUpgrade carries no reentrancy guard, the DelegateController
        // reads the call context before executing actions, and the new implementation's transient
        // reentry slot starts at zero rather than _TRUE. It is deliberately the last action so the
        // batch makes no further call after the bridge's own code has been swapped under its frame.
        actions[6] = buildUpgradeAction(L2.BRIDGE, _d.bridgeImpl);
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
