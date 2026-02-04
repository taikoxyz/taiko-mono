// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { CrossChainSwapHandlerL2 } from
    "../../../../contracts/layer2/surge/cross-chain-dex/CrossChainSwapHandlerL2.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title SetupCrossChainDexL2
/// @notice Script to set L1 handler on L2 handler after deployment
contract SetupCrossChainDexL2 is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal immutable l1Handler = vm.envAddress("L1_HANDLER");
    address internal immutable l2Handler = vm.envAddress("L2_HANDLER");

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
        console2.log("L1 Handler:", l1Handler);
        console2.log("L2 Handler:", l2Handler);
        console2.log("");

        // Set L1 handler on L2
        CrossChainSwapHandlerL2(payable(l2Handler)).setL1Handler(l1Handler);
        console2.log("Set L1Handler on L2Handler");

        console2.log("");
        console2.log("=====================================");
        console2.log("Setup Complete");
        console2.log("=====================================");
        console2.log("");
        console2.log("Cross-Chain DEX is now fully configured!");
    }
}
