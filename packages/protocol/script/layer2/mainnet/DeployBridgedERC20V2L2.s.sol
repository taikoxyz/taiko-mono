// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { BridgedERC20V2 } from "src/shared/vault/BridgedERC20V2.sol";

/// @title DeployBridgedERC20V2L2
/// @notice Deploys the L2 `BridgedERC20V2` implementation that Proposal0023 registers as
/// `bridged_erc20` on the new L2 resolver.
/// @dev Deploys a new implementation only; the registration is an L2 action of Proposal0023. It
/// supersedes the plain `BridgedERC20` that `DeployERC20VaultUpgradeL2` deployed alongside the vault
/// implementation: the July 2024 implementation the legacy L2 registry names supports EIP-2612
/// `permit`, and the vault's new `sendTokenWithPermit` relies on it, so bridged tokens deployed after
/// the proposal should keep that capability. `BridgedERC20V2` is `BridgedERC20` plus `permit`, with
/// the same constructor and the same six-argument `init` the vault calls. The `erc20Vault` immutable
/// is the vault PROXY, so tokens deployed from it survive future vault upgrades.
/// @custom:security-contact security@taiko.xyz
contract DeployBridgedERC20V2L2 is Script {
    error ImmutableMismatch();

    /// @notice Deploys the implementation and logs the address Proposal0023 needs.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        vm.startBroadcast(privateKey);
        BridgedERC20V2 impl = new BridgedERC20V2(LibL2Addrs.ERC20_VAULT);
        vm.stopBroadcast();

        require(impl.erc20Vault() == LibL2Addrs.ERC20_VAULT, ImmutableMismatch());

        console2.log("LibL2Addrs.BRIDGED_ERC20:", address(impl));
    }
}
