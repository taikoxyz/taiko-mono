// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { CrossChainSwapVaultL2 } from
    "../../../../contracts/layer2/surge/cross-chain-dex/CrossChainSwapVaultL2.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title SetupCrossChainDexL2
/// @notice Script to set L1 vault on L2 vault after deployment
contract SetupCrossChainDexL2 is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal immutable l1Vault = vm.envAddress("L1_VAULT");
    address internal immutable l2Vault = vm.envAddress("L2_VAULT");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        console2.log("=====================================");
        console2.log("Setting up Cross-Chain DEX (L2)");
        console2.log("=====================================");
        console2.log("L1 Vault:", l1Vault);
        console2.log("L2 Vault:", l2Vault);
        console2.log("");

        CrossChainSwapVaultL2(payable(l2Vault)).setL1Vault(l1Vault);
        console2.log("Set L1Vault on L2Vault");

        console2.log("");
        console2.log("=====================================");
        console2.log("Setup Complete");
        console2.log("=====================================");
        console2.log("");
        console2.log("Cross-Chain DEX is now fully configured!");
        console2.log("Add liquidity from L1 via addLiquidityToL2()");
    }
}
