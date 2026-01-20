// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DelegateController } from "../../../contracts/layer2/governance/DelegateController.sol";
import "test/shared/DeployCapability.sol";

contract UpgradeShastaL2Contracts is DeployCapability {
    struct DeploymentConfig {
        address delegateController;
        address l1Bridge;
        address anchorProxy;
        address anchorForkRouter;
        address signalServiceProxy;
        address signalServiceForkRouter;
        uint64 srcChainId;
        uint64 destChainId;
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
        // TODO: We need to upgrade DelegateOwner to DelegateController on mainnet first.
        Controller.Action[] memory dcall = new Controller.Action[](2);
        dcall[0] = Controller.Action({
            target: config.anchorProxy,
            value: 0,
            data: abi.encodeCall(Ownable2StepUpgradeable.upgradeTo, config.anchorForkRouter)
        });
        dcall[1] = Controller.Action({
            target: config.signalServiceProxy,
            value: 0,
            data: abi.encodeCall(Ownable2StepUpgradeable.upgradeTo, config.signalServiceForkRouter)
        });

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 5_000_000,
            from: msg.sender,
            srcChainId: config.srcChainId,
            srcOwner: msg.sender,
            destChainId: config.destChainId,
            destOwner: config.delegateController,
            to: config.delegateController,
            value: 0,
            data: abi.encodeCall(
                DelegateController.onMessageInvocation,
                (abi.encodePacked(uint64(0), abi.encode(dcall)))
            )
        });
        IBridge(config.l1Bridge).sendMessage(message);
    }

    function _loadConfig() private view returns (DeploymentConfig memory config) {
        config.delegateController = vm.envAddress("DELEGATE_CONTROLLER");
        config.l1Bridge = vm.envAddress("L1_BRIDGE");
        config.anchorProxy = vm.envAddress("ANCHOR_PROXY");
        config.anchorForkRouter = vm.envAddress("ANCHOR_FORK_ROUTER");
        config.signalServiceProxy = vm.envAddress("SIGNAL_SERVICE_PROXY");
        config.signalServiceForkRouter = vm.envAddress("SIGNAL_SERVICE_FORK_ROUTER");
        config.srcChainId = uint64(vm.envUint("SRC_CHAIN_ID"));
        config.destChainId = uint64(vm.envUint("DEST_CHAIN_ID"));

        require(config.delegateController != address(0), "DELEGATE_CONTROLLER not set");
        require(config.l1Bridge != address(0), "L1_BRIDGE not set");
        require(config.anchorProxy != address(0), "ANCHOR_PROXY not set");
        require(config.anchorForkRouter != address(0), "ANCHOR_FORK_ROUTER not set");
        require(config.signalServiceProxy != address(0), "SIGNAL_SERVICE_PROXY not set");
        require(config.signalServiceForkRouter != address(0), "SIGNAL_SERVICE_FORK_ROUTER not set");
        require(config.srcChainId != 0, "SRC_CHAIN_ID not set");
        require(config.destChainId != 0, "DEST_CHAIN_ID not set");
    }
}
