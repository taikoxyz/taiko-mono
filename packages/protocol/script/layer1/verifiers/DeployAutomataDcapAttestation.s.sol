// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    AutomataDcapAttestationFee
} from "@automata-network/automata-dcap-attestation/contracts/AutomataDcapAttestationFee.sol";
import {
    V3QuoteVerifier
} from "@automata-network/automata-dcap-attestation/contracts/verifiers/V3QuoteVerifier.sol";
import "@p256-verifier/contracts/P256Verifier.sol";
import "script/BaseScript.sol";

/// @title DeployAutomataDcapAttestation
/// @notice Deploys a Taiko-owned Automata DCAP attestation entrypoint
/// (`AutomataDcapAttestationFee`) wired to an SGX (V3) quote verifier, pointed at Automata's
/// deployed on-chain PCCS. The deployed entrypoint address is logged; pass it to
/// `DeployProtocolOnL1` via the `DCAP_ATTESTATION` env var.
/// @dev Kept in a dedicated script because the Automata verifier's X.509/ASN.1 parsing
/// (`QuoteVerifierBase`) requires the IR pipeline (`via_ir`) to compile. The IR pipeline alters
/// codegen in a way that breaks unrelated Shasta tests, so this script is excluded from
/// `profile.layer1` (see `foundry.toml` `skip`) and must be compiled/run under `profile.layer1o`,
/// which enables `via_ir`. The rest of the L1 build stays on the non-IR `profile.layer1`.
/// @custom:security-contact security@taiko.xyz
contract DeployAutomataDcapAttestation is BaseScript {
    function run() external broadcast returns (address entrypoint) {
        address owner = vm.envAddress("CONTRACT_OWNER");
        address pccsRouter = vm.envAddress("PCCS_ROUTER");
        require(owner != address(0), "CONTRACT_OWNER not set");
        require(pccsRouter != address(0), "PCCS_ROUTER not set");

        // SGX (V3) quote verifier, using the RIP-7212 P256 verifier and Automata's deployed PCCS.
        V3QuoteVerifier v3QuoteVerifier =
            new V3QuoteVerifier(address(new P256Verifier()), pccsRouter);
        console2.log("V3QuoteVerifier deployed:", address(v3QuoteVerifier));

        // Deploy the entrypoint owned by the deployer so we can wire the verifier, then hand
        // ownership to the contract owner. AutomataDcapAttestationFee is non-upgradeable (no proxy).
        AutomataDcapAttestationFee attestation = new AutomataDcapAttestationFee(msg.sender);
        attestation.setQuoteVerifier(address(v3QuoteVerifier));
        // Force a zero verification fee while the deployer is still the owner, before handing
        // ownership to `owner`. SgxVerifier.registerInstance forwards msg.value, so a non-zero fee
        // is still payable, but Taiko keeps it at zero by default.
        attestation.setBp(0);
        attestation.transferOwnership(owner);

        entrypoint = address(attestation);
        console2.log("AutomataDcapAttestationFee deployed:", entrypoint);
        console2.log("  -> set DCAP_ATTESTATION to this address for DeployProtocolOnL1");
    }
}
