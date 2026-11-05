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
        // This checks only deploy time. The DAO proposal's single L2 batch upgrades this Anchor
        // and SignalServiceL2 together and must execute well before the Unzen propose cutoff, so
        // the Anchor at the Etna start S is already this one (Etna SWITCH.md section 3).
        require(config.etnaTimestamp > block.timestamp, "ETNA_TIMESTAMP not in the future");
        // ETNA_FORK_TIME is a uint48 in the EtnaInbox; a larger value could never match it.
        require(config.etnaTimestamp <= type(uint48).max, "ETNA_TIMESTAMP above 2^48 - 1");
    }

    /// @dev Preserves an existing immutable pauser when deploying a replacement implementation.
    /// @param _signalService Existing L2 SignalService proxy.
    /// @return pauser_ Existing pauser, or zero for a pre-pauser implementation.
    function _readSignalServicePauser(address _signalService)
        internal
        view
        returns (address pauser_)
    {
        (bool ok, bytes memory ret) = _signalService.staticcall(abi.encodeWithSignature("pauser()"));
        // Older implementations have neither getter; a versioned target must expose its pauser.
        if (ret.length == 0) {
            (bool versionOk, bytes memory version) =
                _signalService.staticcall(abi.encodeWithSignature("VERSION()"));
            require(versionOk || version.length == 0, "Invalid SignalService version");
            require(version.length == 0, "SignalService pauser unavailable");
            return address(0);
        }
        require(ok && ret.length == 32, "Invalid SignalService pauser");
        return abi.decode(ret, (address));
    }

    /// @dev Deploys the two implementations without upgrading the proxies: the Anchor saves
    /// checkpoints into the L2 SignalService proxy, and SignalServiceL2 accepts them only from the
    /// Anchor proxy.
    /// @param config The validated deployment configuration.
    /// @return anchorImpl_ The new Anchor implementation.
    /// @return signalServiceImpl_ The new SignalServiceL2 implementation.
    function _deploy(DeploymentConfig memory config)
        internal
        returns (address anchorImpl_, address signalServiceImpl_)
    {
        anchorImpl_ = address(
            new Anchor(
                ICheckpointStore(config.l2SignalService), config.l1ChainId, config.etnaTimestamp
            )
        );
        console2.log("New anchorImpl deployed:", anchorImpl_);

        signalServiceImpl_ = address(
            new SignalServiceL2(
                config.anchorProxy, config.l1SignalService, config.signalServicePauser
            )
        );
        console2.log("New signalServiceImpl deployed:", signalServiceImpl_);
    }
}
