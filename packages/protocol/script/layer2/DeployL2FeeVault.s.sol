// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Script, console2 } from "forge-std/src/Script.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";

/// @title DeployL2FeeVault
/// @notice Deploys the `L2FeeVault` implementation and its `ERC1967Proxy` on L2.
/// @dev The proxy address becomes the Etna node's `fee_vault` chain constant, the coinbase of
/// every Etna block, so the vault is deployed before Etna activates.
///
/// Environment:
/// - `PRIVATE_KEY`.
/// - `CONTRACT_OWNER`: the vault owner, who can upgrade the vault: the L2 `DelegateController`
///   outside devnets. Required and non-zero.
/// - `L2_BRIDGE`: the Bridge on this chain that carries sweeps. Non-zero.
/// - `L1_CHAIN_ID`: the chain ID of L1. Non-zero.
/// - `REWARD_POOL`: the `EtnaRewardPool` proxy on L1 that receives every sweep. Non-zero.
/// - `SWEEP_MIN_RELAY_FEE`: the smallest relay fee a sweep accepts, in wei. Non-zero and at most
///   `type(uint64).max`; size it to cover one relayed L1 `processMessage` at the expected L1 gas
///   price.
/// @custom:security-contact security@taiko.xyz
contract DeployL2FeeVault is Script {
    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Deploys the vault and logs its addresses, owner, sweep destination and minimum relay
    /// fee.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, InvalidPrivateKey());
        address owner = vm.envAddress("CONTRACT_OWNER");
        require(owner != address(0), InvalidOwner());
        address l2Bridge = vm.envAddress("L2_BRIDGE");
        uint64 l1ChainId = SafeCast.toUint64(vm.envUint("L1_CHAIN_ID"));
        address rewardPool = vm.envAddress("REWARD_POOL");
        uint64 minRelayFee = SafeCast.toUint64(vm.envUint("SWEEP_MIN_RELAY_FEE"));

        vm.startBroadcast(privateKey);
        // The constructor rejects a zero `L2_BRIDGE`, `L1_CHAIN_ID`, `REWARD_POOL` or
        // `SWEEP_MIN_RELAY_FEE`.
        address impl = address(new L2FeeVault(l2Bridge, l1ChainId, rewardPool, minRelayFee));
        address vault = address(new ERC1967Proxy(impl, abi.encodeCall(L2FeeVault.init, (owner))));
        vm.stopBroadcast();

        console2.log("L2FeeVault proxy:", vault);
        console2.log("  impl       :", impl);
        console2.log("  owner      :", L2FeeVault(vault).owner());
        console2.log("  l2 bridge  :", l2Bridge);
        console2.log("  l1 chain id:", l1ChainId);
        console2.log("  reward pool:", rewardPool);
        console2.log("  min fee    :", minRelayFee);
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidOwner();
    error InvalidPrivateKey();
}
