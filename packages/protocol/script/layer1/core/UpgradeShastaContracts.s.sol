// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import "test/shared/DeployCapability.sol";

/// @title UpgradeShastaContracts
/// @notice Upgrades Shasta L1 contracts.
/// This script CAN ONLY BE RUN ON HOODI. For mainnet, we need to use the `BuildProposal` format.
///
/// Required environment variables:
/// - PRIVATE_KEY: Deployer private key
/// - PRECONF_WHITELIST_IMPL: New preconf whitelist implementation address
/// - PROVER_WHITELIST_PROXY: Prover whitelist proxy address (from deployment)
/// - SIGNAL_SERVICE_FORK_ROUTER_IMPL: Signal service fork router implementation address
contract UpgradeShastaContracts is DeployCapability {
    struct UpgradeConfig {
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
        UpgradeConfig memory config = _loadConfig();
        _validateConfig(config);
        _upgrade(config);
    }

    function _loadConfig() private view returns (UpgradeConfig memory config) {
        config.preconfWhitelistProxy = LibL1HoodiAddrs.HOODI_PRECONF_WHITELIST;
        config.signalServiceProxy = LibL1HoodiAddrs.HOODI_SIGNAL_SERVICE;

        // Load deployment-specific values from environment
        config.preconfWhitelistImpl = vm.envAddress("PRECONF_WHITELIST_IMPL");
        config.proverWhitelistProxy = vm.envAddress("PROVER_WHITELIST_PROXY");
        config.signalServiceForkRouterImpl = vm.envAddress("SIGNAL_SERVICE_FORK_ROUTER_IMPL");
    }

    function _validateConfig(UpgradeConfig memory config) private pure {
        require(config.preconfWhitelistProxy != address(0), "PRECONF_WHITELIST_PROXY not set");
        require(config.preconfWhitelistImpl != address(0), "PRECONF_WHITELIST_IMPL not set");
        require(config.proverWhitelistProxy != address(0), "PROVER_WHITELIST_PROXY not set");
        require(config.signalServiceProxy != address(0), "SIGNAL_SERVICE_PROXY not set");
        require(
            config.signalServiceForkRouterImpl != address(0),
            "SIGNAL_SERVICE_FORK_ROUTER_IMPL not set"
        );
    }

    function _upgrade(UpgradeConfig memory config) private {
        UUPSUpgradeable(config.preconfWhitelistProxy).upgradeTo(config.preconfWhitelistImpl);
        Ownable2StepUpgradeable(config.proverWhitelistProxy).acceptOwnership();
        UUPSUpgradeable(config.signalServiceProxy).upgradeTo(config.signalServiceForkRouterImpl);
    }
}
