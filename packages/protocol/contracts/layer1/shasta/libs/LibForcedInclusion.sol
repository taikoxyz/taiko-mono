// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
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
    using LibAddress for address;
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
        uint16, /* _forcedInclusionDelay */
        uint64 _forcedInclusionFeeInGwei,
        LibBlobs.BlobReference memory _blobReference
    )
        public
    {
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(_blobReference);

        require(msg.value == _forcedInclusionFeeInGwei * 1 gwei, IncorrectFee());

        IForcedInclusionStore.ForcedInclusion memory inclusion = IForcedInclusionStore
            .ForcedInclusion({ feeInGwei: _forcedInclusionFeeInGwei, blobSlice: blobSlice });

        $.queue[$.tail++] = inclusion;

        emit IForcedInclusionStore.ForcedInclusionSaved(inclusion);
    }

    /// @dev Internal implementation of consuming forced inclusions
    /// @notice Consumes up to _count forced inclusions from the queue
    /// @param _feeRecipient The address to receive the fees from all consumed inclusions
    /// @param _count The maximum number of forced inclusions to consume
    /// @return sources_ Array of derivation sources with forced inclusions marked and an extra
    /// empty
    /// slot at the end for the normal source. The array size is toProcess + 1, where the last slot
    /// is uninitialized for the caller to populate.
    /// @return availableAfter_ Number of forced inclusions remaining in the queue after consuming
    /// @return oldestForcedInclusionTimestamp_ The timestamp of the oldest forced inclusion that
    /// was
    /// processed. block.timestamp if no forced inclusions were consumed.
    function consumeForcedInclusions(
        Storage storage $,
        address _feeRecipient,
        uint256 _count
    )
        internal
        returns (
            IInbox.DerivationSource[] memory sources_,
            uint256 availableAfter_,
            uint48 oldestForcedInclusionTimestamp_
        )
    {
        unchecked {
            (uint48 head, uint48 tail, uint48 lastProcessedAt) = ($.head, $.tail, $.lastProcessedAt);

            // Calculate actual number to process (min of requested and available)
            uint256 available = tail - head;
            uint256 toProcess = _count > available ? available : _count;

            // Allocate array with an extra slot for the normal derivation source
            sources_ = new IInbox.DerivationSource[](toProcess + 1);
            uint256 totalFees;

            for (uint256 i; i < toProcess; ++i) {
                IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[head + i];
                sources_[i] = IInbox.DerivationSource(true, inclusion.blobSlice);
                totalFees += inclusion.feeInGwei;
            }

            // Calculate oldest forced inclusion timestamp
            if (toProcess > 0) {
                oldestForcedInclusionTimestamp_ =
                    uint48(sources_[0].blobSlice.timestamp.max(lastProcessedAt));
            } else {
                oldestForcedInclusionTimestamp_ = uint48(block.timestamp);
            }

            // Update head and lastProcessedAt after all processing
            ($.head, $.lastProcessedAt) = (head + uint48(toProcess), uint48(block.timestamp));

            // Calculate remaining available inclusions using already known values
            availableAfter_ = available - toProcess;

            // Send all fees in one transfer
            if (totalFees > 0) {
                _feeRecipient.sendEtherAndVerify(totalFees * 1 gwei);
            }
        }
    }

    /// @dev See `IInbox.isOldestForcedInclusionDue`
    function isOldestForcedInclusionDue(
        Storage storage $,
        uint16 _forcedInclusionDelay
    )
        public
        view
        returns (bool)
    {
        (uint48 head, uint48 tail, uint48 lastProcessedAt) = ($.head, $.tail, $.lastProcessedAt);

        // Early exit for empty queue (most common case)
        if (head == tail) return false;

        uint256 timestamp = $.queue[head].blobSlice.timestamp;

        // Early exit if slot is empty
        if (timestamp == 0) return false;

        // Only calculate deadline if we have a valid inclusion
        unchecked {
            uint256 deadline = timestamp.max(lastProcessedAt) + _forcedInclusionDelay;
            return block.timestamp >= deadline;
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error IncorrectFee();
}
