// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../IInbox.sol";

/// @title LibState
/// @notice Library for read/write state data.
/// @custom:security-contact security@taiko.xyz
library LibState {
    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Loads the summary hash from storage
    /// @param $ The state storage
    /// @return The summary hash
    function loadSummaryHash(IInbox.State storage $) internal view returns (bytes32) {
        return $.summaryHash;
    }

    /// @notice Saves the summary hash to storage
    /// @param $ The state storage
    /// @param _summaryHash The summary hash to save
    function saveSummaryHash(IInbox.State storage $, bytes32 _summaryHash) internal {
        $.summaryHash = _summaryHash;
    }

    /// @notice Loads a transition metadata hash from storage
    /// @param $ The state storage
    /// @param _conf The configuration
    /// @param _lastVerifiedBlockHash The last verified block hash
    /// @param _batchId The batch ID
    /// @return metaHash_ The transition metadata hash
    /// @return isFirstTransition_ Whether this is the first transition
    function loadTransitionMetaHash(
        IInbox.State storage $,
        IInbox.Config memory _conf,
        bytes32 _lastVerifiedBlockHash,
        uint256 _batchId
    )
        internal
        view
        returns (bytes32 metaHash_, bool isFirstTransition_)
    {
        uint256 slot = _batchId % _conf.batchRingBufferSize;
        (bytes32 partialParentHash, uint48 batchId) = _loadPartialParentHashAndBatchId($, slot);

        if (batchId != _batchId) return (0, false);

        if (partialParentHash == _lastVerifiedBlockHash >> 48) {
            return ($.transitions[slot][1].metaHash, true);
        } else {
            return ($.transitionMetaHashes[_batchId][_lastVerifiedBlockHash], false);
        }
    }

    /// @notice Saves a transition to storage
    /// @param $ The state storage
    /// @param _conf The configuration
    /// @param _batchId The batch ID
    /// @param _parentHash The parent hash
    /// @param _tranMetahash The transition metadata hash
    /// @return isFirstTransition_ Whether this is the first transition
    function saveTransition(
        IInbox.State storage $,
        IInbox.Config memory _conf,
        uint48 _batchId,
        bytes32 _parentHash,
        bytes32 _tranMetahash
    )
        internal
        returns (bool isFirstTransition_)
    {
        uint256 slot = _batchId % _conf.batchRingBufferSize;

        // In the next code section, we always use `state.transitions[slot][1]` to reuse a
        // previously declared variable -- note that the second mapping key is always 1.
        // Tip: the reuse of the first transition slot can save 3900 gas per batch.
        (bytes32 partialParentHash, uint48 batchId) = _loadPartialParentHashAndBatchId($, slot);

        isFirstTransition_ = batchId != _batchId;

        if (isFirstTransition_) {
            // This is the very first transition of the batch.
            // We can reuse the transition slot to reduce gas cost.
            $.transitions[slot][1].batchIdAndPartialParentHash =
                (uint256(_parentHash) & ~type(uint48).max) | _batchId;
            $.transitions[slot][1].metaHash = _tranMetahash;
        } else if (partialParentHash == _parentHash >> 48) {
            // Same parent hash as stored, overwrite the existing transition
            $.transitions[slot][1].metaHash = _tranMetahash;
        } else {
            // Different parent hash, use separate mapping storage
            $.transitionMetaHashes[_batchId][_parentHash] = _tranMetahash;
        }
    }

    /// @notice Loads a batch metadata hash from storage
    /// @param $ The state storage
    /// @param _conf The configuration
    /// @param _batchId The batch ID
    /// @return The batch metadata hash
    function loadBatchMetaHash(
        IInbox.State storage $,
        IInbox.Config memory _conf,
        uint256 _batchId
    )
        internal
        view
        returns (bytes32)
    {
        return $.batches[_batchId % _conf.batchRingBufferSize];
    }

    /// @notice Saves a batch metadata hash to storage
    /// @param $ The state storage
    /// @param _conf The configuration
    /// @param _batchId The batch ID
    /// @param _metaHash The metadata hash to save
    function saveBatchMetaHash(
        IInbox.State storage $,
        IInbox.Config memory _conf,
        uint256 _batchId,
        bytes32 _metaHash
    )
        internal
    {
        $.batches[_batchId % _conf.batchRingBufferSize] = _metaHash;
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Loads batch ID and partial parent hash from storage
    /// @param $ The state storage
    /// @param _slot The storage slot
    /// @return partialParentHash_ The partial parent hash
    /// @return batchId_ The embedded batch ID
    function _loadPartialParentHashAndBatchId(
        IInbox.State storage $,
        uint256 _slot
    )
        private
        view
        returns (bytes32 partialParentHash_, uint48 batchId_)
    {
        uint256 value = $.transitions[_slot][1].batchIdAndPartialParentHash;
        partialParentHash_ = bytes32(value >> 48);
        batchId_ = uint48(value);
    }
}
