// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/provers/ProverSet.sol";
import "script/BaseScript.sol";

contract DeployProverSet is BaseScript {
    function run() external broadcast {
        address owner = vm.envOr("OWNER", msg.sender);
        address admin = vm.envOr("ADMIN", msg.sender);
        address impl = vm.envOr("PROVER_SET_IMPL", address(new ProverSet()));

        require(owner != address(0), "OWNER not set");
        require(admin != address(0), "ADMIN not set");

        deploy({
            name: "",
            impl: impl,
            data: abi.encodeCall(ProverSet.init, (owner, admin, resolver))
        });
    }
}
