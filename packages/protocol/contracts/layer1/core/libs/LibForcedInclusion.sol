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

    /// @dev See `IInbox.storeForcedInclusion`
    function saveForcedInclusion(
        Storage storage $,
        uint64 _forcedInclusionFeeInGwei,
        LibBlobs.BlobReference memory _blobReference
    )
        public
    {
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(_blobReference);

        require(msg.value == _forcedInclusionFeeInGwei * 1 gwei, IncorrectFee());

        IForcedInclusionStore.ForcedInclusion memory inclusion =
            IForcedInclusionStore.ForcedInclusion({
                feeInGwei: _forcedInclusionFeeInGwei, blobSlice: blobSlice
            });

        $.queue[$.tail++] = inclusion;

        emit IForcedInclusionStore.ForcedInclusionSaved(inclusion);
    }

    /// @dev Returns `_maxCount` forced inclusions starting at `_start`.
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
            if (_maxCount == 0) {
                return inclusions_;
            }

            inclusions_ = new IForcedInclusionStore.ForcedInclusion[](_maxCount);

            for (uint256 i; i < _maxCount; ++i) {
                uint256 idx = uint256(_start) + i;
                inclusions_[i] = $.queue[idx];
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
        head_ = $.head;
        tail_ = $.tail;
        lastProcessedAt_ = $.lastProcessedAt;
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

    error IncorrectFee();
}
