// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Anchor } from "src/layer2/core/Anchor.sol";
import { AnchorForkRouter } from "src/layer2/core/AnchorForkRouter.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { SignalServiceForkRouter } from "src/shared/signal/SignalServiceForkRouter.sol";
import "test/shared/DeployCapability.sol";

/// @title DeployShastaL2Contracts
/// @notice Base contract for deploying Shasta L2 contracts with configurable parameters.
abstract contract DeployShastaL2Contracts is DeployCapability {
    struct DeploymentConfig {
        uint64 l1ChainId;
        address l1SignalService;
        address l2SignalService;
        address oldSignalServiceImpl;
        address anchorProxy;
        address oldAnchorImpl;
        uint64 shastaForkTimestamp;
    }

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set or invalid");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        DeploymentConfig memory config = _loadConfig();
        _validateConfig(config);
        _deploy(config);
    }

    /// @dev Override this function to provide deployment configuration.
    function _loadConfig() internal virtual returns (DeploymentConfig memory config);

    function _validateConfig(DeploymentConfig memory config) internal pure {
        require(config.l1ChainId != 0, "L1_CHAIN_ID not set");
        require(config.l1SignalService != address(0), "L1_SIGNAL_SERVICE not set");
        require(config.l2SignalService != address(0), "L2_SIGNAL_SERVICE not set");
        require(config.oldSignalServiceImpl != address(0), "OLD_SIGNAL_SERVICE_IMPL not set");
        require(config.anchorProxy != address(0), "ANCHOR_PROXY not set");
        require(config.oldAnchorImpl != address(0), "OLD_ANCHOR_IMPL not set");
        require(config.shastaForkTimestamp != 0, "SHASTA_FORK_TIMESTAMP not set");
    }

    function _deploy(DeploymentConfig memory config) internal {
        address anchorImpl =
            address(new Anchor(ICheckpointStore(config.l2SignalService), config.l1ChainId));
        console2.log("New anchorImpl deployed:", anchorImpl);

        address anchorForkRouter = address(new AnchorForkRouter(config.oldAnchorImpl, anchorImpl));
        console2.log("AnchorForkRouter deployed:", anchorForkRouter);

        address signalServiceImpl =
            address(new SignalService(config.anchorProxy, config.l1SignalService));
        console2.log("New signalServiceImpl deployed:", signalServiceImpl);

        address signalServiceForkRouter = address(
            new SignalServiceForkRouter(
                config.oldSignalServiceImpl, signalServiceImpl, config.shastaForkTimestamp
            )
        );
        console2.log("SignalServiceForkRouter deployed:", signalServiceForkRouter);
    }
}
