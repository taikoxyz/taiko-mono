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
            require(
                _summary.nextBatchId + _batches.length
                    <= _summary.lastVerifiedBatchId + _config.maxUnverifiedBatches + 1,
                BatchLimitExceeded()
            );

            require(
                _summary.lastBatchMetaHash == LibData.hashBatch(_evidence), MetadataHashMismatch()
            );

            I.BatchProposeMetadata memory parent = _evidence.proposeMeta;

            I.BatchMetadata memory metadata;
            for (uint256 i; i < _batches.length; ++i) {
                (metadata, _summary.lastBatchMetaHash) =
                    _proposeBatch(_access, _config, _summary, _batches[i], parent);

                if (_summary.gasIssuancePerSecond != _batches[i].gasIssuancePerSecond) {
                    _summary.gasIssuancePerSecond = _batches[i].gasIssuancePerSecond;
                    _summary.gasIssuanceUpdatedAt = uint48(block.timestamp);
                }

                _summary.nextBatchId += 1;

                parent = metadata.proposeMeta;
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
    /// @param _parent The parent batch metadata
    /// @return metadata_ The metadata of the proposed batch
    /// @return batchMetaHash_ The hash of the proposed batch metadata
    function _proposeBatch(
        LibState.Access memory _access,
        I.Config memory _config,
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parent
    )
        private
        returns (I.BatchMetadata memory metadata_, bytes32 batchMetaHash_)
    {
        // Validate the batch parameters and return batch and batch context data
        I.BatchContext memory context =
            LibValidate.validate(_access, _config, _summary, _batch, _parent);

        context.prover =
            LibProver.validateProver(_access, _config, _summary, _batch.proverAuth, _batch);

        metadata_ = LibData.buildBatchMetadata(
            uint48(block.number), uint48(block.timestamp), _batch, context
        );

        batchMetaHash_ = LibData.hashBatch(_summary.nextBatchId, metadata_);
        _access.saveBatchMetaHash(_config, _summary.nextBatchId, batchMetaHash_);

        emit I.Proposed(_summary.nextBatchId, LibCodec.packBatchContext(context));
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
