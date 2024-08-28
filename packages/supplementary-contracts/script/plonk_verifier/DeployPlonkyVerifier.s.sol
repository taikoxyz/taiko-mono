// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "../../contracts/plonk_verifier/SP1VerifierPlonk.sol";

contract DeployPlonkyVerifier is Script {
    function run() external {
        vm.startBroadcast();

        address deployedRemoteVerifier = address(new SP1Verifier());
        console2.log("Deployed remote verifier address:", deployedRemoteVerifier);

        vm.stopBroadcast();
    }
}
