// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployShastaContracts } from "./DeployShastaContracts.s.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeployShastaMainnet
/// @notice Deploys Shasta contracts for Taiko mainnet.
/// Uses known mainnet addresses from LibL1Addrs and LibL2Addrs.
///
/// Required environment variables:
/// - PRIVATE_KEY: Deployer private key
/// - CONTRACT_OWNER: Owner address for deployed contracts
/// - PROVERS: Comma-separated list of prover addresses
/// - SGX_AUTOMATA_PROXY: SGX Automata proxy address
/// - SGX_GETH_AUTOMATA_PROXY: SGX Geth Automata proxy address
/// - R0_GROTH16_VERIFIER: RISC0 Groth16 verifier address
/// - SP1_PLONK_VERIFIER: SP1 Plonk verifier address
/// - OLD_SIGNAL_SERVICE_IMPL: Current signal service implementation address
/// - SHASTA_FORK_TIMESTAMP: Unix timestamp for the Shasta fork
contract DeployShastaMainnet is DeployShastaContracts {
    function _loadConfig() internal view override returns (DeploymentConfig memory config) {
        // Use known mainnet constants
        config.l2ChainId = LibNetwork.TAIKO_MAINNET;
        config.l1SignalService = LibL1Addrs.SIGNAL_SERVICE;
        config.l2SignalService = LibL2Addrs.SIGNAL_SERVICE;
        config.taikoToken = LibL1Addrs.TAIKO_TOKEN;
        config.preconfWhitelist = LibL1Addrs.PRECONF_WHITELIST;
        config.contractOwner = LibL1Addrs.DAO_CONTROLLER;

        // Load deployment-specific values from environment
        config.sgxAutomataProxy = vm.envAddress("SGX_AUTOMATA_PROXY");
        config.sgxGethAutomataProxy = vm.envAddress("SGX_GETH_AUTOMATA_PROXY");
        config.r0Groth16Verifier = vm.envAddress("R0_GROTH16_VERIFIER");
        config.sp1PlonkVerifier = vm.envAddress("SP1_PLONK_VERIFIER");
        config.provers = vm.envAddress("PROVERS", ",");
        config.oldSignalServiceImpl = vm.envAddress("OLD_SIGNAL_SERVICE_IMPL");
        config.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
    }
}
