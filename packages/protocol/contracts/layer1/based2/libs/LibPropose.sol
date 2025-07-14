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
    /// @param _access Read/write function pointers for storage access
    /// @param _config The protocol configuration
    /// @param _summary The current protocol summary
    /// @param _batches Array of batches to propose
    /// @param _evidence Evidence containing parent batch metadata
    /// @return The updated protocol summary
    function propose(
        LibState.Access memory _access,
        I.Config memory _config,
        I.Summary memory _summary,
        I.Batch[] memory _batches,
        I.BatchProposeMetadataEvidence memory _evidence
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            require(_batches.length != 0, EmptyBatchArray());

            // Make sure the lask verified batch is not overwritten by a new batch.
            // Assuming batchRingBufferSize = 100, right after genesis, we can propose up to 99
            // batches, the following requirement-statement will pass as:
            //  1 (nextBatchId) + 99 (_batches.length) <=
            //  0 (lastVerifiedBatchId) + 100 (batchRingBufferSize)
            require(
                _summary.nextBatchId + _batches.length
                    <= _summary.lastVerifiedBatchId + _config.batchRingBufferSize,
                BatchLimitExceeded()
            );

            require(
                _summary.lastBatchMetaHash == LibData.hashBatch(_evidence), MetadataHashMismatch()
            );

            I.BatchProposeMetadata memory parentBatch = _evidence.proposeMeta;

            for (uint256 i; i < _batches.length; ++i) {
                (parentBatch, _summary.lastBatchMetaHash) =
                    _proposeBatch(_access, _config, _summary, _batches[i], parentBatch);
                    
                ++_summary.nextBatchId;

                if (_summary.gasIssuancePerSecond != _batches[i].gasIssuancePerSecond) {
                    _summary.gasIssuancePerSecond = _batches[i].gasIssuancePerSecond;
                    _summary.gasIssuanceUpdatedAt = uint48(block.timestamp);
                }
            }

            return _summary;
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a single batch
    /// @param _access Read/write function pointers for storage access
    /// @param _config The protocol configuration
    /// @param _summary The current protocol summary
    /// @param _batch The batch to propose
    /// @param _parentBatch The parent batch metadata
    /// @return _ The propose metadata of the proposed batch
    /// @return _ The hash of the proposed batch metadata
    function _proposeBatch(
        LibState.Access memory _access,
        I.Config memory _config,
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parentBatch
    )
        private
        returns (I.BatchProposeMetadata memory, bytes32)
    {
        // Validate the batch parameters and return batch and batch context data
        I.BatchContext memory context =
            LibValidate.validate(_access, _config, _summary, _batch, _parentBatch);

        context.prover =
            LibProver.validateProver(_access, _config, _summary, _batch.proverAuth, _batch);

        I.BatchMetadata memory metadata = LibData.buildBatchMetadata(
            uint48(block.number), uint48(block.timestamp), _batch, context
        );

        emit I.Proposed(_summary.nextBatchId, LibCodec.packBatchContext(context));

        bytes32 batchMetaHash = LibData.hashBatch(_summary.nextBatchId, metadata);
        _access.saveBatchMetaHash(_config, _summary.nextBatchId, batchMetaHash);

        return (metadata.proposeMeta, batchMetaHash);
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
