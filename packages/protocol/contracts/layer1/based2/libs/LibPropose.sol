// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";
import "./LibValidate.sol";
import "./LibData.sol";
import "./LibProver.sol";

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

    /// @notice Proposes a batch in a single transaction
    /// @param _inputs The inputs to the propose function
    /// @param _bindings Library function binding
    /// @param _config The protocol configuration
    /// @param _summary The current protocol summary
    /// @param _batch The batch to propose
    /// @param _evidence Evidence containing parent batch metadata
    /// @return The updated protocol summary
    function propose(
        bytes memory _inputs,
        LibBinding.Bindings memory _bindings,
        I.Config memory _config,
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.ProposeBatchEvidence memory _evidence
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            // Make sure the lask verified batch is not overwritten by a new batch.
            // Assuming batchRingBufferSize = 100, right after genesis, we can propose up to 99
            // batches, the following requirement-statement will pass as:
            //  1 (nextBatchId) + 99 (_batches.length) <=
            //  0 (lastVerifiedBatchId) + 100 (batchRingBufferSize)
            require(
                _summary.nextBatchId + 1
                    <= _summary.lastVerifiedBatchId + _config.batchRingBufferSize,
                BatchLimitExceeded()
            );

            require(
                _summary.lastBatchMetaHash == LibData.hashBatch(_evidence), MetadataHashMismatch()
            );

            I.BatchProposeMetadata memory parentBatch = _evidence.proposeMeta;

            // Validate the batch parameters and return batch and batch context data
            I.BatchContext memory context =
                LibValidate.validate(_bindings, _config, _summary, _batch, parentBatch);

            context.prover = LibProver.validateProver(_bindings, _config, _summary, _batch);

            I.BatchMetadata memory metadata = LibData.buildBatchMetadata(
                uint48(block.number), uint48(block.timestamp), _batch, context
            );

            _summary.lastBatchMetaHash = LibData.hashBatch(_summary.nextBatchId, metadata);
            _bindings.saveBatchMetaHash(_config, _summary.nextBatchId, _summary.lastBatchMetaHash);

            emit I.Proposed(_summary.nextBatchId, _bindings.encodeBatchContext(context), _inputs);

            if (_summary.gasIssuancePerSecond != _batch.gasIssuancePerSecond) {
                _summary.gasIssuancePerSecond = _batch.gasIssuancePerSecond;
                _summary.gasIssuanceUpdatedAt = uint48(block.timestamp);
            }

            ++_summary.nextBatchId;
            return _summary;
        }
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error AnchorIdSmallerThanParent();
    error AnchorIdTooSmall();
    error AnchorIdZero();
    error BatchLimitExceeded();
    error BlobHashNotFound();
    error BlocksNotInCurrentFork();
    error EmptyBatchArray();
    error FirstBlockTimeShiftNotZero();
    error MetadataHashMismatch();
    error NoAnchorBlockIdWithinThisBatch();
    error RequiredSignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error ZeroAnchorBlockHash();
}
