// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

/// @title LibForcedInclusion
/// @dev Library for storing and managing forced inclusion requests. Forced inclusions
/// allow users to pay a fee to ensure their transactions are included in a block. The library
/// maintains a FIFO queue of inclusion requests.
/// @dev Inclusion delay is measured in seconds, since we don't have an easy way to get batch number
/// in the Shasta design.
/// @dev We only allow one forced inclusion per L1 transaction to avoid spamming the proposer.
/// @dev Forced inclusions are limited to 1 blob only, and one L2 block only(this and other protocol
/// constrains are enforced by the node and verified by the prover)
/// @custom:security-contact security@taiko.xyz
library LibForcedInclusion {
    using LibMath for uint48;
    using LibMath for uint256;

    // ---------------------------------------------------------------
    //  Structs
    // ---------------------------------------------------------------

    /// @dev Storage for the forced inclusion queue. This struct uses 2 slots.
    /// @dev 2 slots used
    struct Storage {
        mapping(uint256 id => IForcedInclusionStore.ForcedInclusion inclusion) queue;
        /// @notice The index of the oldest forced inclusion in the queue. This is where items will
        /// be dequeued.
        uint48 head;
        /// @notice The index of the next free slot in the queue. This is where items will be
        /// enqueued.
        uint48 tail;
        /// @notice The last time a forced inclusion was processed.
        uint48 lastProcessedAt;
    }

    // ---------------------------------------------------------------
    //  Public Functions
    // ---------------------------------------------------------------

    /// @dev See `IForcedInclusionStore.saveForcedInclusion`
    function saveForcedInclusion(
        Storage storage $,
        uint64 _baseFeeInGwei,
        uint64 _feeDoubleThreshold,
        LibBlobs.BlobReference memory _blobReference
    )
        public
        returns (uint256 refund_)
    {
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(_blobReference);

        uint64 requiredFeeInGwei =
            getCurrentForcedInclusionFee($, _baseFeeInGwei, _feeDoubleThreshold);
        uint256 requiredFee = requiredFeeInGwei * 1 gwei;
        require(msg.value >= requiredFee, InsufficientFee());

        IForcedInclusionStore.ForcedInclusion memory inclusion =
            IForcedInclusionStore.ForcedInclusion({
                feeInGwei: requiredFeeInGwei, blobSlice: blobSlice
            });

        $.queue[$.tail++] = inclusion;

        emit IForcedInclusionStore.ForcedInclusionSaved(inclusion);

        // Calculate and return refund amount
        unchecked {
            refund_ = msg.value - requiredFee;
        }
    }

    /// @dev See `IForcedInclusionStore.getCurrentForcedInclusionFee`
    function getCurrentForcedInclusionFee(
        Storage storage $,
        uint64 _baseFeeInGwei,
        uint64 _feeDoubleThreshold
    )
        public
        view
        returns (uint64 feeInGwei_)
    {
        require(_feeDoubleThreshold > 0, InvalidFeeDoubleThreshold());

        (uint48 head, uint48 tail) = ($.head, $.tail);
        uint256 numPending = uint256(tail - head);

        // Linear scaling formula: fee = baseFee × (threshold + numPending) / threshold
        // This is mathematically equivalent to: fee = baseFee × (1 + numPending / threshold)
        // but avoids floating point arithmetic
        uint256 multipliedFee = _baseFeeInGwei * (_feeDoubleThreshold + numPending);
        feeInGwei_ = uint64((multipliedFee / _feeDoubleThreshold).min(type(uint64).max));
    }

    /// @notice Returns forced inclusions stored starting from a given index.
    /// @dev Returns an empty array if `_start` is outside the valid range [head, tail) or if
    ///      `_maxCount` is zero. Otherwise returns actual stored entries from the queue.
    /// @param _start The queue index to start reading from (must be in range [head, tail)).
    /// @param _maxCount Maximum number of inclusions to return. Passing zero returns an empty array.
    /// @return inclusions_ Forced inclusions from the queue starting at `_start`. The actual length
    ///         will be `min(_maxCount, tail - _start)`, or zero if `_start` is out of range.
    function getForcedInclusions(
        Storage storage $,
        uint48 _start,
        uint48 _maxCount
    )
        internal
        view
        returns (IForcedInclusionStore.ForcedInclusion[] memory inclusions_)
    {
        unchecked {
            (uint48 head, uint48 tail) = ($.head, $.tail);

            if (_start < head || _start >= tail || _maxCount == 0) {
                return new IForcedInclusionStore.ForcedInclusion[](0);
            }

            uint256 count = uint256(tail - _start).min(_maxCount);

            inclusions_ = new IForcedInclusionStore.ForcedInclusion[](count);

            for (uint256 i; i < count; ++i) {
                inclusions_[i] = $.queue[i + _start];
            }
        }
    }

    /// @dev Returns the queue pointers for the forced inclusion storage.
    /// @param $ Storage instance tracking the forced inclusion queue.
    /// @return head_ Index of the next forced inclusion to dequeue.
    /// @return tail_ Index where the next forced inclusion will be enqueued.
    /// @return lastProcessedAt_ Timestamp of the most recent forced inclusion processing.
    function getForcedInclusionState(Storage storage $)
        internal
        view
        returns (uint48 head_, uint48 tail_, uint48 lastProcessedAt_)
    {
        (head_, tail_, lastProcessedAt_) = ($.head, $.tail, $.lastProcessedAt);
    }

    // ---------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------

    /// @dev Checks if the oldest remaining forced inclusion is due
    /// @param $ Storage reference
    /// @param _head Current queue head position
    /// @param _tail Current queue tail position
    /// @param _lastProcessedAt Timestamp of last processing
    /// @param _forcedInclusionDelay Delay in seconds before inclusion is due
    /// @return True if the oldest remaining inclusion is due for processing
    function isOldestForcedInclusionDue(
        Storage storage $,
        uint48 _head,
        uint48 _tail,
        uint48 _lastProcessedAt,
        uint16 _forcedInclusionDelay
    )
        internal
        view
        returns (bool)
    {
        unchecked {
            if (_head == _tail) return false;

            uint256 timestamp = $.queue[_head].blobSlice.timestamp;
            if (timestamp == 0) return false;

            return block.timestamp >= timestamp.max(_lastProcessedAt) + _forcedInclusionDelay;
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InsufficientFee();
    error InvalidFeeDoubleThreshold();
}
