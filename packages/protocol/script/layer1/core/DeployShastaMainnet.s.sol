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
/// - PROVERS: Comma-separated list of prover addresses
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

        // TODO: Please review these addresses carefully
        config.oldSignalServiceImpl = 0x42Ec977eb6B09a8D78c6D486c3b0e63569bA851c;
        config.r0Groth16Verifier = 0x7CCA385bdC790c25924333F5ADb7F4967F5d1599;
        config.sgxGethAutomataProxy = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;
        // Reth
        config.sgxAutomataProxy = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;
        config.sp1PlonkVerifier = 0xcdCEBD75cDcb9DEd637D537776431Db563Ff0821;


        // Load deployment-specific values from environment
        config.provers = vm.envAddress("PROVERS", ",");
        config.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
    }
}
