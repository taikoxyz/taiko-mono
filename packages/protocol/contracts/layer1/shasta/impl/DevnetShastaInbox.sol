// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized4 } from "./InboxOptimized4.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibFasterReentryLock } from "../../mainnet/libs/LibFasterReentryLock.sol";

/// @title DevnetShastaInbox
/// @dev This contract extends the base Inbox contract for devnet deployment
/// with optimized reentrancy lock implementation.
/// @dev DEPLOYMENT: CRITICAL - Must use FOUNDRY_PROFILE=layer1o for deployment.
///      Contract size (26,293 bytes) exceeds 24KB limit without optimization.
///      Example: FOUNDRY_PROFILE=layer1o forge build
/// contracts/layer1/shasta/impl/DevnetShastaInbox.sol
/// @custom:security-contact security@taiko.xyz
contract DevnetShastaInbox is InboxOptimized4 {
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
        address _checkpointManager,
        address _proofVerifier,
        address _proposerChecker,
        address _taikoToken
    )
        InboxOptimized4(
            IInbox.Config({
                bondToken: _taikoToken,
                checkpointManager: _checkpointManager,
                proofVerifier: _proofVerifier,
                proposerChecker: _proposerChecker,
                provingWindow: 2 hours,
                extendedProvingWindow: 4 hours,
                maxFinalizationCount: 16,
                finalizationGracePeriod: 768 seconds,
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 75,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 12 seconds,
                forcedInclusionFeeInGwei: 10_000_000 // 0.01 ETH
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
