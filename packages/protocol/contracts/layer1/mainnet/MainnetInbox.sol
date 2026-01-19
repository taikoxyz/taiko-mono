// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibFasterReentryLock } from "src/layer1/mainnet/LibFasterReentryLock.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";

import "./MainnetInbox_Layout.sol"; // DO NOT DELETE

/// @title ShastaMainnetInbox
/// @dev This contract extends the base Inbox contract for mainnet deployment
/// with optimized reentrancy lock implementation.
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
        address _bondToken
    )

        Inbox(Config({
                proofVerifier: _proofVerifier,
                proposerChecker: _proposerChecker,
                proverWhitelist: _proverWhitelist,
                signalService: LibL1Addrs.SIGNAL_SERVICE,
                bondToken: _bondToken,
                minBond: 0, // During prover whitelist, bond is not necessary
                livenessBond: 0,
                withdrawalDelay: 1 weeks,
                provingWindow: 4 hours, // internal target is still to submit every ~2 hours
                permissionlessProvingDelay: 5 days, // long enough that the security council can intervine in case of a bug
                maxProofSubmissionDelay: 3 minutes, // We want this to be lower than the expected cadence
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 75,
                forcedInclusionDelay: 576 seconds, // 1.5 epochs. Makes sure the proposer is not surprised by a forced inclusion landing on their preconf window.
                forcedInclusionFeeInGwei: 1_000_000, // 0.001 ETH base fee.
                forcedInclusionFeeDoubleThreshold: 50, // fee doubles at 50 pending
                permissionlessInclusionMultiplier: 160 // 160 * 1.5 epochs = 240 epochs = 24 hours. 
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
