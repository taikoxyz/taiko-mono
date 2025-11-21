// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "script/BaseScript.sol";

import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { AnchorForkRouter } from "src/layer2/core/AnchorForkRouter.sol";
import { BondManager } from "src/layer2/core/BondManager.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { SignalServiceForkRouter } from "src/shared/signal/SignalServiceForkRouter.sol";

/// FOUNDRY_PROFILE=layer2 forge script --rpc-url <L2_RPC> script/layer2/DeployShasta.s.sol --broadcast
contract DeployShasta is BaseScript {
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
        config.anchorProxy = LibL2Addrs.ANCHOR;
        config.signalServiceProxy = LibL2Addrs.SIGNAL_SERVICE;
        config.remoteSignalService = LibL1Addrs.SIGNAL_SERVICE;
        config.bondToken = LibL2Addrs.TAIKO_TOKEN;
        config.l1ChainId = 1;

        config.minBond = vm.envUint("MIN_BOND");
        config.withdrawalDelay = uint48(vm.envUint("WITHDRAWAL_DELAY"));
        config.livenessBond = vm.envUint("LIVENESS_BOND");
        config.provabilityBond = vm.envUint("PROVABILITY_BOND");
        config.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
    }

    /// @notice Entry point: deploy new anchor fork router impl first, then signal service impl.
    function run() external broadcast {
        Config memory config = _loadConfig();

        _deployAnchor(config);
        _deploySignalService(config);
    }

    /// @dev Deploys a new BondManager (as proxy) and Anchor impl, wraps with fork router.
    /// Caller should execute proxy upgrade separately if desired.
    function _deployAnchor(Config memory config) private {
        Anchor anchor = Anchor(config.anchorProxy);
        address currentImpl = anchor.impl();
        address owner = anchor.owner();

        BondManager bondManagerImpl = new BondManager(
            config.anchorProxy, config.bondToken, config.minBond, config.withdrawalDelay
        );
        address bondManagerProxy = deploy({
            name: bytes32("shasta_bond_manager"),
            impl: address(bondManagerImpl),
            data: abi.encodeCall(BondManager.init, (owner))
        });

        // Fresh BondManager + Anchor impl configured from env.
        Anchor newImpl = new Anchor(
            ICheckpointStore(config.signalServiceProxy),
            BondManager(bondManagerProxy),
            config.livenessBond,
            config.provabilityBond,
            config.l1ChainId,
            owner
        );

        AnchorForkRouter router = new AnchorForkRouter(currentImpl, address(newImpl));

        console2.log("Deploy anchor proxy:", config.anchorProxy);
        console2.log("Current implementation:", currentImpl);
        console2.log("New implementation:", address(newImpl));
        console2.log("BondManager proxy:", bondManagerProxy);
        console2.log("BondManager implementation:", address(bondManagerImpl));
        console2.log("Fork router implementation:", address(router));
    }

    /// @dev Deploys a new SignalService impl, wraps with fork router.
    /// Caller should execute proxy upgrade separately if desired.
    function _deploySignalService(Config memory config) private {
        SignalService newSignalServiceImpl =
            new SignalService(config.anchorProxy, config.remoteSignalService);

        SignalServiceForkRouter router = new SignalServiceForkRouter(
            SignalService(config.signalServiceProxy).impl(),
            address(newSignalServiceImpl),
            config.shastaForkTimestamp
        );

        console2.log("Deploy SignalService proxy:", config.signalServiceProxy);
        console2.log("Current implementation:", SignalService(config.signalServiceProxy).impl());
        console2.log("New implementation:", address(newSignalServiceImpl));
        console2.log("Fork router implementation:", address(router));
    }
}
