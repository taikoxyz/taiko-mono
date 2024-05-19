// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/team/proving/ProverSet.sol";

contract DeployProverSet is DeployCapability {
    // contract
    address public addressManager = vm.envAddress("ADDRESS_MANAGER");

    function setUp() external { }

    function run() external {
        require(addressManager != address(0), "invalid address manager address");

        vm.startBroadcast();

        deployProxy({
            name: "ProverSet",
            impl: address(new ProverSet()),
            data: abi.encodeCall(ProverSet.init, (address(0), addressManager))
        });

        vm.stopBroadcast();
    }
}
