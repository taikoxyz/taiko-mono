// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    UserOpsSubmitterFactory
} from "../../../contracts/shared/userops/UserOpsSubmitterFactory.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title DeployUserOpsSubmitter
/// @notice Script to deploy UserOpsSubmitterFactory and optionally create a UserOpsSubmitter via
/// the factory.
/// @dev If OWNER_ADDRESS is set, creates a submitter for that owner via the factory.
contract DeployUserOpsSubmitter is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal owner = vm.envOr("OWNER_ADDRESS", address(0));

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast returns (address factory_, address submitter_) {
        console2.log("=====================================");
        console2.log("Deploying UserOpsSubmitterFactory");
        console2.log("=====================================");

        UserOpsSubmitterFactory factory = new UserOpsSubmitterFactory();
        factory_ = address(factory);

        console2.log("Factory deployed at:", factory_);

        if (owner != address(0)) {
            console2.log("");
            console2.log("Creating UserOpsSubmitter for owner:", owner);
            submitter_ = factory.createSubmitter(owner);
            console2.log("UserOpsSubmitter created at:", submitter_);
        } else {
            console2.log("");
            console2.log("No OWNER_ADDRESS set, skipping submitter creation");
        }

        console2.log("=====================================");
        console2.log("Deployment Complete");
        console2.log("=====================================");
    }
}
