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
        address _proverMarket,
        address _signalService
    )
        // See `MainnetInbox.sol` for details on the configuration.
        Inbox(Config({
                proofVerifier: _proofVerifier,
                proposerChecker: _proposerChecker,
                proverMarket: _proverMarket,
                signalService: _signalService,
                maxProofSubmissionDelay: 3 minutes,
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 75,
                forcedInclusionDelay: 0 seconds, // Devnet: immediate forced inclusion for faster testing
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
