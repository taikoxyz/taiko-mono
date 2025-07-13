// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";
import "./LibValidate.sol";
import "./LibData.sol";
import "./LibProver.sol";
import "./LibCodec.sol";

/// @title LibPropose
/// @notice Library for processing batch proposals and metadata generation in Taiko protocol
/// @dev Handles the complete batch proposal workflow including:
///      - Multi-batch proposal validation and processing
///      - Batch metadata population with build, propose, and prove sections
///      - Parent metadata hash verification against evidence
///      - Prover validation and authentication
///      - Batch limit enforcement and sequential processing
/// @custom:security-contact security@taiko.xyz
library LibPropose {
    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes multiple batches in a single transaction
    /// @param _conf The protocol configuration
    /// @param _rw Read/write function pointers for storage access
    /// @param _summary The current protocol summary
    /// @param _batches Array of batches to propose
    /// @param _evidence Evidence containing parent batch metadata
    /// @return The updated protocol summary
    function propose(
        I.Config memory _conf,
        LibState.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.Batch[] memory _batches,
        I.BatchProposeMetadataEvidence memory _evidence
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            require(_batches.length != 0, NoBatchesToPropose());
            require(
                _summary.nextBatchId + _batches.length
                    <= _summary.lastVerifiedBatchId + _conf.maxUnverifiedBatches + 1,
                TooManyBatches()
            );

            require(_summary.lastBatchMetaHash == LibData.hashBatch(_evidence), MetaHashNotMatch());

            I.BatchProposeMetadata memory parent = _evidence.proposeMeta;

            I.BatchMetadata memory meta;
            for (uint256 i; i < _batches.length; ++i) {
                (meta, _summary.lastBatchMetaHash) =
                    _proposeBatch(_conf, _rw, _summary, _batches[i], parent);

                if (_summary.gasIssuancePerSecond != _batches[i].gasIssuancePerSecond) {
                    _summary.gasIssuancePerSecond = _batches[i].gasIssuancePerSecond;
                    _summary.gasIssuanceUpdatedAt = uint48(block.timestamp);
                }

                _summary.nextBatchId += 1;

                parent = meta.proposeMeta;
            }

            return _summary;
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a single batch
    /// @param _conf The protocol configuration
    /// @param _rw Read/write function pointers for storage access
    /// @param _summary The current protocol summary
    /// @param _batch The batch to propose
    /// @param _parent The parent batch metadata
    /// @return meta_ The metadata of the proposed batch
    /// @return batchMetaHash_ The hash of the proposed batch metadata
    function _proposeBatch(
        I.Config memory _conf,
        LibState.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parent
    )
        private
        returns (I.BatchMetadata memory meta_, bytes32 batchMetaHash_)
    {
        // Validate the batch parameters and return batch and batch context data
        I.BatchContext memory context = LibValidate.validate(_conf, _rw, _summary, _batch, _parent);

        context.prover = LibProver.validateProver(_conf, _rw, _summary, _batch.proverAuth, _batch);

        meta_ = LibData.buildBatchMetadata(
            uint48(block.number), uint48(block.timestamp), _batch, context
        );

        batchMetaHash_ = LibData.hashBatch(_summary.nextBatchId, meta_);
        _rw.saveBatchMetaHash(_conf, _summary.nextBatchId, batchMetaHash_);

        emit I.Proposed(_summary.nextBatchId, LibCodec.packBatchContext(context));
    }

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when an anchor ID is smaller than its parent
    error AnchorIdSmallerThanParent();
    /// @notice Thrown when an anchor ID is too small (outside allowed range)
    error AnchorIdTooSmall();
    /// @notice Thrown when an anchor ID is zero but should be non-zero
    error AnchorIdZero();
    /// @notice Thrown when a required blob is not found
    error BlobNotFound();
    /// @notice Thrown when blocks are not in the current fork
    error BlocksNotInCurrentFork();
    /// @notice Thrown when the first block has a non-zero time shift
    error FirstBlockTimeShiftNotZero();
    /// @notice Thrown when the metadata hash does not match
    error MetaHashNotMatch();
    /// @notice Thrown when no anchor block ID is found within the batch
    error NoAnchorBlockIdWithinThisBatch();
    /// @notice Thrown when no batches are provided for proposal
    error NoBatchesToPropose();
    /// @notice Thrown when a signal has not been sent
    error SignalNotSent();
    /// @notice Thrown when a timestamp is smaller than its parent
    error TimestampSmallerThanParent();
    /// @notice Thrown when a timestamp is too large
    error TimestampTooLarge();
    /// @notice Thrown when a timestamp is too small
    error TimestampTooSmall();
    /// @notice Thrown when too many batches are provided
    error TooManyBatches();
    /// @notice Thrown when an anchor block hash is zero
    error ZeroAnchorBlockHash();
}
