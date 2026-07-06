// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployShastaContracts } from "./DeployShastaContracts.s.sol";
import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import { LibL2HoodiAddrs } from "src/layer2/hoodi/LibL2HoodiAddrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeployShastaHoodi
/// @notice Deploys Shasta contracts for Hoodi testnet.
/// Uses known Hoodi addresses from LibL1HoodiAddrs and LibL2HoodiAddrs.
///
/// Required environment variables:
/// - PRIVATE_KEY: Deployer private key
/// - DCAP_ATTESTATION: Taiko-owned AutomataDcapAttestationFee entrypoint (shared by both SGX tiers)
/// - ACTIVATOR: Address to set as initial inbox owner
/// - PROVERS: Comma-separated list of prover addresses
contract DeployShastaHoodi is DeployShastaContracts {
    function _loadConfig() internal view override returns (DeploymentConfig memory config) {
        // Use known Hoodi constants
        config.l2ChainId = LibNetwork.TAIKO_HOODI;
        config.l1SignalService = LibL1HoodiAddrs.HOODI_SIGNAL_SERVICE;
        config.l2SignalService = LibL2HoodiAddrs.HOODI_SIGNAL_SERVICE;
        config.taikoToken = LibL1HoodiAddrs.HOODI_TAIKO_TOKEN;
        config.preconfWhitelist = LibL1HoodiAddrs.HOODI_PRECONF_WHITELIST;
        config.contractOwner = LibL1HoodiAddrs.HOODI_CONTRACT_OWNER;
        config.proverManager = LibL1HoodiAddrs.HOODI_CONTRACT_OWNER;
        config.ejectorManager = LibL1HoodiAddrs.HOODI_CONTRACT_OWNER;

        config.r0Groth16Verifier = 0x32Db7dc407AC886807277636a1633A1381748DD8;
        // Both SGX instances share ONE Taiko-owned AutomataDcapAttestationFee entrypoint, deployed by
        // DeployAutomataDcapAttestation and passed via the DCAP_ATTESTATION env var. This reverses
        // #21871's legacy per-tier proxy wiring (0x4887…/0xebA8…) for Hoodi, matching the #21827
        // shared-entrypoint model so the deployed stack passes VerifyHoodiDeployment.
        address dcapAttestation = vm.envAddress("DCAP_ATTESTATION");
        config.sgxGethAutomataProxy = dcapAttestation;
        config.sgxRethAutomataProxy = dcapAttestation;
        config.sp1PlonkVerifier = 0x2a5A70409Ee9F057503a50E0F4614A6d8CcBb462;

        // Hoodi is a public testnet, so it MUST use the strict SecureSgxVerifier (secure default),
        // matching mainnet and every other public network. The lenient InsecureSgxVerifier is for
        // local devnets only. A prover whose platform reports an out-of-date TCB must update its
        // microcode rather than rely on a weakened public-testnet policy.
        config.useInsecureSgxPolicy = false;

        // Load deployment-specific values from environment
        config.activator = vm.envAddress("ACTIVATOR");
        config.provers = vm.envAddress("PROVERS", ",");
    }
}
