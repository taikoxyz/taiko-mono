// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/provers/ProverSet.sol";
import "script/BaseScript.sol";

contract DeployProverSet is BaseScript {
    function run() external broadcast {
        address owner = vm.envOr("OWNER", msg.sender);
        address admin = vm.envOr("ADMIN", msg.sender);

        require(owner != address(0), "invalid owner address");
        require(admin != address(0), "invalid admin address");
        require(resolver != address(0), "invalid resolver address");

        address proverSet = address(new ProverSet());

        address proxy = deploy({
            name: "prover_set",
            impl: proverSet,
            data: abi.encodeCall(ProverSet.init, (owner, admin, resolver))
        });

        console2.log();
        console2.log("Deployed ProverSet impl at address: %s", proverSet);
        console2.log("Deployed ProverSet proxy at address: %s", proxy);
    }
}
