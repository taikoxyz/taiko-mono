// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../contracts/team/proving/ProverSet.sol";
import "../test/DeployCapability.sol";

contract DeployProverSetUtil is DeployCapability {
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Just do the impl. deployment, nothing else
        address proverSet = address(new ProverSet());
        console2.log("New impl address is:", proverSet);
    }
}
