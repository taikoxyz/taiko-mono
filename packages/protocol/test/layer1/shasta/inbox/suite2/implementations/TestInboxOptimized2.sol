// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized2 } from "src/layer1/shasta/impl/InboxOptimized2.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { IForcedInclusionStore } from "src/layer1/shasta/iface/IForcedInclusionStore.sol";

/// @title TestInboxOptimized2
/// @notice Test wrapper for TestInboxOptimized2 contract with configurable behavior
contract TestInboxOptimized2 is InboxOptimized2 {
    Config private config;

    address private immutable _bondToken;
    address private immutable _checkpointManager;
    address private immutable _proofVerifier;
    address private immutable _proposerChecker;

    constructor(
        address bondToken,
        address checkpointManager,
        address proofVerifier,
        address proposerChecker,
        uint64 inclusionDelay,
        uint64 feeInGwei
    )
        InboxOptimized2(inclusionDelay, feeInGwei)
    {
        _bondToken = bondToken;
        _checkpointManager = checkpointManager;
        _proofVerifier = proofVerifier;
        _proposerChecker = proposerChecker;
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
            minForcedInclusionCount: 1,
            forcedInclusionConfig: IForcedInclusionStore.Config({
                inclusionDelay: 100,
                feeInGwei: 1_000_000_000
            })
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
