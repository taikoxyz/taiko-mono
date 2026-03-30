// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { CrossChainSwapVaultL1 } from
    "../../../../contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title SetupCrossChainDex
/// @notice Script to link L1 vault to L2 vault after deployment
contract SetupCrossChainDex is Script {
    address internal immutable l1Vault = vm.envAddress("L1_VAULT");
    address internal immutable l2Vault = vm.envAddress("L2_VAULT");

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        console2.log("=====================================");
        console2.log("Setting up Cross-Chain DEX (L1)");
        console2.log("=====================================");
        console2.log("L1 Vault:", l1Vault);
        console2.log("L2 Vault:", l2Vault);
        console2.log("");

        CrossChainSwapVaultL1(payable(l1Vault)).setL2Vault(l2Vault);
        console2.log("Set L2Vault on L1Vault");

        console2.log("");
        console2.log("=====================================");
        console2.log("Setup Complete");
        console2.log("=====================================");
        console2.log("");
        console2.log("Don't forget to also set L1Vault on L2Vault using L2 RPC!");
    }
}
