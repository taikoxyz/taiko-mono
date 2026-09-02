// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { BridgedERC20 } from "src/shared/vault/BridgedERC20.sol";

/// @title DeployBridgedERC20L1
/// @notice Deploys the L1 `BridgedERC20` implementation that Proposal0023 registers as
/// `bridged_erc20` on the L1 shared resolver.
/// @dev Deploys a new implementation only. It registers nothing: the registration is a DAO action,
/// because the L1 shared resolver is owned by the DAO controller.
///
/// The L1 shared resolver still names the July 2024 implementation `0x65666141…`, whose only
/// initializer is the seven-argument, address-manager based `init`, while the live L1 vault has
/// initialised new bridged tokens through the six-argument `IBridgedERC20Initializable.init` since
/// Proposal0017. Every first delivery to L1 of a token canonical on another chain therefore reverts
/// today. `BridgedERC20` on `main` authorises minting through its `erc20Vault` immutable, set here
/// to the vault PROXY so tokens deployed from it survive future vault upgrades.
/// @custom:security-contact security@taiko.xyz
contract DeployBridgedERC20L1 is Script {
    error ImmutableMismatch();

    /// @notice Deploys the implementation and logs the address Proposal0023 needs.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        vm.startBroadcast(privateKey);
        BridgedERC20 bridgedErc20Impl = new BridgedERC20(LibL1Addrs.ERC20_VAULT);
        vm.stopBroadcast();

        require(bridgedErc20Impl.erc20Vault() == LibL1Addrs.ERC20_VAULT, ImmutableMismatch());

        console2.log("BRIDGED_ERC20_NEW_IMPL_L1:", address(bridgedErc20Impl));
    }
}
