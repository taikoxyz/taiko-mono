// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized3 } from "./InboxOptimized3.sol";
import { LibFasterReentryLock } from "../../mainnet/libs/LibFasterReentryLock.sol";

/// @title MainnetShastaInbox
/// @dev This contract extends the base Inbox contract for mainnet deployment
/// with optimized reentrancy lock implementation.
/// @custom:security-contact security@taiko.xyz
contract DevnetShastaInbox is InboxOptimized3 {
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
        InboxOptimized3(
            _taikoToken,
            _checkpointManager,
            _proofVerifier,
            _proposerChecker,
            2 hours, // provingWindow
            4 hours, // extendedProvingWindow
            16, // maxFinalizationCount
            _RING_BUFFER_SIZE, // ringBufferSize
            75, // basefeeSharingPctg
            1, // minForcedInclusionCount
            100, // forcedInclusionDelay
            10_000_000 // forcedInclusionFeeInGwei (0.01 ETH)
        )
    { }

    // ---------------------------------------------------------------
    // External/Public Functions
    // ---------------------------------------------------------------

    // /// @notice Initializes the core state.
    // /// @param _coreState The core state.
    // function initCoreState(CoreState memory _coreState) external onlyOwner reinitializer(2) {
    //     require(_coreState.nextProposalId != 0, InvalidCoreState());

    //     coreStateHash = keccak256(abi.encode(_coreState));
    //     emit CoreStateSet(_coreState);
    // }

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
