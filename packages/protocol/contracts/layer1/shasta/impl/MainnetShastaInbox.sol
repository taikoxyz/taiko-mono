// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized4 } from "./InboxOptimized4.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibFasterReentryLock } from "../../mainnet/libs/LibFasterReentryLock.sol";
import { LibL1Addrs } from "../../mainnet/libs/LibL1Addrs.sol";

/// @title MainnetShastaInbox
/// @dev This contract extends the base Inbox contract for mainnet deployment
/// with optimized reentrancy lock implementation and efficient hashing.
/// @dev DEPLOYMENT: CRITICAL - Must use FOUNDRY_PROFILE=layer1o for mainnet deployment.
///      Contract size (26,455 bytes) exceeds 24KB limit without optimization.
///      Example: FOUNDRY_PROFILE=layer1o forge build
/// contracts/layer1/shasta/impl/MainnetShastaInbox.sol
/// @custom:security-contact security@taiko.xyz
contract MainnetShastaInbox is InboxOptimized4 {
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
        address _proposerChecker
    )
        InboxOptimized4(
            IInbox.Config({
                bondToken: LibL1Addrs.TAIKO_TOKEN,
                checkpointManager: _checkpointManager,
                proofVerifier: _proofVerifier,
                proposerChecker: _proposerChecker,
                provingWindow: 2 hours,
                extendedProvingWindow: 4 hours,
                maxFinalizationCount: 16,
                finalizationGracePeriod: 768 seconds,
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 0,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 100,
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
