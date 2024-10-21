// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/src/v3.0.0-rc3/SP1VerifierPlonk.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

contract DeploySP1Verifier is DeployCapability {
    uint256 public deployerPrivKey = vm.envUint("PRIVATE_KEY");
    address public rollupAddressManager = vm.envAddress("ROLLUP_ADDRESS_MANAGER");

    function run() external {
        require(deployerPrivKey != 0, "invalid deployer priv key");
        require(rollupAddressManager != address(0), "invalid rollup address manager address");

        vm.startBroadcast(deployerPrivKey);

        // Deploy sp1 plonk verifier
        SuccinctVerifier succinctVerifier = new SuccinctVerifier();
        register(rollupAddressManager, "sp1_remote_verifier", address(succinctVerifier));

        deployProxy({
            name: "tier_zkvm_sp1",
            impl: address(new SP1Verifier()),
            data: abi.encodeCall(SP1Verifier.init, (address(0), rollupAddressManager)),
            registerTo: rollupAddressManager
        });

        vm.stopBroadcast();
    }
}
