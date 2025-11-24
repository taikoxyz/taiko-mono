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
        console2.log("anchorProxy:", config.anchorProxy);

        config.signalServiceProxy = LibL2Addrs.SIGNAL_SERVICE;
        console2.log("signalServiceProxy:", config.signalServiceProxy);

        config.remoteSignalService = LibL1Addrs.SIGNAL_SERVICE;
        console2.log("remoteSignalService:", config.remoteSignalService);

        config.bondToken = LibL2Addrs.TAIKO_TOKEN;
        console2.log("bondToken:", config.bondToken);

        config.l1ChainId = 1;
        console2.log("l1ChainId:", config.l1ChainId);

        config.minBond = vm.envUint("MIN_BOND");
        require(config.minBond > 0, "MIN_BOND not set");
        console2.log("minBond:", config.minBond);

        config.withdrawalDelay = uint48(vm.envUint("WITHDRAWAL_DELAY"));
        require(config.withdrawalDelay > 0, "WITHDRAWAL_DELAY not set");
        console2.log("withdrawalDelay:", config.withdrawalDelay);

        config.livenessBond = vm.envUint("LIVENESS_BOND");
        require(config.livenessBond > 0, "LIVENESS_BOND not set");
        console2.log("livenessBond:", config.livenessBond);

        config.provabilityBond = vm.envUint("PROVABILITY_BOND");
        require(config.provabilityBond > 0, "PROVABILITY_BOND not set");
        console2.log("provabilityBond:", config.provabilityBond);

        config.shastaForkTimestamp = uint64(vm.envUint("SHASTA_FORK_TIMESTAMP"));
        require(config.shastaForkTimestamp != 0, "SHASTA_FORK_TIMESTAMP not set");
        console2.log("shastaForkTimestamp:", config.shastaForkTimestamp);
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
        Anchor anchorProxy = Anchor(config.anchorProxy);

        address anchorOldImpl = anchorProxy.impl();
        console2.log("anchorOldImpl:", anchorOldImpl);

        address owner = anchorProxy.owner();
        console2.log("anchor owner:", owner);

        address bondManagerImpl = address(
            new BondManager(
                config.anchorProxy, config.bondToken, config.minBond, config.withdrawalDelay
            )
        );
        console2.log("bondManagerImpl deployed:", address(bondManagerImpl));

        address bondManagerProxy = deploy({
            name: "shasta_bond_manager",
            impl: bondManagerImpl,
            data: abi.encodeCall(BondManager.init, (owner))
        });
        console2.log("bondManagerProxy deployed:", bondManagerProxy);

        // Fresh BondManager + Anchor impl configured from env.
        address anchorNewImpl = address(
            new Anchor(
                ICheckpointStore(config.signalServiceProxy),
                BondManager(bondManagerProxy),
                config.livenessBond,
                config.provabilityBond,
                config.l1ChainId,
                owner // really?
            )
        );
        console2.log("anchorNewImpl deployed:", address(anchorNewImpl));

        address anchorForkRouter = address(new AnchorForkRouter(anchorOldImpl, anchorNewImpl));
        console2.log("anchorForkRouter deployed:", anchorForkRouter);
    }

    /// @dev Deploys a new SignalService impl, wraps with fork router.
    /// Caller should execute proxy upgrade separately if desired.
    function _deploySignalService(Config memory config) private {
        console2.log("signalServiceOldImpl:", SignalService(config.signalServiceProxy).impl());

        address signalServiceNewImpl =
            address(new SignalService(config.anchorProxy, config.remoteSignalService));
        console2.log("signalServiceNewImpl deployed:", signalServiceNewImpl);

        address signalServiceRouter = address(
            new SignalServiceForkRouter(
                SignalService(config.signalServiceProxy).impl(),
                signalServiceNewImpl,
                config.shastaForkTimestamp
            )
        );

        console2.log("signalServiceForkRouter deployed:", signalServiceRouter);
    }
}
