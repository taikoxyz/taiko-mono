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
    /// - D = 14: Proposals may continue without finalization for up to 14 days.
    /// - P = 6: On average, 1 proposal is submitted every 6 Ethereum slots (≈72s).
    ///
    /// Calculation:
    ///   _RING_BUFFER_SIZE = (86400 * D) / 12 / P
    ///                     = (86400 * 14) / 12 / 6
    ///                     = 16800
    uint64 private constant _RING_BUFFER_SIZE = 16_800;

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
