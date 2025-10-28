// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { InboxOptimized2 } from "src/layer1/core/impl/InboxOptimized2.sol";
import { LibFasterReentryLock } from "src/layer1/mainnet/LibFasterReentryLock.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";

/// @title ShastaMainnetInbox
/// @dev This contract extends the base Inbox contract for mainnet deployment
/// with optimized reentrancy lock implementation and efficient hashing.
/// @custom:security-contact security@taiko.xyz
contract MainnetInbox is InboxOptimized2 {
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
        address _codec,
        address _proofVerifier,
        address _proposerChecker
    )
        InboxOptimized2(IInbox.Config({
                bondToken: LibL1Addrs.TAIKO_TOKEN,
                checkpointStore: LibL1Addrs.SIGNAL_SERVICE,
                codec: _codec,
                proofVerifier: _proofVerifier,
                proposerChecker: _proposerChecker,
                provingWindow: 4 hours,
                extendedProvingWindow: 8 hours,
                maxFinalizationCount: 16,
                finalizationGracePeriod: 768 seconds, // 2 epochs
                ringBufferSize: _RING_BUFFER_SIZE,
                basefeeSharingPctg: 0,
                minForcedInclusionCount: 1,
                forcedInclusionDelay: 100,
                forcedInclusionFeeInGwei: 10_000_000, // 0.01 ETH
                minCheckpointDelay: 384 seconds, // 1 epoch
                permissionlessInclusionMultiplier: 5,
                compositeKeyVersion: 1
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

// Storage Layout ---------------------------------------------------------------
// solhint-disable max-line-length
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   _shastaInitializer             | address                                            | Slot: 251  | Offset: 0    | Bytes: 20
//   conflictingTransitionDetected  | bool                                               | Slot: 251  | Offset: 20   | Bytes: 1
//   _proposalHashes                | mapping(uint256 => bytes32)                        | Slot: 252  | Offset: 0    | Bytes: 32
//   _transitionRecordHashAndDeadline | mapping(bytes32 => struct Inbox.TransitionRecordHashAndDeadline) | Slot: 253  | Offset: 0    | Bytes: 32
//   _forcedInclusionStorage        | struct LibForcedInclusion.Storage                  | Slot: 254  | Offset: 0    | Bytes: 64
//   __gap                          | uint256[37]                                        | Slot: 256  | Offset: 0    | Bytes: 1184
//   _reusableTransitionRecords     | mapping(uint256 => struct InboxOptimized1.ReusableTransitionRecord) | Slot: 293  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[49]                                        | Slot: 294  | Offset: 0    | Bytes: 1568
//   __gap                          | uint256[50]                                        | Slot: 343  | Offset: 0    | Bytes: 1600
// solhint-enable max-line-length

// Storage Layout ---------------------------------------------------------------
// solhint-disable max-line-length
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   _shastaInitializer             | address                                            | Slot: 251  | Offset: 0    | Bytes: 20
//   conflictingTransitionDetected  | bool                                               | Slot: 251  | Offset: 20   | Bytes: 1
//   _proposalHashes                | mapping(uint256 => bytes32)                        | Slot: 252  | Offset: 0    | Bytes: 32
//   _transitionRecordHashAndDeadline | mapping(bytes32 => struct Inbox.TransitionRecordHashAndDeadline) | Slot: 253  | Offset: 0    | Bytes: 32
//   _forcedInclusionStorage        | struct LibForcedInclusion.Storage                  | Slot: 254  | Offset: 0    | Bytes: 64
//   __gap                          | uint256[37]                                        | Slot: 256  | Offset: 0    | Bytes: 1184
//   _reusableTransitionRecords     | mapping(uint256 => struct InboxOptimized1.ReusableTransitionRecord) | Slot: 293  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[49]                                        | Slot: 294  | Offset: 0    | Bytes: 1568
//   __gap                          | uint256[50]                                        | Slot: 343  | Offset: 0    | Bytes: 1600
// solhint-enable max-line-length
