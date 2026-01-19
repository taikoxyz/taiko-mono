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
    uint48 private constant _RING_BUFFER_SIZE = 100;

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
                signalService: LibL1Addrs.SIGNAL_SERVICE,
                bondToken: _bondToken,
                minBond: 0,
                livenessBond: 0,
                withdrawalDelay: 1 weeks,
                provingWindow: 4 hours, // internal target to submit every 2 hours
                permissionlessProvingDelay: 5 days, // long enough such that the security council can intervine
                maxProofSubmissionDelay: 3 minutes, // We want this to be lower than the expected cadence
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 75,
                minForcedInclusionCount: 3, // TODO: remove this, not a concern anymore. zk gas will fix it
                forcedInclusionDelay: 576 seconds, // 1.5 epochs. Makes sure the proposer is not surprised by a forced inclusion landing on their preconf window.
                forcedInclusionFeeInGwei: 1_000_000, // 0.001 ETH base fee. Too high??
                forcedInclusionFeeDoubleThreshold: 50, // fee doubles at 50 pending. TODO: we don't have an objective mechanism yet
                minCheckpointDelay: 384 * 4 seconds, // TODO: remove this, we expect to prove every ~2hs, so we can just checkpoint everytime
                permissionlessInclusionMultiplier: 160 // 160 * 1.5 epochs = 240 epochs = 24 hours. 
            })
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
