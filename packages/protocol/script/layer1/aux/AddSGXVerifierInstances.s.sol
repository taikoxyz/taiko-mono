// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/verifiers/SgxVerifier.sol";
import "script/BaseScript.sol";

contract AddSGXVerifierInstances is BaseScript {
    address public sgxVerifier = vm.envAddress("SGX_VERIFIER");
    address[] public instances = vm.envAddress("INSTANCES", ",");

    function run() external broadcast {
        require(instances.length != 0, "invalid instances");

        SgxVerifier(sgxVerifier).addInstances(instances);

        for (uint256 i; i < instances.length; ++i) {
            console2.log("instance", i, "added ", instances[0]);
        }
    }
}
