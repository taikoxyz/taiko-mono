// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibFasterReentryLock } from "src/layer1/mainnet/LibFasterReentryLock.sol";

import "./DevnetInbox_Layout.sol"; // DO NOT DELETE

/// @title DevnetInbox
/// @dev This contract extends the base Inbox contract for devnet deployment
/// with optimized reentrancy lock implementation.
/// @custom:security-contact security@taiko.xyz
contract DevnetInbox is Inbox {
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
        address _proofVerifier,
        address _proposerChecker,
        address _proverWhitelist,
        address _signalService,
        address _bondToken,
        uint64 _minBond,
        uint64 _livenessBond,
        uint48 _withdrawalDelay
    )
        Inbox(Config({
                proofVerifier: _proofVerifier,
                proposerChecker: _proposerChecker,
                proverWhitelist: _proverWhitelist,
                signalService: _signalService,
                bondToken: _bondToken,
                minBond: _minBond,
                livenessBond: _livenessBond,
                withdrawalDelay: _withdrawalDelay,
                provingWindow: 2 hours,
                permissionlessProvingDelay: 24 hours,
                maxProofSubmissionDelay: 3 minutes, // We want this to be lower than the proposal cadence
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 75,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 0,
                forcedInclusionFeeInGwei: 10_000_000, // 0.01 ETH base fee
                forcedInclusionFeeDoubleThreshold: 50, // fee doubles at 50 pending
                minCheckpointDelay: 384 seconds, // 1 epoch
                permissionlessInclusionMultiplier: 5
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
}
