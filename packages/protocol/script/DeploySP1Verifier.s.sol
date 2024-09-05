// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../contracts/verifiers/SP1Verifier.sol";
import "../test/DeployCapability.sol";

contract DeploySP1Verifier is DeployCapability {
    // On mainnet, rollup specific address manager is as follows.
    address public addressManager = 0x579f40D0BE111b823962043702cabe6Aaa290780;

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // address sp1RemoteVerifierOrGateway = vm.envOr("SP1_REMOTE_VERIFIER_GATEWAY", address(0));
        // // address(0)
        // is fine, we can set it later
        address owner = vm.envOr("SP1_VERIFIER_OWNER", msg.sender);

        address sp1Verifier = address(new SP1Verifier());

        address proxy = deployProxy({
            name: "sp1_verifier",
            impl: sp1Verifier,
            data: abi.encodeCall(SP1Verifier.init, (owner, addressManager))
        });

        console2.log();
        console2.log("Deployed SP1Verifier impl at address: %s", sp1Verifier);
        console2.log("Deployed SP1Verifier proxy at address: %s", proxy);
    }
}
