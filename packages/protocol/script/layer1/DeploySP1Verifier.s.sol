// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SP1Verifier as SP1Verifier120rc } from "@sp1-contracts/src/v1.2.0-rc/SP1VerifierPlonk.sol";
import "../../test/shared/DeployCapability.sol";
import "../../contracts/layer1/verifiers/SP1Verifier.sol";

contract DeploySP1Verifier is DeployCapability {
    uint256 public deployerPrivKey = vm.envUint("PRIVATE_KEY");
    address public rollupAddressManager = vm.envAddress("ROLLUP_ADDRESS_MANAGER");

    function run() external {
        require(deployerPrivKey != 0, "invalid deployer priv key");
        require(rollupAddressManager != address(0), "invalid rollup address manager address");

        vm.startBroadcast(deployerPrivKey);

        // Deploy sp1 plonk verifier
        SP1Verifier120rc sp1Verifier120rc = new SP1Verifier120rc();
        register(rollupAddressManager, "sp1_remote_verifier", address(sp1Verifier120rc));

        deployProxy({
            name: "tier_zkvm_sp1",
            impl: address(new SP1Verifier()),
            data: abi.encodeCall(SP1Verifier.init, (address(0), rollupAddressManager)),
            registerTo: rollupAddressManager
        });

        vm.stopBroadcast();
    }
}
