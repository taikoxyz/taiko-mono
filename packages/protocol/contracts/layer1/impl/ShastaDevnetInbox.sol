// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized2 } from "./InboxOptimized2.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibFasterReentryLock } from "../libs/LibFasterReentryLock.sol";

/// @title ShastaDevnetInbox
/// @dev This contract extends the base Inbox contract for devnet deployment
/// with optimized reentrancy lock implementation.
/// @custom:security-contact security@taiko.xyz
contract ShastaDevnetInbox is InboxOptimized2 {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    /// @dev Ring buffer size for storing proposal hashes.
    /// Assumptions:
    /// - D = 2: Proposals may continue without finalization for up to 2 days.
    /// - P = 6: On average, 1 proposal is submitted every 6 Ethereum slots (≈72s).
    ///
    /// Calculation:
    ///   _RING_BUFFER_SIZE = (86400 * D) / 12 / P
    ///                     = (86400 * 2) / 12 / 6
    ///                     = 2400
    uint64 private constant _RING_BUFFER_SIZE = 2400;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        address _codec,
        address _proofVerifier,
        address _proposerChecker,
        address _taikoToken,
        address _signalService
    )
        InboxOptimized2(
            IInbox.Config({
                bondToken: _taikoToken,
                signalService: _signalService,
                codec: _codec,
                proofVerifier: _proofVerifier,
                proposerChecker: _proposerChecker,
                provingWindow: 2 hours,
                extendedProvingWindow: 4 hours,
                maxFinalizationCount: 16,
                finalizationGracePeriod: 768 seconds, // 2 epochs
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 75,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 0,
                forcedInclusionFeeInGwei: 10_000_000, // 0.01 ETH
                minCheckpointDelay: 384 seconds, // 1 epoch
                permissionlessInclusionMultiplier: 5,
                compositeKeyVersion: 1
            })
        )
    { }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidCoreState();
}
