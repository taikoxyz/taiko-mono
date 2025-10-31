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
        (uint48 head, uint48 tail) = ($.head, $.tail);
        uint256 numPending = uint256(tail - head);

        // Linear scaling formula: fee = baseFee × (threshold + numPending) / threshold
        // This is mathematically equivalent to: fee = baseFee × (1 + numPending / threshold)
        // but avoids floating point arithmetic
        uint256 multipliedFee = _baseFeeInGwei * (_feeDoubleThreshold + numPending);
        feeInGwei_ = uint64(multipliedFee / _feeDoubleThreshold);
    }

    /// @dev See `IForcedInclusionStore.isOldestForcedInclusionDue`
    function isOldestForcedInclusionDue(
        Storage storage $,
        uint16 _forcedInclusionDelay
    )
        public
        view
        returns (bool)
    {
        (uint48 head, uint48 tail, uint48 lastProcessedAt) = ($.head, $.tail, $.lastProcessedAt);
        return isOldestForcedInclusionDue($, head, tail, lastProcessedAt, _forcedInclusionDelay);
    }

    // ---------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------

    /// @dev Checks if the oldest remaining forced inclusion is due (internal variant with
    /// parameters)
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
}
