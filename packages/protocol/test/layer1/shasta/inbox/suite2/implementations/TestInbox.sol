// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title TestInbox
/// @notice Test wrapper for Inbox contract with configurable behavior
contract TestInbox is Inbox {
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
        Inbox(inclusionDelay, feeInGwei)
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
