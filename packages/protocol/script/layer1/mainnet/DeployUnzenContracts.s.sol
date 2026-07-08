// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { ZkRequiredVerifier } from "src/layer1/verifiers/compose/ZkRequiredVerifier.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeployUnzenContracts
/// @notice Deploys the mainnet implementation contracts for the Unzen hardfork bundle.
/// @dev This script deploys new contracts only. It does not upgrade proxies or call
/// initializers; the DAO proposal performs the Inbox upgrade, `init3`, and the SGX verifier
/// trust configuration after reviewing the logged addresses.
///
/// PREREQUISITE: the upstream Automata DCAP attestation entrypoint must already be deployed —
/// run `DeployAutomataDcapAttestation` first (under `FOUNDRY_PROFILE=layer1o`; the upstream
/// Automata code only compiles with via_ir, see foundry.toml) and pass its logged address via
/// the `DCAP_ATTESTATION` env var. This script reverts if it is unset or has no code.
///
/// The verifier wiring is immutable at every level (SgxVerifier -> attestation,
/// ZkRequiredVerifier -> sub-verifiers, Inbox -> proof verifier), so the chain deploys
/// bottom-up:
///
/// 1. Two new `SecureSgxVerifier` instances (SGX-geth and SGX-reth) wired to the same upstream
///    attestation entrypoint. They replace the Proposal0017 verifiers (immutably wired to the
///    old pre-incident vendored attestation) and carry the post-v3.1.0 hardening: permanent
///    MRENCLAVE/MRSIGNER untrust, uint32 instance-id overflow rejection, and the
///    quote-freshness gate. Both deploy fail-closed: no instance can register until the DAO
///    trusts an MRENCLAVE and MRSIGNER (proposal actions) and the registrar registers the
///    raiko instances post-execution.
/// 2. `ZkRequiredVerifier` replaces `MainnetVerifier`: two sub-proofs with at least one ZK
///    proof ((SGX_GETH|SGX_RETH)+RISC0, (SGX_GETH|SGX_RETH)+SP1, or RISC0+SP1) — the
///    SGX-geth + SGX-reth (zero ZK) combination no longer exists.
/// 3. A new `MainnetInbox` implementation with forced inclusions re-enabled, wired to the new
///    verifier. `init3` voids the stale pre-incident forced inclusion queue entry whose blob
///    has expired from the blob retention window.
/// @custom:security-contact security@taiko.xyz
contract DeployUnzenContracts is Script {
    /// @dev Matches the Proposal0017 SecureSgxVerifier deployment parameters.
    uint64 private constant _INSTANCE_VALIDITY_DELAY = 24 hours;

    struct Deployment {
        address dcapAttestation;
        address sgxGethVerifier;
        address sgxRethVerifier;
        address zkRequiredVerifier;
        address mainnetInboxImpl;
    }

    /// @notice Deploys the implementation contracts and logs their addresses.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        // The upstream Automata DCAP attestation entrypoint (AutomataDcapAttestationFee),
        // deployed beforehand by DeployAutomataDcapAttestation under FOUNDRY_PROFILE=layer1o.
        address dcapAttestation = vm.envAddress("DCAP_ATTESTATION");
        require(dcapAttestation != address(0), "DCAP_ATTESTATION not set");
        require(dcapAttestation.code.length != 0, "DCAP_ATTESTATION has no code");

        vm.startBroadcast(privateKey);
        Deployment memory deployment = _deployImplementations(dcapAttestation);
        vm.stopBroadcast();

        _logDeployment(deployment);
    }

    function _deployImplementations(address _dcapAttestation)
        private
        returns (Deployment memory deployment_)
    {
        deployment_.dcapAttestation = _dcapAttestation;

        // New SGX verifiers (geth + reth) on the hardened SgxVerifier, both verifying quotes
        // against the same upstream Automata entrypoint (unlike the old vendored setup, the
        // MRENCLAVE/MRSIGNER allowlists live in each verifier, not the attestation, so one
        // entrypoint serves both). The contracts are identical; each becomes geth- or
        // reth-flavored through the ZkRequiredVerifier slot it occupies below, the raiko
        // measurements the DAO trusts on it, and the raiko instances that register on it.
        // Same owner/registrar/delay as Proposal0017.
        deployment_.sgxGethVerifier = address(
            new SecureSgxVerifier(
                LibNetwork.TAIKO_MAINNET,
                LibL1Addrs.DAO_CONTROLLER,
                _dcapAttestation,
                LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH,
                _INSTANCE_VALIDITY_DELAY
            )
        );

        deployment_.sgxRethVerifier = address(
            new SecureSgxVerifier(
                LibNetwork.TAIKO_MAINNET,
                LibL1Addrs.DAO_CONTROLLER,
                _dcapAttestation,
                LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH,
                _INSTANCE_VALIDITY_DELAY
            )
        );

        deployment_.zkRequiredVerifier = address(
            new ZkRequiredVerifier(
                deployment_.sgxGethVerifier,
                deployment_.sgxRethVerifier,
                LibL1Addrs.RISC0_RETH_VERIFIER,
                LibL1Addrs.SP1_RETH_VERIFIER
            )
        );

        deployment_.mainnetInboxImpl = address(
            new MainnetInbox(
                deployment_.zkRequiredVerifier,
                LibL1Addrs.PRECONF_WHITELIST,
                LibL1Addrs.PROVER_WHITELIST,
                LibL1Addrs.SIGNAL_SERVICE,
                LibL1Addrs.TAIKO_TOKEN
            )
        );
    }

    function _logDeployment(Deployment memory _deployment) private pure {
        console2.log("DCAP_ATTESTATION (input):", _deployment.dcapAttestation);
        console2.log("SGXGETH_VERIFIER_NEW:", _deployment.sgxGethVerifier);
        console2.log("SGXRETH_VERIFIER_NEW:", _deployment.sgxRethVerifier);
        console2.log("ZK_REQUIRED_VERIFIER:", _deployment.zkRequiredVerifier);
        console2.log("MAINNET_INBOX_NEW_IMPL:", _deployment.mainnetInboxImpl);
        console2.log("RISC0_RETH_VERIFIER (reused):", LibL1Addrs.RISC0_RETH_VERIFIER);
        console2.log("SP1_RETH_VERIFIER (reused):", LibL1Addrs.SP1_RETH_VERIFIER);
        console2.log("NOTE: the new SGX verifier has no registered instances; after the DAO");
        console2.log("proposal executes (trust config), the registrar must registerInstance.");
        console2.log("RISC0+SP1 keeps proving alive until SGX registration completes.");
    }
}
