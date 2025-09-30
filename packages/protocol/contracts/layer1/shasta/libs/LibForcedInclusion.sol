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
    //  Errors
    // ---------------------------------------------------------------

    /// @dev Thrown when an unprocessed forced inclusion is due
    error UnprocessedForcedInclusionIsDue();

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

    /// @dev Result from consuming forced inclusions
    struct ConsumptionResult {
        IInbox.DerivationSource[] sources;
        bool allowsPermissionless;
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

        IForcedInclusionStore.ForcedInclusion memory inclusion = IForcedInclusionStore
            .ForcedInclusion({ feeInGwei: _forcedInclusionFeeInGwei, blobSlice: blobSlice });

        $.queue[$.tail++] = inclusion;

        emit IForcedInclusionStore.ForcedInclusionSaved(inclusion);
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
    //  Internal Functions
    // ---------------------------------------------------------------

    /// @dev Consumes forced inclusions from the queue and returns result with extra slot for normal
    /// source
    /// @param $ Storage reference
    /// @param _feeRecipient Address to receive accumulated fees
    /// @param _numForcedInclusionsRequested Maximum number of forced inclusions to consume
    /// @param _minForcedInclusionCount Minimum required count for validation
    /// @param _forcedInclusionDelay Delay in seconds before an inclusion is considered due
    /// @param _permissionlessInclusionMultiplier Multiplier for permissionless delay calculation
    /// @return result_ ConsumptionResult with sources array (size: processed + 1, last slot empty)
    /// and whether permissionless proposals are allowed
    function consumeForcedInclusions(
        Storage storage $,
        address _feeRecipient,
        uint256 _numForcedInclusionsRequested,
        uint256 _minForcedInclusionCount,
        uint16 _forcedInclusionDelay,
        uint8 _permissionlessInclusionMultiplier
    )
        internal
        returns (ConsumptionResult memory result_)
    {
        unchecked {
            // Load storage once
            (uint48 head, uint48 tail, uint48 lastProcessedAt) = ($.head, $.tail, $.lastProcessedAt);

            uint256 available = tail - head;
            uint256 toProcess = _numForcedInclusionsRequested > available
                ? available
                : _numForcedInclusionsRequested;

            // Allocate array with extra slot for normal source
            result_.sources = new IInbox.DerivationSource[](toProcess + 1);

            // Process inclusions if any
            uint48 oldestTimestamp;
            (oldestTimestamp, head, lastProcessedAt) = _consumeAndUpdateStorage(
                $, _feeRecipient, result_.sources, head, lastProcessedAt, toProcess
            );

            // Calculate remaining and validate
            _validateForcedInclusionRequirements(
                $,
                _numForcedInclusionsRequested,
                _minForcedInclusionCount,
                available - toProcess,
                head,
                lastProcessedAt,
                _forcedInclusionDelay
            );

            // Check if permissionless proposals are allowed
            result_.allowsPermissionless = block.timestamp
                > uint256(_forcedInclusionDelay) * _permissionlessInclusionMultiplier + oldestTimestamp;
        }
    }

    // ---------------------------------------------------------------
    //  Private Functions
    // ---------------------------------------------------------------

    /// @dev Processes forced inclusions and returns total fees
    /// @param $ Storage reference
    /// @param sources Array to populate with derivation sources
    /// @param head Starting index in the queue
    /// @param count Number of inclusions to process
    /// @return totalFees Total fees accumulated from all processed inclusions
    function _processInclusions(
        Storage storage $,
        IInbox.DerivationSource[] memory sources,
        uint48 head,
        uint256 count
    )
        private
        view
        returns (uint256 totalFees)
    {
        unchecked {
            for (uint256 i; i < count; ++i) {
                IForcedInclusionStore.ForcedInclusion storage inclusion = $.queue[head + i];
                sources[i] = IInbox.DerivationSource(true, inclusion.blobSlice);
                totalFees += inclusion.feeInGwei;
            }
        }
    }

    /// @dev Consumes forced inclusions and updates storage
    /// @param $ Storage reference
    /// @param _feeRecipient Address to receive fees
    /// @param _sources Array to populate with derivation sources
    /// @param _head Current queue head position
    /// @param _lastProcessedAt Timestamp of last processing
    /// @param _toProcess Number of inclusions to process
    /// @return oldestTimestamp_ Oldest timestamp from processed inclusions
    /// @return head_ Updated head position
    /// @return lastProcessedAt_ Updated last processed timestamp
    function _consumeAndUpdateStorage(
        Storage storage $,
        address _feeRecipient,
        IInbox.DerivationSource[] memory _sources,
        uint48 _head,
        uint48 _lastProcessedAt,
        uint256 _toProcess
    )
        private
        returns (uint48 oldestTimestamp_, uint48 head_, uint48 lastProcessedAt_)
    {
        if (_toProcess > 0) {
            // Process inclusions and accumulate fees
            uint256 totalFees = _processInclusions($, _sources, _head, _toProcess);

            // Transfer accumulated fees
            if (totalFees > 0) {
                _feeRecipient.sendEtherAndVerify(totalFees * 1 gwei);
            }

            // Oldest timestamp is max of first inclusion timestamp and last processed time
            oldestTimestamp_ = uint48(_sources[0].blobSlice.timestamp.max(_lastProcessedAt));

            // Update queue position and last processed time
            head_ = _head + uint48(_toProcess);
            lastProcessedAt_ = uint48(block.timestamp);

            // Write to storage once (separate assignments to avoid stack too deep)
            ($.head, $.lastProcessedAt) = (head_, lastProcessedAt_);
        } else {
            // No inclusions processed
            oldestTimestamp_ = type(uint48).max;
            head_ = _head;
            lastProcessedAt_ = _lastProcessedAt;
        }
    }

    /// @dev Validates forced inclusion requirements
    /// @param $ Storage reference
    /// @param _numForcedInclusionsRequested Number requested
    /// @param _minForcedInclusionCount Minimum required count
    /// @param _remainingForcedInclusionCount Number remaining in queue
    /// @param _head Current queue head position
    /// @param _lastProcessedAt Timestamp of last processing
    /// @param _forcedInclusionDelay Delay in seconds before inclusion is due
    function _validateForcedInclusionRequirements(
        Storage storage $,
        uint256 _numForcedInclusionsRequested,
        uint256 _minForcedInclusionCount,
        uint256 _remainingForcedInclusionCount,
        uint48 _head,
        uint48 _lastProcessedAt,
        uint16 _forcedInclusionDelay
    )
        private
        view
    {
        // Validate forced inclusion requirements: must satisfy one of:
        // 1. Requested minimum required count - return early
        if (_numForcedInclusionsRequested >= _minForcedInclusionCount) return;

        // 2. Emptied the queue (remaining is 0 AND requested > 0) - return early
        if (_remainingForcedInclusionCount == 0 && _numForcedInclusionsRequested > 0) return;

        // 3. No remaining inclusions are due - only check if we reach here
        if (_remainingForcedInclusionCount == 0) return;

        require(
            !_isOldestInclusionDue($, _head, _lastProcessedAt, _forcedInclusionDelay),
            UnprocessedForcedInclusionIsDue()
        );
    }

    /// @dev Checks if the oldest remaining forced inclusion is due
    /// @param $ Storage reference
    /// @param head Current queue head position
    /// @param lastProcessedAt Timestamp of last processing
    /// @param forcedInclusionDelay Delay in seconds before inclusion is due
    /// @return True if the oldest remaining inclusion is due for processing
    function _isOldestInclusionDue(
        Storage storage $,
        uint48 head,
        uint48 lastProcessedAt,
        uint16 forcedInclusionDelay
    )
        private
        view
        returns (bool)
    {
        unchecked {
            uint256 timestamp = $.queue[head].blobSlice.timestamp;
            if (timestamp == 0) return false;
            return block.timestamp >= timestamp.max(lastProcessedAt) + forcedInclusionDelay;
        }
    }
    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error IncorrectFee();
}
