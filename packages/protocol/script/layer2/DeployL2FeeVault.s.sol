// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/src/Script.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";

/// @title DeployL2FeeVault
/// @notice Deploys the `L2FeeVault` implementation and its `ERC1967Proxy` on L2.
/// @dev The proxy address becomes the Etna node's `fee_vault` chain constant, the coinbase of
/// every Etna block, so the vault is deployed before Etna activates.
///
/// Environment:
/// - `PRIVATE_KEY`.
/// - `CONTRACT_OWNER`: the vault owner, the L2 `DelegateController` outside devnets; the
///   deployer if unset or zero.
/// @custom:security-contact security@taiko.xyz
contract DeployL2FeeVault is Script {
    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Deploys the vault and logs its addresses and owner.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, InvalidPrivateKey());
        address owner = vm.envOr("CONTRACT_OWNER", address(0));

        vm.startBroadcast(privateKey);
        address impl = address(new L2FeeVault());
        address vault = address(new ERC1967Proxy(impl, abi.encodeCall(L2FeeVault.init, (owner))));
        vm.stopBroadcast();

        console2.log("L2FeeVault proxy:", vault);
        console2.log("  impl :", impl);
        console2.log("  owner:", L2FeeVault(payable(vault)).owner());
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidPrivateKey();
}
