// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";

/// @title MockEtnaInbox
/// @notice The Inbox views the staking registry reads, set directly by tests, and a forwarder for
/// the registry's Inbox-only `forceExit`.
/// @dev Starts uninitialized, unlocked, at generation 0 and snapshot 0.
contract MockEtnaInbox {
    bool public isInitialized;
    uint256 public activeCommitteeSnapshot;
    uint48 public recoveryGeneration;
    bool public inNonReentrant;

    function setInitialized(bool _initialized) external {
        isInitialized = _initialized;
    }

    function setActiveCommitteeSnapshot(uint256 _snapshot) external {
        activeCommitteeSnapshot = _snapshot;
    }

    function setRecoveryGeneration(uint48 _generation) external {
        recoveryGeneration = _generation;
    }

    function setInNonReentrant(bool _locked) external {
        inNonReentrant = _locked;
    }

    /// @dev Calls `_registry.forceExit` as the Inbox.
    function forceExit(
        IEtnaStakingRegistry _registry,
        uint256 _bondId,
        bytes32 _entryKey
    )
        external
    {
        _registry.forceExit(_bondId, _entryKey);
    }
}
