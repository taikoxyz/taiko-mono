// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/src/Script.sol";
import {console2} from "forge-std/src/console2.sol";

interface IBridgeInit3 {
    function init3(bytes32[] calldata _msgHashes) external;
}

interface IInboxInit2 {
    function init2(uint48 _lastFinalizedProposalId, bytes32 _lastFinalizedBlockHash) external;
}

/// @title RunPostUpgradeInitializers
/// @notice Runs Bridge.init3(bytes32[]) and Inbox.init2(uint48,bytes32) after L1 upgrades.
/// @custom:security-contact security@taiko.xyz
contract RunPostUpgradeInitializers is Script {
    struct InitConfig {
        address bridgeProxy;
        bytes32[] bridgeMsgHashes;
        address inboxProxy;
        uint256 lastFinalizedProposalId;
        bytes32 lastFinalizedBlockHash;
        bool runBridgeInit3;
        bool runInboxInit2;
    }

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        if (privateKey == 0) revert InvalidPrivateKey();
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    function run() external broadcast {
        InitConfig memory config = _loadConfig();
        _validateConfig(config);
        _runInitializers(config);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    function _loadConfig() private view returns (InitConfig memory config_) {
        config_.runBridgeInit3 = vm.envOr("RUN_BRIDGE_INIT3", true);
        config_.runInboxInit2 = vm.envOr("RUN_INBOX_INIT2", true);

        if (config_.runBridgeInit3) {
            config_.bridgeProxy = vm.envAddress("BRIDGE_PROXY");
            config_.bridgeMsgHashes = vm.envBytes32("BRIDGE_MSG_HASHES", ",");
        }

        if (config_.runInboxInit2) {
            config_.inboxProxy = vm.envAddress("INBOX_PROXY");
            config_.lastFinalizedProposalId = vm.envUint("INBOX_LAST_FINALIZED_PROPOSAL_ID");
            config_.lastFinalizedBlockHash = vm.envBytes32("INBOX_LAST_FINALIZED_BLOCK_HASH");
        }
    }

    function _validateConfig(InitConfig memory _config) private pure {
        if (!_config.runBridgeInit3 && !_config.runInboxInit2) revert NothingToRun();

        if (_config.runBridgeInit3) {
            _validateAddress("BRIDGE_PROXY", _config.bridgeProxy);
            if (_config.bridgeMsgHashes.length == 0) revert EmptyBridgeMsgHashes();

            for (uint256 i; i < _config.bridgeMsgHashes.length; ++i) {
                if (_config.bridgeMsgHashes[i] == bytes32(0)) revert BridgeMsgHashIsZero(i);
            }
        }

        if (_config.runInboxInit2) {
            _validateAddress("INBOX_PROXY", _config.inboxProxy);
            if (_config.lastFinalizedProposalId > type(uint48).max) {
                revert LastFinalizedProposalIdTooLarge(_config.lastFinalizedProposalId);
            }
            if (_config.lastFinalizedBlockHash == bytes32(0)) revert LastFinalizedBlockHashIsZero();
        }
    }

    function _runInitializers(InitConfig memory _config) private {
        if (_config.runBridgeInit3) {
            console2.log("BRIDGE_PROXY=", _config.bridgeProxy);
            console2.log("BRIDGE_MSG_HASHES length=", _config.bridgeMsgHashes.length);
            IBridgeInit3(_config.bridgeProxy).init3(_config.bridgeMsgHashes);
            console2.log("Bridge.init3 completed");
        }

        if (_config.runInboxInit2) {
            uint48 lastFinalizedProposalId = uint48(_config.lastFinalizedProposalId);
            console2.log("INBOX_PROXY=", _config.inboxProxy);
            console2.log("INBOX_LAST_FINALIZED_PROPOSAL_ID=", lastFinalizedProposalId);
            console2.logBytes32(_config.lastFinalizedBlockHash);
            IInboxInit2(_config.inboxProxy)
                .init2({
                    _lastFinalizedProposalId: lastFinalizedProposalId,
                    _lastFinalizedBlockHash: _config.lastFinalizedBlockHash
                });
            console2.log("Inbox.init2 completed");
        }
    }

    function _validateAddress(string memory _name, address _addr) private pure {
        if (_addr == address(0)) revert AddressIsZero(_name);
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidPrivateKey();
    error NothingToRun();
    error AddressIsZero(string name);
    error EmptyBridgeMsgHashes();
    error BridgeMsgHashIsZero(uint256 index);
    error LastFinalizedProposalIdTooLarge(uint256 value);
    error LastFinalizedBlockHashIsZero();
}
