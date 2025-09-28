// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "test/shared/DeployCapability.sol";

/// @title SetupRisc0Verifier
/// @notice Script to setup Risc0 verifier with trusted image IDs and transfer ownership
contract SetupRisc0Verifier is Script, DeployCapability {
    // Configuration
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // Risc0 verifier configuration
    address internal immutable risc0VerifierAddress = vm.envAddress("RISC0_VERIFIER_ADDRESS");
    bytes32 internal immutable risc0BlockProvingImageId =
        vm.envBytes32("RISC0_BLOCK_PROVING_IMAGE_ID");
    bytes32 internal immutable risc0AggregationImageId = vm.envBytes32("RISC0_AGGREGATION_IMAGE_ID");

    // Ownership transfer
    address internal immutable newOwner = vm.envAddress("NEW_OWNER");

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
        require(newOwner != address(0), "config: NEW_OWNER");

        Risc0Verifier risc0Verifier = Risc0Verifier(risc0VerifierAddress);

        // Verify current ownership
        require(risc0Verifier.owner() == msg.sender, "SetupRisc0Verifier: not owner");

        // Setup trusted image IDs
        risc0Verifier.setImageIdTrusted(risc0BlockProvingImageId, true);
        console2.log("** Set block proving image ID as trusted:", uint256(risc0BlockProvingImageId));

        risc0Verifier.setImageIdTrusted(risc0AggregationImageId, true);
        console2.log("** Set aggregation image ID as trusted:", uint256(risc0AggregationImageId));

        // Transfer ownership
        risc0Verifier.transferOwnership(newOwner);
        console2.log("** Risc0Verifier ownership transferred to:", newOwner);

        console2.log("** Risc0 verifier setup complete **");
    }
}
