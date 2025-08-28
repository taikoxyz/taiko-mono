// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized1 } from "src/layer1/shasta/impl/InboxOptimized1.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title TestInboxOptimized1
/// @notice Test wrapper for TestInboxOptimized1 contract with configurable behavior
contract TestInboxOptimized1 is InboxOptimized1 {
    Config private config;

    address private immutable _bondToken;
    address private immutable _checkpointManager;
    address private immutable _proofVerifier;
    address private immutable _proposerChecker;
    address private immutable _forcedInclusionStore;

    constructor(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    ) {
        _bondToken = bondToken;
        _checkpointManager = checkpointManager;
        _proofVerifier = proofVerifier;
        _proposerChecker = proposerChecker;
        _forcedInclusionStore = forcedInclusionStore;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return IInbox.Config({
            bondToken: _bondToken,
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            maxFinalizationCount: 16,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            checkpointManager: _checkpointManager,
            proofVerifier: _proofVerifier,
            proposerChecker: _proposerChecker,
            forcedInclusionStore: _forcedInclusionStore,
            minForcedInclusionCount: 1
        });
    }

    /// @dev Fills the buffer with a hash that has no meaning for the protocol. This simulates the
    /// upgrade from Pacaya to Shasta,
    ///      since this buffer will already be full since we are reusing the same slot.
    function fillTransitionRecordBuffer() public {
        IInbox.Config memory _config = getConfig();
        bytes32 value = bytes32(keccak256("transitionRecord"));

        for (uint256 i = 0; i < _config.ringBufferSize; i++) {
            _transitionRecordHashes[i][bytes32(0)] = value;
        }
    }
}
