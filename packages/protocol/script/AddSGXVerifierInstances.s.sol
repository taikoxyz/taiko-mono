// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../test/DeployCapability.sol";
import "../contracts/verifiers/SgxVerifier.sol";

contract AddSGXVerifierInstances is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public sgxVerifier = vm.envAddress("SGX_VERIFIER");
    address[] public instances = vm.envAddress("INSTANCES", ",");

    function run() external {
        require(instances.length != 0, "invalid instances");

        vm.startBroadcast(privateKey);

        SgxVerifier(sgxVerifier).addInstances(instances);

        for (uint256 i; i < instances.length; ++i) {
            console2.log("New instance added:");
            console2.log("index: ", i);
            console2.log("instance: ", instances[0]);
        }

        vm.stopBroadcast();
    }
}
