// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { L2Math } from "./L2Math.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title DeployL2Math
/// @notice Script to deploy the L2Math contract on L2.
contract DeployL2Math is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal immutable bridge = vm.envAddress("L2_BRIDGE");
    uint64 internal immutable l1ChainId = uint64(vm.envUint("L1_CHAIN_ID"));

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast returns (address l2Math_) {
        console2.log("=====================================");
        console2.log("Deploying L2Math");
        console2.log("=====================================");
        console2.log("Bridge address:", bridge);
        console2.log("L1 Chain ID:", l1ChainId);
        console2.log("");

        L2Math l2Math = new L2Math(bridge, l1ChainId);
        l2Math_ = address(l2Math);

        console2.log("L2Math deployed at:", l2Math_);
        writeJson("L2Math", l2Math_);

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
