// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../test/shared/DeployCapability.sol";
import "../../contracts/layer1/verifiers/ProverRegistryVerifier.sol";

contract DeployProverRegistryVerifier is DeployCapability {
    uint256 public deployerPrivKey = vm.envUint("PRIVATE_KEY");
    address public rollupAddressManager = vm.envAddress("ROLLUP_ADDRESS_MANAGER");
    address public attestationVerifier = vm.envAddress("ATTESTATION_VERIFIER");
    uint256 public attestationValiditySeconds = vm.envUint("ATTEST_VALIDITY_SECONDS");
    uint256 public maxBlockNumberDiff = vm.envUint("MAX_BLOCK_NUMBER_DIFF");

    function run() external {
        require(deployerPrivKey != 0, "invalid deployer priv key");
        require(rollupAddressManager != address(0), "invalid rollup address manager address");

        vm.startBroadcast(deployerPrivKey);

        // Deploy Prover Registry Verifier
        ProverRegistryVerifier proverRegistryVerifier = new ProverRegistryVerifier();

        deployProxy({
            name: "tier_tdx",
            impl: address(proverRegistryVerifier),
            data: abi.encodeCall(ProverRegistryVerifier.init, (msg.sender, rollupAddressManager, attestationVerifier, attestationValiditySeconds, maxBlockNumberDiff)),
            registerTo: rollupAddressManager
        });

        vm.stopBroadcast();
    }
}