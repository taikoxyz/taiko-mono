// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployShastaContracts } from "./DeployShastaContracts.s.sol";

/// @title DeployShastaHoodi
/// @notice Deploys Shasta contracts for Hoodi testnet.
/// All configuration is loaded from environment variables.
///
/// Required environment variables:
/// - PRIVATE_KEY: Deployer private key
/// - CONTRACT_OWNER: Owner address for deployed contracts
/// - L2_CHAIN_ID: Target L2 chain ID
/// - L1_SIGNAL_SERVICE: L1 signal service proxy address
/// - L2_SIGNAL_SERVICE: L2 signal service address
/// - TAIKO_TOKEN: Taiko token address
/// - PRECONF_WHITELIST: Preconf whitelist address
/// - PROVERS: Comma-separated list of prover addresses
/// - SGX_AUTOMATA_PROXY: SGX Automata proxy address
/// - SGX_GETH_AUTOMATA_PROXY: SGX Geth Automata proxy address
/// - R0_GROTH16_VERIFIER: RISC0 Groth16 verifier address
/// - SP1_PLONK_VERIFIER: SP1 Plonk verifier address
/// - OLD_SIGNAL_SERVICE_IMPL: Current signal service implementation address
/// - SHASTA_FORK_TIMESTAMP: Unix timestamp for the Shasta fork
contract DeployShastaHoodi is DeployShastaContracts {
    function _loadConfig() internal view override returns (DeploymentConfig memory config) {
        config.contractOwner = vm.envAddress("CONTRACT_OWNER");
        config.l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));
        config.l1SignalService = vm.envAddress("L1_SIGNAL_SERVICE");
        config.l2SignalService = vm.envAddress("L2_SIGNAL_SERVICE");
        config.taikoToken = vm.envAddress("TAIKO_TOKEN");
        config.preconfWhitelist = vm.envAddress("PRECONF_WHITELIST");
        config.sgxAutomataProxy = vm.envAddress("SGX_AUTOMATA_PROXY");
        config.sgxGethAutomataProxy = vm.envAddress("SGX_GETH_AUTOMATA_PROXY");
        config.r0Groth16Verifier = vm.envAddress("R0_GROTH16_VERIFIER");
        config.sp1PlonkVerifier = vm.envAddress("SP1_PLONK_VERIFIER");
        config.provers = vm.envAddress("PROVERS", ",");
        config.oldSignalServiceImpl = vm.envAddress("OLD_SIGNAL_SERVICE_IMPL");
        config.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
    }
}
