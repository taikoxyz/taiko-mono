// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { LibL2HoodiAddrs } from "src/layer2/hoodi/LibL2HoodiAddrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";
import "test/shared/DeployCapability.sol";

/// @title UpgradeShastaL2Contracts
/// @notice Upgrades Shasta L2 contracts via bridge message. Automatically detects network based on chainId.
///
/// Required environment variables:
/// - PRIVATE_KEY: Deployer private key
/// - ANCHOR_FORK_ROUTER: Anchor fork router implementation address
/// - SIGNAL_SERVICE_FORK_ROUTER: Signal service fork router implementation address
/// - DELEGATE_CONTROLLER: L2 delegate controller address (only for Hoodi)
contract UpgradeShastaL2Contracts is DeployCapability {
    struct UpgradeConfig {
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
        UpgradeConfig memory config = _loadConfig();
        _validateConfig(config);
        _upgrade(config);
    }

    function _loadConfig() private view returns (UpgradeConfig memory config) {
        if (block.chainid == LibNetwork.ETHEREUM_MAINNET) {
            config = _loadMainnetConfig();
        } else if (block.chainid == LibNetwork.ETHEREUM_HOODI) {
            config = _loadHoodiConfig();
        } else {
            revert("Unsupported chainId");
        }

        // Load deployment-specific values from environment
        config.anchorForkRouter = vm.envAddress("ANCHOR_FORK_ROUTER");
        config.signalServiceForkRouter = vm.envAddress("SIGNAL_SERVICE_FORK_ROUTER");
    }

    function _loadMainnetConfig() private pure returns (UpgradeConfig memory config) {
        config.delegateController = LibL2Addrs.DELEGATE_CONTROLLER;
        config.l1Bridge = LibL1Addrs.BRIDGE;
        config.anchorProxy = LibL2Addrs.ANCHOR;
        config.signalServiceProxy = LibL2Addrs.SIGNAL_SERVICE;
        config.srcChainId = uint64(LibNetwork.ETHEREUM_MAINNET);
        config.destChainId = LibNetwork.TAIKO_MAINNET;
    }

    function _loadHoodiConfig() private view returns (UpgradeConfig memory config) {
        config.delegateController = vm.envAddress("DELEGATE_CONTROLLER");
        config.l1Bridge = LibL1HoodiAddrs.HOODI_BRIDGE;
        config.anchorProxy = LibL2HoodiAddrs.HOODI_ANCHOR;
        config.signalServiceProxy = LibL2HoodiAddrs.HOODI_SIGNAL_SERVICE;
        config.srcChainId = uint64(LibNetwork.ETHEREUM_HOODI);
        config.destChainId = LibNetwork.TAIKO_HOODI;
    }

    function _validateConfig(UpgradeConfig memory config) private pure {
        require(config.delegateController != address(0), "DELEGATE_CONTROLLER not set");
        require(config.l1Bridge != address(0), "L1_BRIDGE not set");
        require(config.anchorProxy != address(0), "ANCHOR_PROXY not set");
        require(config.anchorForkRouter != address(0), "ANCHOR_FORK_ROUTER not set");
        require(config.signalServiceProxy != address(0), "SIGNAL_SERVICE_PROXY not set");
        require(config.signalServiceForkRouter != address(0), "SIGNAL_SERVICE_FORK_ROUTER not set");
        require(config.srcChainId != 0, "SRC_CHAIN_ID not set");
        require(config.destChainId != 0, "DEST_CHAIN_ID not set");
    }

    function _upgrade(UpgradeConfig memory config) private {
        Controller.Action[] memory dcall = new Controller.Action[](2);
        dcall[0] = Controller.Action({
            target: config.anchorProxy,
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, config.anchorForkRouter)
        });
        dcall[1] = Controller.Action({
            target: config.signalServiceProxy,
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, config.signalServiceForkRouter)
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
                IMessageInvocable.onMessageInvocation,
                (abi.encodePacked(uint64(0), abi.encode(dcall)))
            )
        });
        IBridge(config.l1Bridge).sendMessage(message);
    }
}
