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
contract DeployShastaMainnet is DeployShastaContracts {
    function _loadConfig() internal view override returns (DeploymentConfig memory config) {
        // Use known mainnet constants
        config.l2ChainId = LibNetwork.TAIKO_MAINNET;
        config.l1SignalService = LibL1Addrs.SIGNAL_SERVICE;
        config.l2SignalService = LibL2Addrs.SIGNAL_SERVICE;
        config.taikoToken = LibL1Addrs.TAIKO_TOKEN;
        config.preconfWhitelist = LibL1Addrs.PRECONF_WHITELIST;
        config.contractOwner = LibL1Addrs.DAO_CONTROLLER;

        config.r0Groth16Verifier = 0x8EaB2D97Dfce405A1692a21b3ff3A172d593D319;
        config.sgxGethAutomataProxy = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;
        config.sgxRethAutomataProxy = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;
        config.sp1PlonkVerifier = 0x3B6041173B80E77f038f3F2C0f9744f04837185e;

        config.activator = 0xF14Dc4EdDb43e9a6A440e6beC97ea2ea64f39Ef7;
        config.ejectorManager = LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH;
        config.proverManager = LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH;
        config.provers = new address[](1);
        config.provers[0] = 0xa5cb34B75bD72f15290ef37A01F06183E8036875; // We can add new provers later using the prover manager role
    }
}
