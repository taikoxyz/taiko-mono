// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import { MainnetVerifier } from "src/layer1/mainnet/MainnetVerifier.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeployHoodiProofStack
/// @notice Deploys only the Hoodi proof-verification contracts — the two SGX verifiers, the Risc0
/// and SP1 verifiers, and the MainnetVerifier that aggregates them — wired to a pre-deployed
/// Taiko-owned AutomataDcapAttestationFee entrypoint (env `DCAP_ATTESTATION`). A focused sibling of
/// DeployShastaHoodi: it does NOT deploy the entrypoint (see DeployAutomataDcapAttestation) nor the
/// inbox / signal service / whitelists (see DeployShastaHoodi). Runs under FOUNDRY_PROFILE=layer1.
/// @custom:security-contact security@taiko.xyz
contract DeployHoodiProofStack is Script {
    uint64 internal constant CHAIN_ID = LibNetwork.TAIKO_HOODI;
    address internal constant OWNER = LibL1HoodiAddrs.HOODI_CONTRACT_OWNER;
    uint64 internal constant VALIDITY_DELAY = 1 hours;
    // Hoodi verifier dependencies, mirroring DeployShastaHoodi._loadConfig.
    address internal constant R0_GROTH16 = 0x32Db7dc407AC886807277636a1633A1381748DD8;
    address internal constant SP1_PLONK = 0x2a5A70409Ee9F057503a50E0F4614A6d8CcBb462;

    struct ProofStack {
        address sgxReth;
        address sgxGeth;
        address risc0;
        address sp1;
        address mainnetVerifier;
    }

    /// @notice Deploys the Hoodi proof-verification stack wired to the `DCAP_ATTESTATION` entrypoint.
    /// @return stack_ The deployed proof-stack addresses.
    function run() external returns (ProofStack memory stack_) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address dcapAttestation = vm.envAddress("DCAP_ATTESTATION");
        // The deployer (broadcast signer) is set as the SGX registrar (see _deployProofStack).
        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        stack_ = _deployProofStack(dcapAttestation, deployer);
        vm.stopBroadcast();

        console2.log("SgxVerifier (reth) deployed:", stack_.sgxReth);
        console2.log("SgxGethVerifier deployed:", stack_.sgxGeth);
        console2.log("Risc0Verifier deployed:", stack_.risc0);
        console2.log("SP1Verifier deployed:", stack_.sp1);
        console2.log("MainnetVerifier deployed:", stack_.mainnetVerifier);
    }

    /// @dev Deploys the four tier verifiers and the MainnetVerifier that aggregates them, all wired
    /// to `_dcapAttestation`. Mirrors DeployShastaContracts._deployAllVerifiers (kept self-contained).
    /// @param _dcapAttestation The Taiko-owned AutomataDcapAttestationFee entrypoint shared by both
    /// SGX instances.
    /// @param _registrar The SGX registrar (the only address allowed to call `registerInstance`).
    /// @return stack_ The deployed proof-stack addresses.
    function _deployProofStack(
        address _dcapAttestation,
        address _registrar
    )
        internal
        returns (ProofStack memory stack_)
    {
        require(_dcapAttestation != address(0), "DCAP_ATTESTATION not set");

        // Both SGX instances share the one Taiko-owned entrypoint (the #21827 shared-entrypoint
        // model). The registrar (the deployer) is the only address allowed to registerInstance
        // (defense-in-depth); 1h instance-validity delay.
        stack_.sgxReth = address(
            new SecureSgxVerifier(CHAIN_ID, OWNER, _dcapAttestation, _registrar, VALIDITY_DELAY)
        );
        stack_.sgxGeth = address(
            new SecureSgxVerifier(CHAIN_ID, OWNER, _dcapAttestation, _registrar, VALIDITY_DELAY)
        );
        stack_.risc0 = address(new Risc0Verifier(CHAIN_ID, R0_GROTH16, OWNER));
        stack_.sp1 = address(new SP1Verifier(CHAIN_ID, SP1_PLONK, OWNER));
        stack_.mainnetVerifier =
            address(new MainnetVerifier(stack_.sgxGeth, stack_.sgxReth, stack_.risc0, stack_.sp1));
    }
}
