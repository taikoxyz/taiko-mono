// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol"; // RiscZeroGroth16Verifier + ControlID
import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/v6.1.0/SP1VerifierPlonk.sol";
import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import { MainnetVerifier } from "src/layer1/mainnet/MainnetVerifier.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";

/// @title DeployProofStack
/// @notice Abstract base for the focused proof-verification deploy — the two SGX verifiers, the
/// Risc0 and SP1 verifiers, and the MainnetVerifier that aggregates them — wired to a pre-deployed
/// Taiko-owned AutomataDcapAttestationFee entrypoint (env `DCAP_ATTESTATION`). Per-network
/// constants are supplied by subclasses via `_config()`. It does NOT deploy the entrypoint (see
/// DeployAutomataDcapAttestation) nor the inbox / signal service / whitelists (see
/// DeployShastaHoodi / DeployShastaMainnet). Runs under FOUNDRY_PROFILE=layer1.
/// @custom:security-contact security@taiko.xyz
abstract contract DeployProofStack is Script {
    /// @dev Per-network verifier dimensions supplied by subclasses.
    struct Config {
        uint64 chainId;
        address owner;
        uint64 validityDelay;
        address r0Groth16;
        address sp1Plonk;
    }

    struct ProofStack {
        address sgxReth;
        address sgxGeth;
        address risc0;
        address sp1;
        address mainnetVerifier;
    }

    /// @dev Returns the network-specific verifier dimensions.
    /// @return The per-network Config.
    function _config() internal view virtual returns (Config memory);

    /// @notice Deploys the proof-verification stack wired to the `DCAP_ATTESTATION` entrypoint.
    /// @return stack_ The deployed proof-stack addresses.
    function run() external returns (ProofStack memory stack_) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address dcapAttestation = vm.envAddress("DCAP_ATTESTATION");
        address deployer = vm.addr(privateKey);
        // The SGX registrar (the only address allowed to call `registerInstance`) is configurable
        // via env, defaulting to the deployer (the broadcast signer). Set SGX_REGISTRAR to a
        // durable owner (e.g. a multisig), or to address(0) for permissionless registration.
        address registrar = vm.envOr("SGX_REGISTRAR", deployer);

        Config memory cfg = _config();
        // The underlying RiscZero Groth16 / SP1 Plonk verifiers are configurable via env, defaulting
        // to the network's config value; address(0) (Mainnet's default) means deploy fresh.
        cfg.r0Groth16 = vm.envOr("R0_GROTH16", cfg.r0Groth16);
        cfg.sp1Plonk = vm.envOr("SP1_PLONK", cfg.sp1Plonk);

        vm.startBroadcast(privateKey);
        stack_ = _deployProofStack(cfg, dcapAttestation, registrar);
        vm.stopBroadcast();

        console2.log("SgxVerifier (reth) deployed:", stack_.sgxReth);
        console2.log("SgxGethVerifier deployed:", stack_.sgxGeth);
        console2.log("Risc0Verifier deployed:", stack_.risc0);
        console2.log("SP1Verifier deployed:", stack_.sp1);
        console2.log("MainnetVerifier deployed:", stack_.mainnetVerifier);
    }

    /// @dev Deploys the four tier verifiers and the MainnetVerifier that aggregates them, all wired
    /// to `_dcapAttestation`. Mirrors DeployShastaContracts._deployAllVerifiers (self-contained).
    /// @param _cfg The per-network verifier dimensions.
    /// @param _dcapAttestation The Taiko-owned AutomataDcapAttestationFee entrypoint shared by both
    /// SGX instances.
    /// @param _registrar The SGX registrar (the only address allowed to call `registerInstance`).
    /// @return stack_ The deployed proof-stack addresses.
    function _deployProofStack(
        Config memory _cfg,
        address _dcapAttestation,
        address _registrar
    )
        internal
        returns (ProofStack memory stack_)
    {
        require(_dcapAttestation != address(0), "DCAP_ATTESTATION not set");

        // Both SGX instances share the one Taiko-owned entrypoint (the #21827 shared-entrypoint
        // model). 1h/24h instance-validity delay per network.
        stack_.sgxReth = address(
            new SecureSgxVerifier(
                _cfg.chainId, _cfg.owner, _dcapAttestation, _registrar, _cfg.validityDelay
            )
        );
        stack_.sgxGeth = address(
            new SecureSgxVerifier(
                _cfg.chainId, _cfg.owner, _dcapAttestation, _registrar, _cfg.validityDelay
            )
        );
        // Deploy fresh underlying verifiers when the config address is zero (Mainnet's default),
        // else wrap the configured/live one. Mirrors DeployProtocolOnL1._deployZKVerifiers.
        address r0Groth16 = _cfg.r0Groth16 == address(0)
            ? address(
                new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID)
            )
            : _cfg.r0Groth16;
        address sp1Plonk =
            _cfg.sp1Plonk == address(0) ? address(new SuccinctVerifier()) : _cfg.sp1Plonk;
        stack_.risc0 = address(new Risc0Verifier(_cfg.chainId, r0Groth16, _cfg.owner));
        stack_.sp1 = address(new SP1Verifier(_cfg.chainId, sp1Plonk, _cfg.owner));
        stack_.mainnetVerifier =
            address(new MainnetVerifier(stack_.sgxGeth, stack_.sgxReth, stack_.risc0, stack_.sp1));
    }
}
