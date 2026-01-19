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
    uint48 private constant _RING_BUFFER_SIZE = 100;

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
        // See `MainnetInbox.sol` for details on the configuration.
        Inbox(Config({
                proofVerifier: _proofVerifier,
                proposerChecker: _proposerChecker,
                proverWhitelist: _proverWhitelist,
                signalService: _signalService,
                bondToken: _bondToken,
                minBond: 0,
                livenessBond: 0,
                withdrawalDelay: 1 weeks,
                provingWindow: 4 hours, 
                permissionlessProvingDelay: 5 days,
                maxProofSubmissionDelay: 3 minutes, 
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 75,
                forcedInclusionDelay: 576 seconds,
                forcedInclusionFeeInGwei: 1_000_000,
                forcedInclusionFeeDoubleThreshold: 50,
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
