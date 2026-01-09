// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { DeployCapability } from "test/shared/DeployCapability.sol";

/// @title SetupRisc0Verifier
/// @notice Script to setup Risc0 verifier with trusted image IDs and transfer ownership
contract SetupRisc0Verifier is Script, DeployCapability {
    // Configuration
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // Risc0 verifier configuration
    address internal immutable risc0VerifierAddress = vm.envAddress("RISC0_VERIFIER_ADDRESS");
    bytes32 internal immutable risc0BlockProvingImageId =
        vm.envBytes32("RISC0_BLOCK_PROVING_IMAGE_ID");
    bytes32 internal immutable risc0AggregationImageId =
        vm.envBytes32("RISC0_AGGREGATION_IMAGE_ID");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(risc0VerifierAddress != address(0), "config: RISC0_VERIFIER_ADDRESS");
        require(risc0BlockProvingImageId != bytes32(0), "config: RISC0_BLOCK_PROVING_IMAGE_ID");
        require(risc0AggregationImageId != bytes32(0), "config: RISC0_AGGREGATION_IMAGE_ID");

        Risc0Verifier risc0Verifier = Risc0Verifier(risc0VerifierAddress);

        // Verify current ownership
        require(risc0Verifier.owner() == msg.sender, "SetupRisc0Verifier: not owner");

        // Setup trusted image IDs
        risc0Verifier.setImageIdTrusted(risc0BlockProvingImageId, true);
        console2.log("** Set block proving image ID as trusted:", uint256(risc0BlockProvingImageId));

        risc0Verifier.setImageIdTrusted(risc0AggregationImageId, true);
        console2.log("** Set aggregation image ID as trusted:", uint256(risc0AggregationImageId));

        console2.log("** Risc0 verifier setup complete **");
    }
}
