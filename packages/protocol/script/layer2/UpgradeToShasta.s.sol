// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "script/BaseScript.sol";

import { Anchor } from "src/layer2/core/Anchor.sol";
import { AnchorForkRouter } from "src/layer2/core/AnchorForkRouter.sol";
import { BondManager } from "src/layer2/core/BondManager.sol";

import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { SignalServiceForkRouter } from "src/shared/signal/SignalServiceForkRouter.sol";

/// forge script --rpc-url <L2_RPC> script/layer2/UpgradeToShasta.s.sol --broadcast
contract UpgradeToShasta is BaseScript {
    struct Config {
        address anchorProxy;
        address signalServiceProxy;
        address remoteSignalService;
        address bondToken;
        uint256 minBond;
        uint48 withdrawalDelay;
        uint256 livenessBond;
        uint256 provabilityBond;
        uint64 l1ChainId;
        uint64 shastaForkTimestamp;
    }

    /// @dev Load config from env vars.
    function _loadConfig() private view returns (Config memory config) {
        config.anchorProxy = vm.envAddress("ANCHOR_PROXY");
        require(config.anchorProxy != address(0), "anchor address not set");

        config.signalServiceProxy = vm.envAddress("SIGNAL_SERVICE_PROXY");
        require(config.signalServiceProxy != address(0), "signal service address not set");

        config.remoteSignalService = vm.envAddress("REMOTE_SIGNAL_SERVICE");
        require(config.remoteSignalService != address(0), "remote signal service not set");

        config.bondToken = vm.envAddress("BOND_TOKEN");
        config.minBond = vm.envUint("MIN_BOND");
        config.withdrawalDelay = uint48(vm.envUint("WITHDRAWAL_DELAY"));
        config.livenessBond = vm.envUint("LIVENESS_BOND");
        config.provabilityBond = vm.envUint("PROVABILITY_BOND");
        config.l1ChainId = uint64(vm.envUint("L1_CHAIN_ID"));
        config.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
    }

    /// @notice Entry point: deploy new anchor impl first, then signal service impl.
    function run() external broadcast {
        Config memory config = _loadConfig();

        _deployAnchor(config);
        _deploySignalService(config);
    }

    /// @dev Deploys a new BondManager and Anchor impl, wraps with fork router.
    /// Caller should execute proxy upgrade separately if desired.
    function _deployAnchor(Config memory config) private {
        Anchor anchor = Anchor(config.anchorProxy);
        address currentImpl = anchor.impl();

        // Fresh BondManager + Anchor impl configured from env.
        Anchor newImpl = new Anchor(
            ICheckpointStore(config.signalServiceProxy),
            new BondManager(
                config.anchorProxy, config.bondToken, config.minBond, config.withdrawalDelay
            ),
            config.livenessBond,
            config.provabilityBond,
            config.l1ChainId,
            anchor.owner()
        );

        AnchorForkRouter router = new AnchorForkRouter(currentImpl, address(newImpl));

        console2.log("Deploy anchor proxy:", config.anchorProxy);
        console2.log("Current implementation:", currentImpl);
        console2.log("New implementation:", address(newImpl));
        console2.log("Fork router implementation:", address(router));
    }

    /// @dev Deploys a new SignalService impl, wraps with fork router.
    /// Caller should execute proxy upgrade separately if desired.
    function _deploySignalService(Config memory config) private {
        SignalService signalService = SignalService(config.signalServiceProxy);
        address owner = signalService.owner();
        require(owner == vm.addr(deployerPrivateKey), "caller is not signal owner");

        // Swap in new SignalService impl and route through fork router by timestamp.
        SignalService newSignalServiceImpl =
            new SignalService(config.anchorProxy, config.remoteSignalService);

        SignalServiceForkRouter router = new SignalServiceForkRouter(
            signalService.impl(), address(newSignalServiceImpl), config.shastaForkTimestamp
        );

        console2.log("Deploy SignalService proxy:", config.signalServiceProxy);
        console2.log("Current implementation:", signalService.impl());
        console2.log("New implementation:", address(newSignalServiceImpl));
        console2.log("Fork router implementation:", address(router));
    }
}
