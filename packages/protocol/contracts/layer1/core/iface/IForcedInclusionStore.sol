// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBlobs } from "../libs/LibBlobs.sol";

/// @title IForcedInclusionStore
/// @custom:security-contact security@taiko.xyz
interface IForcedInclusionStore {
    /// @notice Represents a forced inclusion that will be stored onchain.
    struct ForcedInclusion {
        /// @notice The fee in Gwei that was paid to submit the forced inclusion.
        uint64 feeInGwei;
        /// @notice The proposal's blob slice.
        LibBlobs.BlobSlice blobSlice;
    }

    /// @dev Event emitted when a forced inclusion is stored.
    event ForcedInclusionSaved(ForcedInclusion forcedInclusion);

    /// @notice Saves a forced inclusion request
    /// A priority fee must be paid to the contract
    /// @param _blobReference The blob locator that contains the transaction data
    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable;

    /// @notice Returns the current dynamic forced inclusion fee based on queue size
    /// The fee scales linearly with queue size using the formula:
    /// fee = baseFee × (1 + numPending / threshold)
    /// Examples with threshold = 100 and baseFee = 0.01 ETH:
    /// - 0 pending:   fee = 0.01 × (1 + 0/100)   = 0.01 ETH (1× base)
    /// - 50 pending:  fee = 0.01 × (1 + 50/100)  = 0.015 ETH (1.5× base)
    /// - 100 pending: fee = 0.01 × (1 + 100/100) = 0.02 ETH (2× base, DOUBLED)
    /// - 150 pending: fee = 0.01 × (1 + 150/100) = 0.025 ETH (2.5× base)
    /// - 200 pending: fee = 0.01 × (1 + 200/100) = 0.03 ETH (3× base, TRIPLED)
    /// @return feeInGwei_ The current fee in Gwei
    function getCurrentForcedInclusionFee() external view returns (uint64 feeInGwei_);

    /// @notice Returns forced inclusions stored starting from a given index.
    /// @dev Returns an empty array if `_start` is outside the valid range [head, tail) or if
    ///      `_maxCount` is zero. Otherwise returns actual stored entries from the queue.
    /// @param _start The queue index to start reading from (must be in range [head, tail)).
    /// @param _maxCount Maximum number of inclusions to return. Passing zero returns an empty array.
    /// @return inclusions_ Forced inclusions from the queue starting at `_start`. The actual length
    ///         will be `min(_maxCount, tail - _start)`, or zero if `_start` is out of range.
    function getForcedInclusions(
        uint48 _start,
        uint48 _maxCount
    )
        external
        view
        returns (ForcedInclusion[] memory inclusions_);

    /// @notice Returns the queue pointers for the forced inclusion store.
    /// @return head_ Index of the oldest forced inclusion in the queue.
    /// @return tail_ Index of the next free slot in the queue.
    /// @return lastProcessedAt_ Timestamp when the last forced inclusion was processed.
    function getForcedInclusionState()
        external
        view
        returns (uint48 head_, uint48 tail_, uint48 lastProcessedAt_);
}
