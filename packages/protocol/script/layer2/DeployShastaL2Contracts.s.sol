// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Anchor } from "src/layer2/core/Anchor.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalServiceL2 } from "src/shared/signal/SignalServiceL2.sol";
import "test/shared/DeployCapability.sol";

/// @title DeployShastaL2Contracts
/// @notice Base contract for deploying Shasta L2 contracts with configurable parameters.
abstract contract DeployShastaL2Contracts is DeployCapability {
    struct DeploymentConfig {
        uint64 l1ChainId;
        address l1SignalService;
        address l2SignalService;
        address anchorProxy;
        address signalServicePauser;
        uint64 etnaTimestamp;
        /// @dev Must match the checkpoint/cache layout of the existing L2 proxy.
        bool signalServiceUsesLegacyStorage;
    }

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set or invalid");
        vm.startBroadcast(privateKey);
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

    function _validateConfig(DeploymentConfig memory config) internal view {
        require(config.l1ChainId != 0, "L1_CHAIN_ID not set");
        require(config.l1SignalService != address(0), "L1_SIGNAL_SERVICE not set");
        require(config.l2SignalService != address(0), "L2_SIGNAL_SERVICE not set");
        require(config.anchorProxy != address(0), "ANCHOR_PROXY not set");
        // On a running network the gate must lie in the future, or anchorV4 would already revert.
        // This checks only deploy time. The upgrade to this Anchor implementation must execute on
        // L2 before etnaTimestamp; otherwise the old, ungated anchorV4 is still live at the fork.
        require(config.etnaTimestamp > block.timestamp, "ETNA_TIMESTAMP not in the future");
    }

    /// @dev Preserves an existing immutable pauser when deploying a replacement implementation.
    /// @param _signalService Existing L2 SignalService proxy.
    /// @param _usesLegacyStorage Whether the target is an old flat-mapping implementation.
    /// @return pauser_ Existing pauser, or zero for a legacy implementation without that getter.
    function _readSignalServicePauser(
        address _signalService,
        bool _usesLegacyStorage
    )
        internal
        view
        returns (address pauser_)
    {
        (bool ok, bytes memory ret) = _signalService.staticcall(abi.encodeWithSignature("pauser()"));
        // The pre-pauser legacy implementation has no getter. A versioned target must expose
        // it; treating a failed read there as zero would silently remove its pause authority.
        if (ret.length == 0) {
            require(_usesLegacyStorage, "SignalService pauser unavailable");
            return address(0);
        }
        require(ok && ret.length == 32, "Invalid SignalService pauser");
        return abi.decode(ret, (address));
    }

    function _deploy(DeploymentConfig memory config) internal {
        address anchorImpl = address(
            new Anchor(
                ICheckpointStore(config.l2SignalService), config.l1ChainId, config.etnaTimestamp
            )
        );
        console2.log("New anchorImpl deployed:", anchorImpl);

        address signalServiceImpl = address(
            new SignalServiceL2(
                config.anchorProxy,
                config.l1SignalService,
                config.signalServicePauser,
                config.signalServiceUsesLegacyStorage
            )
        );
        console2.log("New signalServiceImpl deployed:", signalServiceImpl);
    }
}
