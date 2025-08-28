// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized3 } from "src/layer1/shasta/impl/InboxOptimized3.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title TestInboxOptimized3
/// @notice Test wrapper for TestInboxOptimized3 contract with configurable behavior
contract TestInboxOptimized3 is InboxOptimized3 {
    address private immutable _bondToken;
    address private immutable _syncedBlockManager;
    address private immutable _proofVerifier;
    address private immutable _proposerChecker;
    address private immutable _forcedInclusionStore;

    constructor(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    ) {
        _bondToken = bondToken;
        _syncedBlockManager = syncedBlockManager;
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
            syncedBlockManager: _syncedBlockManager,
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
        IInbox.Config memory config = getConfig();
        bytes32 value = bytes32(keccak256("transitionRecord"));

        for (uint256 i = 0; i < config.ringBufferSize; i++) {
            _transitionRecordHashes[i][bytes32(0)] = value;
        }
    }
}
