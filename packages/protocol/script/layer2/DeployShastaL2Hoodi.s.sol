// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployShastaL2Contracts } from "./DeployShastaL2Contracts.s.sol";
import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import { LibL2HoodiAddrs } from "src/layer2/hoodi/LibL2HoodiAddrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeployShastaL2Hoodi
/// @notice Deploys Shasta L2 contracts for Hoodi testnet using hardcoded addresses.
///
/// Required environment variables:
/// - PRIVATE_KEY: Deployer private key
/// - SHASTA_FORK_TIMESTAMP: Timestamp for the Shasta fork
contract DeployShastaL2Hoodi is DeployShastaL2Contracts {
    function _loadConfig() internal view override returns (DeploymentConfig memory config) {
        config.l1ChainId = uint64(LibNetwork.ETHEREUM_HOODI);
        config.l1SignalService = LibL1HoodiAddrs.HOODI_SIGNAL_SERVICE;
        config.l2SignalService = LibL2HoodiAddrs.HOODI_SIGNAL_SERVICE;
        config.anchorProxy = LibL2HoodiAddrs.HOODI_ANCHOR;

        config.oldSignalServiceImpl = 0x0167013000000000000000000000000000000005;
        config.oldAnchorImpl = 0x5E652dC4033C6860b27d6860164369D15b421A42;


        config.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
    }
}
