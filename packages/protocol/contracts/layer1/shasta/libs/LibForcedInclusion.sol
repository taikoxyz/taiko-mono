// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
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

    struct Storage {
        mapping(uint256 id => IForcedInclusionStore.ForcedInclusion inclusion) queue; //slot 1
        // --slot 2--
        /// @notice The index of the oldest forced inclusion in the queue. This is where items will
        /// be dequeued.
        uint64 head;
        /// @notice The index of the next free slot in the queue. This is where items will be
        /// enqueued.
        uint64 tail;
        /// @notice The last time a forced inclusion was processed.
        uint64 lastProcessedAt;
    }

    // ---------------------------------------------------------------
    //  Public Functions
    // ---------------------------------------------------------------

    /// @dev See `IInbox.storeForcedInclusion`
    function storeForcedInclusion(
        Storage storage $,
        IInbox.Config memory _config,
        LibBlobs.BlobReference memory _blobReference
    )
        public
    {
        LibBlobs.BlobSlice memory blobSlice =
            LibBlobs.validateBlobReference(_blobReference);

        require(msg.value == _config.forcedInclusionFeeInGwei * 1 gwei, IncorrectFee());

        IForcedInclusionStore.ForcedInclusion memory inclusion = IForcedInclusionStore.ForcedInclusion({
            feeInGwei: _config.forcedInclusionFeeInGwei,
            blobSlice: blobSlice
        });

        $.queue[$.tail++] = inclusion;

        emit IForcedInclusionStore.ForcedInclusionStored(inclusion);
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
        internal
        returns (IForcedInclusionStore.ForcedInclusion[] memory inclusions_)
    {
        // TODO: we need to optimize the storage access by ensuring only 1 SLOAD and 1 SSTORE per
        // this function call.
        // Early exit if no inclusions requested or queue is empty
        if (_count == 0 || $.head == $.tail) {
            return new IForcedInclusionStore.ForcedInclusion[](0);
        }

        // Calculate actual number to process (min of requested and available)
        uint256 available = $.tail - $.head;
        uint256 toProcess = _count > available ? available : _count;

        inclusions_ = new IForcedInclusionStore.ForcedInclusion[](toProcess);
        uint256 totalFees;

        unchecked {
            for (uint256 i; i < toProcess; ++i) {
                inclusions_[i] = $.queue[$.head + i];
                totalFees += inclusions_[i].feeInGwei;

                // Delete the inclusion from storage
                delete $.queue[$.head + i];
            }

            // Update head and lastProcessedAt after all processing
            $.head += uint64(toProcess);
            $.lastProcessedAt = uint64(block.timestamp);

            // Send all fees in one transfer
            if (totalFees > 0) {
                _feeRecipient.sendEtherAndVerify(totalFees * 1 gwei);
            }
        }
    }

    /// @dev See `IInbox.isOldestForcedInclusionDue`
    function isOldestForcedInclusionDue(
        Storage storage $,
        IInbox.Config memory _config
    )
        public
        view
        returns (bool)
    {
        // Early exit for empty queue (most common case)
        if ($.head == $.tail) return false;

        IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[$.head];
        // Early exit if slot is empty
        if (inclusion.blobSlice.timestamp == 0) return false;

        // Only calculate deadline if we have a valid inclusion
        unchecked {
            uint256 deadline = uint256($.lastProcessedAt).max(inclusion.blobSlice.timestamp)
                + _config.forcedInclusionDelay;
            return block.timestamp >= deadline;
        }
    }


    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error IncorrectFee();
}
