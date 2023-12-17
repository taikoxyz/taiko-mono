// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.20;

import "../test/DeployCapability.sol";
import "../contracts/L1/gov/TaikoTimelockController.sol";
import "../contracts/L1/verifiers/SgxVerifier.sol";

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
