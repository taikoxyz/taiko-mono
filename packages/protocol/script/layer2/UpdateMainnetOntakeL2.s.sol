// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/DeployCapability.sol";
import "src/layer2/mainnet/MainnetTaikoL2.sol";

contract UpgradeMainnetOntakeL2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // MainnetTaikoL2
        console2.log(address(new MainnetTaikoL2()));
    }
}
