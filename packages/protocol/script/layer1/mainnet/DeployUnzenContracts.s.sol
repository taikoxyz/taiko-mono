// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/src/Script.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { AnyTwoVerifier } from "src/layer1/verifiers/compose/AnyTwoVerifier.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeployUnzenContracts
/// @notice Deploys all mainnet contracts for the Unzen hardfork bundle in one run.
/// @dev This script deploys new contracts only. It does not upgrade proxies or call
/// initializers; the DAO proposal performs the Inbox upgrade, `init3`, and the SGX verifier
/// trust configuration after reviewing the logged addresses.
///
/// PREREQUISITE: `pnpm compile:l1o` (or `FOUNDRY_PROFILE=layer1o forge build`). The upstream
/// Automata DCAP contracts only compile under the IR pipeline, which is quarantined in the
/// `layer1o` profile (via_ir alters codegen for the rest of the suite — see foundry.toml). This
/// script itself runs under the standard `layer1` profile so the Taiko contracts keep their
/// canonical non-IR bytecode, and deploys the Automata pieces from the pre-built `out/layer1o`
/// artifacts via `vm.getCode`.
///
/// The verifier wiring is immutable at every level (SgxVerifier -> attestation,
/// AnyTwoVerifier -> sub-verifiers, Inbox -> proof verifier), so the chain deploys bottom-up:
///
/// 1. `AutomataDcapAttestationFee` — the audited upstream Automata DCAP entrypoint
///    (+ `V3QuoteVerifier`, RIP-7212 P256 verifier), pointed at Automata's on-chain PCCS
///    (`PCCS_ROUTER` env). Non-upgradeable; verification fee pinned to zero (the SGX verifier's
///    `registerInstance` is non-payable); ownership handed to the DAO controller. Set the
///    `DCAP_ATTESTATION` env var to reuse an already-deployed entrypoint instead.
/// 2. A new `SecureSgxVerifier` (SGX-reth) wired to that entrypoint. This replaces the
///    Proposal0017 verifier (immutably wired to the old pre-incident vendored attestation) and
///    carries the post-v3.1.0 hardening: permanent MRENCLAVE/MRSIGNER untrust, uint32
///    instance-id overflow rejection, and the quote-freshness gate. It deploys fail-closed: no
///    instance can register until the DAO trusts an MRENCLAVE and MRSIGNER (proposal actions)
///    and the registrar registers the raiko instance post-execution.
/// 3. `AnyTwoVerifier` replaces `MainnetVerifier`: two sub-proofs with at least one ZK proof
///    (SGX+RISC0, SGX+SP1, or RISC0+SP1), removing the SGX-geth + SGX-reth (zero ZK) combination.
/// 4. A new `MainnetInbox` implementation with forced inclusions re-enabled, wired to the new
///    verifier. `init3` voids the stale pre-incident forced inclusion queue entry whose blob
///    has expired from the blob retention window.
/// @custom:security-contact security@taiko.xyz
contract DeployUnzenContracts is Script {
    /// @dev Matches the Proposal0017 SecureSgxVerifier deployment parameters.
    uint64 private constant _INSTANCE_VALIDITY_DELAY = 24 hours;

    /// @dev Pre-built layer1o (via_ir) artifacts for the upstream Automata contracts.
    string private constant _P256_ARTIFACT = "out/layer1o/P256Verifier.sol/P256Verifier.json";
    string private constant _V3_QUOTE_VERIFIER_ARTIFACT =
        "out/layer1o/V3QuoteVerifier.sol/V3QuoteVerifier.json";
    string private constant _ATTESTATION_ARTIFACT =
        "out/layer1o/AutomataDcapAttestationFee.sol/AutomataDcapAttestationFee.json";

    struct Deployment {
        address dcapAttestation;
        address sgxRethVerifier;
        address anyTwoVerifier;
        address mainnetInboxImpl;
    }

    /// @notice Deploys the Unzen bundle and logs the addresses.
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set");

        // Optional: reuse an already-deployed upstream attestation entrypoint. When unset, a
        // fresh one is deployed from the layer1o artifacts (requires PCCS_ROUTER).
        address dcapAttestation = vm.envOr("DCAP_ATTESTATION", address(0));

        vm.startBroadcast(privateKey);
        if (dcapAttestation == address(0)) {
            dcapAttestation = _deployAttestation(vm.addr(privateKey));
        } else {
            require(dcapAttestation.code.length != 0, "DCAP_ATTESTATION has no code");
        }
        Deployment memory deployment = _deployImplementations(dcapAttestation);
        vm.stopBroadcast();

        _logDeployment(deployment);
    }

    /// @dev Deploys the upstream Automata DCAP attestation stack from the layer1o artifacts:
    /// P256Verifier -> V3QuoteVerifier (wired to Automata's PCCS router) -> entrypoint. The
    /// entrypoint is initially owned by the broadcast signer so the wiring calls pass onlyOwner,
    /// then ownership is handed to the DAO controller.
    function _deployAttestation(address _deployer) private returns (address entrypoint_) {
        address pccsRouter = vm.envAddress("PCCS_ROUTER");
        require(pccsRouter != address(0), "PCCS_ROUTER not set");
        require(pccsRouter.code.length != 0, "PCCS_ROUTER has no code");

        address p256 = _deployFromArtifact(_P256_ARTIFACT, "");
        address v3QuoteVerifier =
            _deployFromArtifact(_V3_QUOTE_VERIFIER_ARTIFACT, abi.encode(p256, pccsRouter));
        entrypoint_ = _deployFromArtifact(_ATTESTATION_ARTIFACT, abi.encode(_deployer));

        IAutomataDcapAttestationFee(entrypoint_).setQuoteVerifier(v3QuoteVerifier);
        // The verification fee MUST stay zero: SgxVerifier.registerInstance is non-payable and
        // forwards zero value to this entrypoint.
        IAutomataDcapAttestationFee(entrypoint_).setBp(0);
        IAutomataDcapAttestationFee(entrypoint_).transferOwnership(LibL1Addrs.DAO_CONTROLLER);

        console2.log("P256Verifier deployed:", p256);
        console2.log("V3QuoteVerifier deployed:", v3QuoteVerifier);
    }

    function _deployImplementations(address _dcapAttestation)
        private
        returns (Deployment memory deployment_)
    {
        deployment_.dcapAttestation = _dcapAttestation;

        // New SGX-reth verifier on the hardened SgxVerifier, verifying quotes against the
        // upstream Automata entrypoint. Same owner/registrar/delay as Proposal0017.
        deployment_.sgxRethVerifier = address(
            new SecureSgxVerifier(
                LibNetwork.TAIKO_MAINNET,
                LibL1Addrs.DAO_CONTROLLER,
                _dcapAttestation,
                LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH,
                _INSTANCE_VALIDITY_DELAY
            )
        );

        deployment_.anyTwoVerifier = address(
            new AnyTwoVerifier(
                deployment_.sgxRethVerifier,
                LibL1Addrs.RISC0_RETH_VERIFIER,
                LibL1Addrs.SP1_RETH_VERIFIER
            )
        );

        deployment_.mainnetInboxImpl = address(
            new MainnetInbox(
                deployment_.anyTwoVerifier,
                LibL1Addrs.PRECONF_WHITELIST,
                LibL1Addrs.PROVER_WHITELIST,
                LibL1Addrs.SIGNAL_SERVICE,
                LibL1Addrs.TAIKO_TOKEN
            )
        );
    }

    /// @dev Deploys a contract from a pre-built artifact (creation code + abi-encoded
    /// constructor args). Runs inside the active broadcast, so the create is recorded like a
    /// regular `new`. Reverts with forge's "no matching artifact" error if `pnpm compile:l1o`
    /// has not been run.
    function _deployFromArtifact(
        string memory _artifact,
        bytes memory _ctorArgs
    )
        private
        returns (address addr_)
    {
        bytes memory initCode = abi.encodePacked(vm.getCode(_artifact), _ctorArgs);
        assembly {
            addr_ := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(addr_ != address(0), string.concat("deploy failed: ", _artifact));
    }

    function _logDeployment(Deployment memory _deployment) private pure {
        console2.log("DCAP_ATTESTATION:", _deployment.dcapAttestation);
        console2.log("SGXRETH_VERIFIER_NEW:", _deployment.sgxRethVerifier);
        console2.log("ANY_TWO_VERIFIER:", _deployment.anyTwoVerifier);
        console2.log("MAINNET_INBOX_NEW_IMPL:", _deployment.mainnetInboxImpl);
        console2.log("RISC0_RETH_VERIFIER (reused):", LibL1Addrs.RISC0_RETH_VERIFIER);
        console2.log("SP1_RETH_VERIFIER (reused):", LibL1Addrs.SP1_RETH_VERIFIER);
        console2.log("NOTE: the new SGX verifier has no registered instances; after the DAO");
        console2.log("proposal executes (trust config), the registrar must registerInstance.");
        console2.log("RISC0+SP1 keeps proving alive until SGX registration completes.");
    }
}

interface IAutomataDcapAttestationFee {
    function setQuoteVerifier(address _verifier) external;
    function setBp(uint16 _bp) external;
    function transferOwnership(address _newOwner) external;
}
