// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "test/shared/DeployCapability.sol";

/// @title SetupSP1Verifier
/// @notice Script to setup SP1 verifier with trusted program verification keys and transfer
/// ownership
contract SetupSP1Verifier is Script, DeployCapability {
    // Configuration
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // SP1 verifier configuration
    address internal immutable sp1VerifierAddress = vm.envAddress("SP1_VERIFIER_ADDRESS");
    bytes32 internal immutable sp1BlockProvingProgramVKey =
        vm.envBytes32("SP1_BLOCK_PROVING_PROGRAM_VKEY");
    bytes32 internal immutable sp1AggregationProgramVKey =
        vm.envBytes32("SP1_AGGREGATION_PROGRAM_VKEY");

    // Ownership transfer
    address internal immutable newOwner = vm.envAddress("NEW_OWNER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(sp1VerifierAddress != address(0), "config: SP1_VERIFIER_ADDRESS");
        require(sp1BlockProvingProgramVKey != bytes32(0), "config: SP1_BLOCK_PROVING_PROGRAM_VKEY");
        require(sp1AggregationProgramVKey != bytes32(0), "config: SP1_AGGREGATION_PROGRAM_VKEY");
        require(newOwner != address(0), "config: NEW_OWNER");

        SP1Verifier sp1Verifier = SP1Verifier(sp1VerifierAddress);

        // Verify current ownership
        require(sp1Verifier.owner() == msg.sender, "SetupSP1Verifier: not owner");

        // Setup trusted program verification keys
        sp1Verifier.setProgramTrusted(sp1BlockProvingProgramVKey, true);
        console2.log(
            "** Set block proving program VKey as trusted:", uint256(sp1BlockProvingProgramVKey)
        );

        sp1Verifier.setProgramTrusted(sp1AggregationProgramVKey, true);
        console2.log(
            "** Set aggregation program VKey as trusted:", uint256(sp1AggregationProgramVKey)
        );

        // Transfer ownership
        sp1Verifier.transferOwnership(newOwner);
        console2.log("** SP1Verifier ownership transferred to:", newOwner);

        console2.log("** SP1 verifier setup complete **");
    }
}
