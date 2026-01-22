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
/// - ACTIVATOR: Address to set as initial inbox owner
/// - PROVERS: Comma-separated list of prover addresses
/// - SHASTA_FORK_TIMESTAMP: Unix timestamp for the Shasta fork
contract DeployShastaHoodi is DeployShastaContracts {
    function _loadConfig() internal view override returns (DeploymentConfig memory config) {
        // Use known Hoodi constants
        config.l2ChainId = LibNetwork.TAIKO_HOODI;
        config.l1SignalService = LibL1HoodiAddrs.HOODI_SIGNAL_SERVICE;
        config.l2SignalService = LibL2HoodiAddrs.HOODI_SIGNAL_SERVICE;
        config.taikoToken = LibL1HoodiAddrs.HOODI_TAIKO_TOKEN;
        config.preconfWhitelist = LibL1HoodiAddrs.HOODI_PRECONF_WHITELIST;
        config.contractOwner = LibL1HoodiAddrs.HOODI_CONTRACT_OWNER;

        config.oldSignalServiceImpl = 0x5776315840041c2bc2C9D16a33E52AD0DD359600;
        config.r0Groth16Verifier = 0xD559e537CF82f2816096a3DDBC2026514e308CF7;
        config.sgxGethAutomataProxy = 0x488797321FA4272AF9d0eD4cDAe5Ec7a0210cBD5;
        // Reth
        config.sgxRethAutomataProxy = 0xebA89cA02449070b902A5DDc406eE709940e280E;
        config.sp1PlonkVerifier = 0x801dcB74Ed6c45764c91B9e818Ec204B41EadA9B;

        // Load deployment-specific values from environment
        config.activator = vm.envAddress("ACTIVATOR");
        config.provers = vm.envAddress("PROVERS", ",");
        config.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
    }
}
