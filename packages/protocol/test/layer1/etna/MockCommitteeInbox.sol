// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";

/// @notice Explicit settlement source for registry-only tests; integration tests use the real Inbox.
contract MockCommitteeInbox {
    address public immutable stakingRegistry;
    uint64 public activeCommitteeSnapshot;
    bool public initialized = true;

    constructor(address _registry) {
        stakingRegistry = _registry;
    }

    /// @notice Advances settlement independently of the L1 block clock.
    function setActiveCommitteeSnapshot(uint64 _snapshot) external {
        require(_snapshot >= activeCommitteeSnapshot && _snapshot <= block.number);
        activeCommitteeSnapshot = _snapshot;
    }

    /// @notice Models a proxy whose genesis has not been initialized.
    function setInitialized(bool _initialized) external {
        initialized = _initialized;
    }

    /// @notice Returns a nonzero genesis checkpoint only after initialization.
    function lastCheckpoint() external view returns (IEtnaInbox.LandedCheckpoint memory) {
        return IEtnaInbox.LandedCheckpoint({
            height: 0, blockHash: initialized ? keccak256("test genesis") : bytes32(0)
        });
    }
}
