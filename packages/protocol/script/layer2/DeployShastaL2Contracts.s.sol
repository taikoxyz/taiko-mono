// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SignalService } from "src/shared/signal/SignalService.sol";
import "test/shared/DeployCapability.sol";

/// @title DeployShastaL2Contracts
/// @notice Deploys the Etna L2 SignalService implementation without upgrading the proxy: the shared
/// SignalService with the `Anchor` proxy as its syncer and `beaconRootsFrom` set to the Etna fork
/// time (Etna SPEC START-10-5). The `Anchor` needs no Etna change, so the DAO proposal's L2 message
/// upgrades only the SignalService proxy (Etna SWITCH.md section 3).
abstract contract DeployShastaL2Contracts is DeployCapability {
    struct DeploymentConfig {
        uint64 l1ChainId;
        address l1SignalService;
        address l2SignalService;
        address anchorProxy;
        address signalServicePauser;
        uint64 etnaForkTime;
        uint64 l2ChainId;
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
        // A script run against another network would otherwise deploy a SignalService that
        // accepts checkpoints from an address that is not this network's Anchor.
        require(block.chainid == config.l2ChainId, "Wrong L2 chain");
        require(config.l2SignalService.code.length != 0, "L2_SIGNAL_SERVICE has no code");
        require(config.anchorProxy.code.length != 0, "ANCHOR_PROXY has no code");
        // The new SignalService accepts checkpoints only from this Anchor, which must already save
        // into this SignalService for this L1.
        require(
            _readWord(config.anchorProxy, "checkpointStore()")
                == uint256(uint160(config.l2SignalService)),
            "ANCHOR_PROXY checkpoint store mismatch"
        );
        require(
            _readWord(config.anchorProxy, "l1ChainId()") == config.l1ChainId,
            "ANCHOR_PROXY L1 chain id mismatch"
        );
        // On a running network the fork time must lie in the future, or the upgrade would close
        // the checkpoint store at once and every anchorV4 would revert. This checks only deploy
        // time. The DAO proposal's L2 message must execute well before the Unzen propose cutoff,
        // so the first Etna block already sees the cutoff (Etna SWITCH.md section 3).
        require(config.etnaForkTime > block.timestamp, "ETNA_FORK_TIME not in the future");
        // ETNA_FORK_TIME is a uint48 in the EtnaInbox; a larger value could never match it.
        require(config.etnaForkTime <= type(uint48).max, "ETNA_FORK_TIME above 2^48 - 1");
    }

    /// @dev Reads one 32-byte word from a getter of a live contract.
    /// @param _target The contract.
    /// @param _signature The getter's signature.
    /// @return word_ The returned word.
    function _readWord(
        address _target,
        string memory _signature
    )
        internal
        view
        returns (uint256 word_)
    {
        (bool ok, bytes memory ret) = _target.staticcall(abi.encodeWithSignature(_signature));
        require(ok && ret.length == 32, "Live getter unreadable");
        return abi.decode(ret, (uint256));
    }

    /// @dev Preserves an existing immutable pauser when deploying a replacement implementation.
    /// @param _signalService Existing L2 SignalService proxy.
    /// @return pauser_ Existing pauser, or zero for a pre-pauser implementation.
    function _readSignalServicePauser(address _signalService)
        internal
        view
        returns (address pauser_)
    {
        // A call to an address without code succeeds with no data, which would read as zero.
        require(_signalService.code.length != 0, "L2_SIGNAL_SERVICE has no code");
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

    /// @dev Deploys the SignalService implementation without upgrading the proxy: it accepts
    /// checkpoints only from the Anchor proxy until the fork time, proves against the L1
    /// SignalService and resolves roots through EIP-4788 from the fork time on.
    /// @param config The validated deployment configuration.
    /// @return signalServiceImpl_ The new SignalService implementation.
    function _deploy(DeploymentConfig memory config) internal returns (address signalServiceImpl_) {
        signalServiceImpl_ = address(
            new SignalService(
                config.anchorProxy,
                config.l1SignalService,
                config.signalServicePauser,
                config.etnaForkTime
            )
        );
        console2.log("New signalServiceImpl deployed:", signalServiceImpl_);
        console2.log("beaconRootsFrom:", config.etnaForkTime);
    }
}
