// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Multicall } from "../../../contracts/shared/common/Multicall.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title DeployMulticall
/// @notice Script to deploy the Multicall contract.
contract DeployMulticall is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast returns (address multicall_) {
        console2.log("=====================================");
        console2.log("Deploying Multicall");
        console2.log("=====================================");

        Multicall multicall = new Multicall();
        multicall_ = address(multicall);

        console2.log("Multicall deployed at:", multicall_);
        writeJson("Multicall", multicall_);

        console2.log("=====================================");
        console2.log("Deployment Complete");
        console2.log("=====================================");
    }

    /// @dev Writes an address to the deployment JSON file
    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/composability.json")
        );
    }
}
