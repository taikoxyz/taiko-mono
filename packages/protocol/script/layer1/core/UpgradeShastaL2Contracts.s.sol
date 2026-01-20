// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    SignalServiceForkRouter
} from "../../../contracts/shared/signal/SignalServiceForkRouter.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "test/shared/DeployCapability.sol";

contract UpgradeShastaContracts is DeployCapability {
    struct DeploymentConfig {
        address preconfWhitelistProxy;
        address preconfWhitelistImpl;
        address proverWhitelistProxy;
        address signalServiceProxy;
        address signalServiceForkRouterImpl;
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
        PreconfWhitelist(config.preconfWhitelistProxy).upgradeTo(config.preconfWhitelistImpl);
        Ownable2StepUpgradeable(config.proverWhitelistProxy).acceptOwnership();
        SignalServiceForkRouter(config.signalServiceProxy)
            .upgradeTo(config.signalServiceForkRouterImpl);
    }

    function _loadConfig() private view returns (DeploymentConfig memory config) {
        config.preconfWhitelistProxy = vm.envAddress("PRECONF_WHITELIST_PROXY");
        config.preconfWhitelistImpl = vm.envAddress("PRECONF_WHITELIST_IMPL");
        config.proverWhitelistProxy = vm.envAddress("PROVER_WHITELIST_PROXY");
        config.signalServiceProxy = vm.envAddress("SIGNAL_SERVICE_PROXY");
        config.signalServiceForkRouterImpl = vm.envAddress("SIGNAL_SERVICE_FORK_ROUTER_IMPL");

        require(config.preconfWhitelistProxy != address(0), "PRECONF_WHITELIST_PROXY not set");
        require(config.preconfWhitelistImpl != address(0), "PRECONF_WHITELIST_IMPL not set");
        require(config.proverWhitelistProxy != address(0), "PROVER_WHITELIST_PROXY not set");
        require(config.signalServiceProxy != address(0), "SIGNAL_SERVICE_PROXY not set");
        require(
            config.signalServiceForkRouterImpl != address(0),
            "SIGNAL_SERVICE_FORK_ROUTER_IMPL not set"
        );
    }
}
