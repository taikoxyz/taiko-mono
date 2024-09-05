// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../contracts/team/proving/ProverSet.sol";
import "../test/DeployCapability.sol";

contract DeployProverSet is DeployCapability {
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address owner = vm.envOr("PROVER_SET_OWNER", msg.sender);
        address admin = vm.envOr("PROVER_SET_ADMIN", msg.sender);
        address addressManager = vm.envAddress("ROLLUP_ADDRESS_MANAGER");

        addressNotNull(owner, "invalid owner address");
        addressNotNull(admin, "invalid admin address");
        addressNotNull(addressManager, "invalid rollup address manager address");

        address proverSet = address(new ProverSet());

        address proxy = deployProxy({
            name: "prover_set",
            impl: proverSet,
            data: abi.encodeCall(ProverSet.init, (owner, admin, addressManager))
        });

        console2.log();
        console2.log("Deployed ProverSet impl at address: %s", proverSet);
        console2.log("Deployed ProverSet proxy at address: %s", proxy);
    }

    function addressNotNull(address addr, string memory err) private pure {
        require(addr != address(0), err);
    }
}
