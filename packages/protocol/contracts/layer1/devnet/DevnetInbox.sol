// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxOptimized2 } from "src/layer1/core/impl/InboxOptimized2.sol";
import { LibFasterReentryLock } from "src/layer1/mainnet/LibFasterReentryLock.sol";

import "./DevnetInbox_Layout.sol"; // DO NOT DELETE

/// @title DevnetInbox
/// @dev This contract extends the base Inbox contract for devnet deployment
/// with optimized reentrancy lock implementation.
/// @custom:security-contact security@taiko.xyz
contract DevnetInbox is InboxOptimized2 {
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
    uint64 private constant _RING_BUFFER_SIZE = 100;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        address _codec,
        address _proofVerifier,
        address _proposerChecker,
        address _taikoToken,
        address _checkpointStore
    )
        InboxOptimized2(IInbox.Config({
                bondToken: _taikoToken,
                checkpointStore: _checkpointStore,
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
                forcedInclusionFeeInGwei: 10_000_000, // 0.01 ETH base fee
                forcedInclusionFeeDoubleThreshold: 50, // fee doubles at 50 pending
                minCheckpointDelay: 384 seconds, // 1 epoch
                permissionlessInclusionMultiplier: 5,
                compositeKeyVersion: 1
            }))
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
