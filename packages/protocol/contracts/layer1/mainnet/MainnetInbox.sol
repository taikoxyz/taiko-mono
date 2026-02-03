// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibFasterReentryLock } from "src/layer1/mainnet/LibFasterReentryLock.sol";

import "./MainnetInbox_Layout.sol"; // DO NOT DELETE

/// @title MainnetInbox
/// @dev This contract extends the base Inbox contract for Shasta mainnet deployment with an
/// optimized reentrancy lock implementation.
/// @custom:security-contact security@taiko.xyz
contract MainnetInbox is Inbox {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    /// @dev Ring buffer size for storing proposal hashes.
    /// Sized for worst-case throughput (1 proposal per L1 slot) over 3 days without finalization:
    ///   _RING_BUFFER_SIZE = (3 days × 86_400) / 12 = 21_600
    uint48 private constant _RING_BUFFER_SIZE = 21_600;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        address _proofVerifier,
        address _proposerChecker,
        address _proverWhitelist,
        address _signalService,
        address _bondToken
    )
        Inbox(Config({
                proofVerifier: _proofVerifier,
                proposerChecker: _proposerChecker,
                proverWhitelist: _proverWhitelist,
                signalService: _signalService,
                bondToken: _bondToken,
                minBond: 0, // During prover whitelist, bonds are not necessary
                livenessBond: 0,
                withdrawalDelay: 1 weeks,
                provingWindow: 4 hours, // internal target is still to submit every ~2 hours
                // Allows the security council time to intervene if a bug is found.
                permissionlessProvingDelay: 5 days,
                maxProofSubmissionDelay: 3 minutes, // We want this to be lower than the expected cadence
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 75,
                minForcedInclusionCount: 10,
                // 1.5 epochs. Makes sure the proposer is not surprised by a forced inclusion landing on their window.
                forcedInclusionDelay: 576 seconds,
                forcedInclusionFeeInGwei: 1_000_000, // 0.001 ETH base fee.
                forcedInclusionFeeDoubleThreshold: 50, // fee doubles at 50 pending
                // 160 * 576s = 92_160s (~25.6 hours).
                permissionlessInclusionMultiplier: 160
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
