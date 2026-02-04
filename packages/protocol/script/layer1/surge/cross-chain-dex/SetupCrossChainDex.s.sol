// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { CrossChainSwapHandlerL1 } from
    "../../../../contracts/layer1/surge/cross-chain-dex/CrossChainSwapHandlerL1.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title SetupCrossChainDex
/// @notice Script to link L1 and L2 handlers after deployment
contract SetupCrossChainDex is Script {
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
        console2.log("Setting up Cross-Chain DEX");
        console2.log("=====================================");
        console2.log("L1 Handler:", l1Handler);
        console2.log("L2 Handler:", l2Handler);
        console2.log("");

        // Set L2 handler on L1
        CrossChainSwapHandlerL1(payable(l1Handler)).setL2Handler(l2Handler);
        console2.log("Set L2Handler on L1Handler");

        console2.log("");
        console2.log("=====================================");
        console2.log("Setup Complete");
        console2.log("=====================================");
        console2.log("");
        console2.log("Don't forget to also set L1Handler on L2Handler using L2 RPC!");
    }
}
