// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Script, console2 } from "forge-std/src/Script.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { ZkRequiredVerifier } from "src/layer1/verifiers/compose/ZkRequiredVerifier.sol";

/// @title DeployEtnaVerifiers
/// @notice Deploys dedicated Etna SGX, RISC0 and SP1 verifier instances and their ZK-required
/// composition, keeping Etna image trust separate from the Unzen Inbox's verifier instances.
/// @dev Reads PRIVATE_KEY and optional CONTRACT_OWNER (the deployer when unset or empty; an
/// explicit zero address is rejected), L1_CHAIN_ID (must match the connected chain), L2_CHAIN_ID
/// (uint64, greater than 1 and different from L1), DCAP_ATTESTATION, SGX_REGISTRAR (zero allows
/// permissionless registration), SGX_INSTANCE_VALIDITY_DELAY (uint64 seconds, positive and at
/// most SecureSgxVerifier.INSTANCE_EXPIRY), R0_GROTH16_VERIFIER and SP1_PLONK_VERIFIER. The DCAP
/// entrypoint and both remote ZK verifiers must already have code on L1. The new composition
/// disables SGX_GETH and uses the new SGX instance for SGX_RETH. This script only deploys: the
/// SGX identity allowlists, attribute policies and instances, RISC0 image trust and SP1 program
/// trust remain empty for subsequent configuration. It neither upgrades nor configures an Inbox.
/// @custom:security-contact security@taiko.xyz
contract DeployEtnaVerifiers is Script {
    /// @notice Immutable parameters supplied to the new sub-verifier instances.
    struct DeploymentConfig {
        address owner;
        uint64 l2ChainId;
        address dcapAttestation;
        address sgxRegistrar;
        uint64 instanceValidityDelay;
        address risc0RemoteVerifier;
        address sp1RemoteVerifier;
    }

    /// @notice Fresh verifier addresses; proofVerifier is the Etna Inbox's ETNA_PROOF_VERIFIER.
    struct VerifierAddresses {
        address sgxReth;
        address risc0Reth;
        address sp1Reth;
        address proofVerifier;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Deploys four fresh verifier instances and logs their deployment configuration.
    /// @dev Validates the key, chain identities, owner and external dependency code before
    /// broadcasting. SecureSgxVerifier's constructor checks the validity-delay bounds. All trust
    /// mappings retain their empty constructor state, with SGX local-report checking enabled.
    /// @return verifiers_ The new SGX, RISC0, SP1 and composed verifier addresses.
    function run() external returns (VerifierAddresses memory verifiers_) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, InvalidPrivateKey());
        DeploymentConfig memory config = _loadConfig(privateKey);

        vm.startBroadcast(privateKey);
        verifiers_.sgxReth = address(
            new SecureSgxVerifier(
                config.l2ChainId,
                config.owner,
                config.dcapAttestation,
                config.sgxRegistrar,
                config.instanceValidityDelay
            )
        );
        verifiers_.risc0Reth =
            address(new Risc0Verifier(config.l2ChainId, config.risc0RemoteVerifier, config.owner));
        verifiers_.sp1Reth =
            address(new SP1Verifier(config.l2ChainId, config.sp1RemoteVerifier, config.owner));
        verifiers_.proofVerifier = address(
            new ZkRequiredVerifier(
                address(0), verifiers_.sgxReth, verifiers_.risc0Reth, verifiers_.sp1Reth
            )
        );
        vm.stopBroadcast();

        console2.log("Deployer:", vm.addr(privateKey));
        console2.log("CONTRACT_OWNER:", config.owner);
        console2.log("L1_CHAIN_ID:", block.chainid);
        console2.log("L2_CHAIN_ID:", config.l2ChainId);
        console2.log("DCAP_ATTESTATION:", config.dcapAttestation);
        console2.log("SGX_REGISTRAR:", config.sgxRegistrar);
        console2.log("SGX_INSTANCE_VALIDITY_DELAY:", config.instanceValidityDelay);
        console2.log("R0_GROTH16_VERIFIER:", config.risc0RemoteVerifier);
        console2.log("SP1_PLONK_VERIFIER:", config.sp1RemoteVerifier);
        console2.log("SGX_VERIFIER_ADDRESS:", verifiers_.sgxReth);
        console2.log("ETNA_RISC0_RETH_VERIFIER:", verifiers_.risc0Reth);
        console2.log("ETNA_SP1_RETH_VERIFIER:", verifiers_.sp1Reth);
        console2.log("ETNA_PROOF_VERIFIER:", verifiers_.proofVerifier);
        console2.log("Configure Etna enclave policies, instances and guest image trust before use.");
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Reads deployment parameters without defaults for required variables. Optional owner
    /// parsing is strict: only an unset or empty variable falls back to the deployer.
    /// @param _privateKey The deployment key, used to derive the default owner.
    /// @return config_ Validated addresses, chain id and the range-checked validity delay.
    function _loadConfig(uint256 _privateKey)
        private
        view
        returns (DeploymentConfig memory config_)
    {
        require(vm.envUint("L1_CHAIN_ID") == block.chainid, L1ChainIdMismatch());
        config_.l2ChainId = SafeCast.toUint64(vm.envUint("L2_CHAIN_ID"));
        require(config_.l2ChainId > 1 && config_.l2ChainId != block.chainid, InvalidL2ChainId());
        config_.owner = vm.envExists("CONTRACT_OWNER")
            && bytes(vm.envString("CONTRACT_OWNER")).length != 0
            ? vm.envAddress("CONTRACT_OWNER")
            : vm.addr(_privateKey);
        require(config_.owner != address(0), InvalidOwner());
        config_.dcapAttestation = _contractAddress("DCAP_ATTESTATION");
        config_.sgxRegistrar = vm.envAddress("SGX_REGISTRAR");
        config_.instanceValidityDelay = SafeCast.toUint64(vm.envUint("SGX_INSTANCE_VALIDITY_DELAY"));
        config_.risc0RemoteVerifier = _contractAddress("R0_GROTH16_VERIFIER");
        config_.sp1RemoteVerifier = _contractAddress("SP1_PLONK_VERIFIER");
    }

    /// @dev Reads a required address and checks that it contains code on the connected chain.
    /// @param _name The deployment environment variable.
    /// @return contract_ The external dependency address.
    function _contractAddress(string memory _name) private view returns (address contract_) {
        contract_ = vm.envAddress(_name);
        require(contract_.code.length != 0, DependencyHasNoCode(_name, contract_));
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidPrivateKey();
    error InvalidOwner();
    error L1ChainIdMismatch();
    error InvalidL2ChainId();
    error DependencyHasNoCode(string name, address dependency);
}
