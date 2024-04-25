// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "../contracts/L1/provers/GuardianProver.sol";

contract SetGuardians is Script {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
    address public guardianProverAddress = vm.envAddress("GUARDIAN_PROVER");
    address[] public guardians = vm.envAddress("GUARDIANS", ",");
    uint256 public minGuardians = vm.envUint("MIN_GUARDIANS");

    function run() external {
        vm.startBroadcast(privateKey);

        GuardianProver proxy = GuardianProver(payable(guardianProverAddress));

        proxy.setGuardians(guardians, uint8(minGuardians));

        vm.stopBroadcast();
    }
}
