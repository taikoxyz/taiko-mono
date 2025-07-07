// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibState
/// @notice Library for read/write state data.
/// @custom:security-contact security@taiko.xyz
library LibState {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Structure containing function pointers for read and write operations
    /// @dev This pattern allows libraries to interact with external contracts
    ///      without direct dependencies
    struct ReadWrite {
        // ---------------------------------------------------------------------
        // Read functions
        // ---------------------------------------------------------------------

        /// @notice Loads a batch metadata hash
        function(I.Config memory, uint256) view returns (bytes32) loadBatchMetaHash;
        /// @notice Checks if a signal has been sent
        function(I.Config memory, bytes32) view returns (bool) isSignalSent;
        /// @notice Gets the blob hash for a given index
        function(uint256) view returns (bytes32) getBlobHash;
        function (I.Config memory, bytes32, uint256) view returns (bytes32 , bool)
            loadTransitionMetaHash;
        // ---------------------------------------------------------------------
        // Write functions
        // ---------------------------------------------------------------------

        /// @notice Saves a transition
        function(I.Config memory, uint48, bytes32, bytes32) returns (bool) saveTransition;
        /// @notice Transfers fees between addresses
        function(address, address, address, uint256) transferFee;
        /// @notice Credits bond to a user
        function(address, uint256) creditBond;
        /// @notice Debits bond from a user
        function(I.Config memory, address, uint256) debitBond;
        /// @notice Syncs chain data
        function(I.Config memory, uint64, bytes32) syncChainData;
        /// @notice Saves a batch metadata hash
        function(I.Config memory, uint256, bytes32) saveBatchMetaHash;
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Loads the summary hash from storage
    /// @param $ The state storage
    /// @return The summary hash
    function loadSummaryHash(I.State storage $) internal view returns (bytes32) {
        return $.summaryHash;
    }

    /// @notice Saves the summary hash to storage
    /// @param $ The state storage
    /// @param _summaryHash The summary hash to save
    function saveSummaryHash(I.State storage $, bytes32 _summaryHash) internal {
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
        I.State storage $,
        I.Config memory _conf,
        bytes32 _lastVerifiedBlockHash,
        uint256 _batchId
    )
        internal
        view
        returns (bytes32 metaHash_, bool isFirstTransition_)
    {
        uint256 slot = _batchId % _conf.batchRingBufferSize;
        (uint48 embeddedBatchId, bytes32 partialParentHash) =
            _loadBatchIdAndPartialParentHash($, slot);

        if (embeddedBatchId != _batchId) return (0, false);

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
        I.State storage $,
        I.Config memory _conf,
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
        (uint48 embeddedBatchId, bytes32 partialParentHash) =
            _loadBatchIdAndPartialParentHash($, slot);

        isFirstTransition_ = embeddedBatchId != _batchId;

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
        I.State storage $,
        I.Config memory _conf,
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
        I.State storage $,
        I.Config memory _conf,
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
    /// @return embeddedBatchId_ The embedded batch ID
    /// @return partialParentHash_ The partial parent hash
    function _loadBatchIdAndPartialParentHash(
        I.State storage $,
        uint256 _slot
    )
        private
        view
        returns (uint48 embeddedBatchId_, bytes32 partialParentHash_)
    {
        uint256 value = $.transitions[_slot][1].batchIdAndPartialParentHash;
        embeddedBatchId_ = uint48(value);
        partialParentHash_ = bytes32(value >> 48);
    }
}
