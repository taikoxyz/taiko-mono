// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { L1Sender } from "./L1Sender.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title DeployL1Sender
/// @notice Script to deploy the L1Sender contract on L1.
contract DeployL1Sender is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal immutable bridge = vm.envAddress("L1_BRIDGE");
    uint64 internal immutable l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast returns (address l1Sender_) {
        console2.log("=====================================");
        console2.log("Deploying L1Sender");
        console2.log("=====================================");
        console2.log("Bridge address:", bridge);
        console2.log("L2 Chain ID:", l2ChainId);
        console2.log("");

        L1Sender l1Sender = new L1Sender(bridge, l2ChainId);
        l1Sender_ = address(l1Sender);

        console2.log("L1Sender deployed at:", l1Sender_);
        writeJson("L1Sender", l1Sender_);

        console2.log("=====================================");
        console2.log("Deployment Complete");
        console2.log("=====================================");
    }

    /// @dev Writes an address to the deployment JSON file
    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/bridge-examples.json")
        );
    }
}
