// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxOptimized } from "src/layer1/core/impl/InboxOptimized.sol";
import { LibFasterReentryLock } from "src/layer1/mainnet/LibFasterReentryLock.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";

import "./MainnetInbox_Layout.sol"; // DO NOT DELETE

/// @title ShastaMainnetInbox
/// @dev This contract extends the base Inbox contract for mainnet deployment
/// with optimized reentrancy lock implementation and efficient hashing.
/// @custom:security-contact security@taiko.xyz
contract MainnetInbox is InboxOptimized {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    /// @dev Ring buffer size for storing proposal hashes.
    /// Assumptions:
    /// - D = 10: Buffer must hold at least 10 days of proposals.
    /// - P = 1: Sized for worst-case 1 proposal every slot (12s); expected cadence
    ///   is 1 proposal every 32 Ethereum slots (≈384s ≈6 minutes).
    ///
    /// Calculation:
    ///   _RING_BUFFER_SIZE = (86400 * D) / 12 / P
    ///                     = (86400 * 10) / 12 / 1
    ///                     = 72000
    uint64 private constant _RING_BUFFER_SIZE = 72_000;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        address _proofVerifier,
        address _proposerChecker,
        address _codec
    )
        InboxOptimized(IInbox.Config({
                bondToken: LibL1Addrs.TAIKO_TOKEN,
                codec: _codec,
                signalService: LibL1Addrs.SIGNAL_SERVICE,
                proofVerifier: _proofVerifier,
                proposerChecker: _proposerChecker,
                provingWindow: 4 hours,
                extendedProvingWindow: 8 hours,
                maxProofSubmissionDelay: 3 minutes, // We want this to be lower than the proposal cadence
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 0,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 384, // 1 epoch
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

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidCoreState();
}
