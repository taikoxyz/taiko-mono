// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployShastaL2Contracts } from "./DeployShastaL2Contracts.s.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeployShastaL2Mainnet
/// @notice Deploys Shasta L2 contracts for mainnet using hardcoded addresses.
///
/// Required environment variables:
/// - PRIVATE_KEY: Deployer private key
contract DeployShastaL2Mainnet is DeployShastaL2Contracts {
    function _loadConfig() internal pure override returns (DeploymentConfig memory config) {
        config.l1ChainId = uint64(LibNetwork.ETHEREUM_MAINNET);
        config.l1SignalService = LibL1Addrs.SIGNAL_SERVICE;
        config.l2SignalService = LibL2Addrs.SIGNAL_SERVICE;
        config.anchorProxy = LibL2Addrs.ANCHOR;
    }
}
