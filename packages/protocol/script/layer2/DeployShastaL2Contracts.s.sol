// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    SignalServiceForkRouter
} from "../../../contracts/shared/signal/SignalServiceForkRouter.sol";
import { Anchor } from "../../contracts/layer2/core/Anchor.sol";
import { AnchorForkRouter } from "../../contracts/layer2/core/AnchorForkRouter.sol";
import "src/shared/signal/SignalService.sol";
import "test/shared/DeployCapability.sol";

contract DeployShastaL2Contracts is DeployCapability {
    struct DeploymentConfig {
        uint64 l1ChainId;
        address l1SignalService;
        address oldSignalServiceImpl;
        address anchorProxy;
        address oldAnchorImpl;
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
        // TODO: question about whether the Bridge contract is compatible and whether a Bridge contract upgrade is required.
        address anchorImpl =
            address(new Anchor(ICheckpointStore(config.l1SignalService), config.l1ChainId));
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

    function _loadConfig() private view returns (DeploymentConfig memory config) {
        config.l1ChainId = uint64(vm.envUint("L2_CHAIN_ID"));
        config.l1SignalService = vm.envAddress("L2_SIGNAL_SERVICE");
        config.oldSignalServiceImpl = vm.envAddress("OLD_SIGNAL_SERVICE_IMPL");
        config.anchorProxy = vm.envAddress("ANCHOR_PROXY");
        config.oldAnchorImpl = vm.envAddress("OLD_ANCHOR_IMPL");

        require(config.l1ChainId != 0, "L2_CHAIN_ID not set");
        require(config.l1SignalService != address(0), "L2_SIGNAL_SERVICE not set");
        require(config.oldSignalServiceImpl != address(0), "OLD_SIGNAL_SERVICE_IMPL not set");
        require(config.anchorProxy != address(0), "ANCHOR_PROXY not set");
        require(config.oldAnchorImpl != address(0), "OLD_ANCHOR_IMPL not set");
    }
}
