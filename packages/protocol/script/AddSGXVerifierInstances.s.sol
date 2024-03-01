// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/L1/gov/TaikoTimelockController.sol";
import "../contracts/verifiers/SgxVerifier.sol";

contract AddSGXVerifierInstances is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
    address public sgxVerifier = vm.envAddress("SGX_VERIFIER");
    address[] public instances = vm.envAddress("INSTANCES", ",");

    function run() external {
        require(instances.length != 0, "invalid instances");

        vm.startBroadcast(privateKey);

        updateInstancesByTimelock(timelockAddress);

        vm.stopBroadcast();
    }

    function updateInstancesByTimelock(address timelock) internal {
        bytes32 salt = bytes32(block.timestamp);

        bytes memory payload =
            abi.encodeWithSelector(bytes4(keccak256("addInstances(address[])")), instances);

        TaikoTimelockController timelockController = TaikoTimelockController(payable(timelock));

        timelockController.schedule(sgxVerifier, 0, payload, bytes32(0), salt, 0);

        timelockController.execute(sgxVerifier, 0, payload, bytes32(0), salt);

        for (uint256 i; i < instances.length; ++i) {
            console2.log("New instance added:");
            console2.log("index: ", i);
            console2.log("instance: ", instances[0]);
        }
    }
}
