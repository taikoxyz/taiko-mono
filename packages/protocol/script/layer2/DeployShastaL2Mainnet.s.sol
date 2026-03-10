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
/// - SHASTA_FORK_TIMESTAMP: Timestamp for the Shasta fork
contract DeployShastaL2Mainnet is DeployShastaL2Contracts {
    function _loadConfig() internal view override returns (DeploymentConfig memory config) {
        config.l1ChainId = uint64(LibNetwork.ETHEREUM_MAINNET);
        config.l1SignalService = LibL1Addrs.SIGNAL_SERVICE;
        config.l2SignalService = LibL2Addrs.SIGNAL_SERVICE;
        config.anchorProxy = LibL2Addrs.ANCHOR;

        config.oldSignalServiceImpl = 0xaea51c413Bd15bBee72737C8094BE942B5208762;
        config.oldAnchorImpl = 0xE6d1efcC6AC8969474308C99a3805c332D33a1E0;

        config.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
    }
}
