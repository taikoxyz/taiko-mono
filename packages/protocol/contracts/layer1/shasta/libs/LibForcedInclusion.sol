// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
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

    /// @notice Saves a forced inclusion request to the queue
    /// @dev Validates the blob reference and checks the fee before saving
    /// @param $ The storage reference for the forced inclusion queue
    /// @param _forcedInclusionFeeInGwei The fee in Gwei for the forced inclusion
    /// @param _blobReference The blob reference containing transaction data
    function saveForcedInclusion(
        Storage storage $,
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
    /// @return inclusions_ Array of consumed forced inclusions (may be less than _count if queue
    /// has fewer)
    function consumeForcedInclusions(
        Storage storage $,
        address _feeRecipient,
        uint256 _count
    )
        public
        returns (IForcedInclusionStore.ForcedInclusion[] memory inclusions_)
    {
        unchecked {
            // Early exit if no inclusions requested
            if (_count == 0) {
                return new IForcedInclusionStore.ForcedInclusion[](0);
            }

            (uint48 head, uint48 tail) = ($.head, $.tail);

            // Early exit if  queue is empty
            if (head == tail) {
                return new IForcedInclusionStore.ForcedInclusion[](0);
            }

            // Calculate actual number to process (min of requested and available)
            uint256 available = tail - head;
            uint256 toProcess = _count > available ? available : _count;

            inclusions_ = new IForcedInclusionStore.ForcedInclusion[](toProcess);
            uint256 totalFees;

            for (uint256 i; i < toProcess; ++i) {
                inclusions_[i] = $.queue[head + i];
                totalFees += inclusions_[i].feeInGwei;
            }

            // Update head and lastProcessedAt after all processing
            ($.head, $.lastProcessedAt) = (head + uint48(toProcess), uint48(block.timestamp));

            // Send all fees in one transfer
            if (totalFees > 0) {
                _feeRecipient.sendEtherAndVerify(totalFees * 1 gwei);
            }
        }
    }

    /// @notice Retrieves the effective timestamp for forced inclusions.
    /// @dev Returns the timestamp of the oldest forced inclusion in the queue or the last processed
    /// timestamp if the queue is empty.
    /// @param $ The storage reference for forced inclusion data.
    /// @return The effective timestamp as a uint256.
    function getOldestInclusionEffectiveTimestamp(Storage storage $) public view returns (uint48) {
        (uint48 head, uint48 tail, uint48 lastProcessedAt) = ($.head, $.tail, $.lastProcessedAt);
        if (head == tail) {
            return lastProcessedAt;
        }

        uint48 oldestTimestamp = $.queue[head].blobSlice.timestamp;
        if (oldestTimestamp == 0) {
            return type(uint48).max;
        }
        return oldestTimestamp > lastProcessedAt ? oldestTimestamp : lastProcessedAt;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error IncorrectFee();
}
