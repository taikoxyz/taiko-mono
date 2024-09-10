// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import "../../test/shared/DeployCapability.sol";
import "../../contracts/layer1/verifiers/Risc0Verifier.sol";

contract DeployRisc0Verifier is DeployCapability {
    uint256 public deployerPrivKey = vm.envUint("PRIVATE_KEY");
    address public rollupAddressManager = vm.envAddress("ROLLUP_ADDRESS_MANAGER");

    function run() external {
        require(deployerPrivKey != 0, "invalid deployer priv key");
        require(rollupAddressManager != address(0), "invalid rollup address manager address");

        vm.startBroadcast(deployerPrivKey);
        RiscZeroGroth16Verifier verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
        register(rollupAddressManager, "risc0_groth16_verifier", address(verifier));
        deployProxy({
            name: "tier_zkvm_risc0",
            impl: address(new Risc0Verifier()),
            data: abi.encodeCall(Risc0Verifier.init, (address(0), rollupAddressManager)),
            registerTo: rollupAddressManager
        });
        vm.stopBroadcast();
    }
}
