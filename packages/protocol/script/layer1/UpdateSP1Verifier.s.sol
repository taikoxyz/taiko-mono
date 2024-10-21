// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@sp1-contracts/src/v3.0.0-rc3/SP1VerifierPlonk.sol";
import "test/shared/DeployCapability.sol";

contract UpdateSP1Verifier is DeployCapability {
    uint256 public deployerPrivKey = vm.envUint("PRIVATE_KEY");
    address public rollupAddressManager = vm.envAddress("ROLLUP_ADDRESS_MANAGER");

    function run() external {
        require(deployerPrivKey != 0, "invalid deployer priv key");
        require(rollupAddressManager != address(0), "invalid rollup address manager address");

        vm.startBroadcast(deployerPrivKey);

        // Deploy sp1 plonk verifier
        SP1Verifier sp1Verifier = new SP1Verifier();
        register(rollupAddressManager, "sp1_remote_verifier", address(sp1Verifier));

        vm.stopBroadcast();
    }
}
