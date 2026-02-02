// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { L1Sender } from "../../../layer1/surge/examples/L1Sender.sol";
import { L2Math } from "../../../layer2/surge/examples/L2Math.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title SetupBridgeContracts
/// @notice Script to set up the bridge contracts by configuring L1Sender and L2Math with each other's addresses.
contract SetupBridgeContracts is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    /// @notice Sets the L2Math address in L1Sender (call on L1)
    function setupL1Sender() external broadcast {
        address l1Sender = vm.envAddress("L1_SENDER");
        address l2Math = vm.envAddress("L2_MATH");

        console2.log("=====================================");
        console2.log("Setting up L1Sender");
        console2.log("=====================================");
        console2.log("L1Sender address:", l1Sender);
        console2.log("L2Math address:", l2Math);
        console2.log("");

        // Set L2Math address in L1Sender
        console2.log("Setting L2Math address in L1Sender...");
        L1Sender(l1Sender).setL2Math(l2Math);
        console2.log("L1Sender.l2Math set to:", l2Math);
        console2.log("");

        console2.log("=====================================");
        console2.log("Setup Complete");
        console2.log("=====================================");
    }

    /// @notice Sets the L1Sender address in L2Math (call on L2)
    function setupL2Math() external broadcast {
        address l1Sender = vm.envAddress("L1_SENDER");
        address l2Math = vm.envAddress("L2_MATH");

        console2.log("=====================================");
        console2.log("Setting up L2Math");
        console2.log("=====================================");
        console2.log("L1Sender address:", l1Sender);
        console2.log("L2Math address:", l2Math);
        console2.log("");

        // Set L1Sender address in L2Math
        console2.log("Setting L1Sender address in L2Math...");
        L2Math(l2Math).setL1Sender(l1Sender);
        console2.log("L2Math.l1Sender set to:", l1Sender);
        console2.log("");

        console2.log("=====================================");
        console2.log("Setup Complete");
        console2.log("=====================================");
    }
}
