// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/forced-inclusion/IForcedInclusionStore.sol";
import "../IInbox.sol";
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

    /// @notice Proposes multiple batches in a single transaction
    /// @param _bindings Library function binding
    /// @param _config The protocol configuration
    /// @param _summary The current protocol summary
    /// @param _batches Array of batches to propose
    /// @param _evidence Evidence containing parent batch metadata
    /// @return The updated protocol summary
    function propose(
        LibBinding.Bindings memory _bindings,
        IInbox.Config memory _config,
        IInbox.Summary memory _summary,
        IInbox.Batch[] memory _batches,
        IInbox.ProposeBatchEvidence memory _evidence
    )
        internal
        returns (IInbox.Summary memory, IInbox.BatchContext[] memory)
    {
        unchecked {
            // Validate preconfer authorization first
            LibValidate.validateProposer(_config, _bindings);

            if (_batches.length == 0) revert EmptyBatchArray();
            if (_batches.length >= 8) revert BatchLimitExceeded();

            // Make sure the last verified batch is not overwritten by a new batch.
            // Assuming batchRingBufferSize = 100, right after genesis, we can propose up to 99
            // batches, the following requirement-statement will pass as:
            //  1 (nextBatchId) + 99 (_batches.length) <=
            //  0 (lastVerifiedBatchId) + 100 (batchRingBufferSize)
            if (
                _summary.nextBatchId + _batches.length
                    > _summary.lastVerifiedBatchId + _config.batchRingBufferSize
            ) {
                revert BatchLimitExceeded();
            }

            if (_summary.lastBatchMetaHash != LibData.hashBatch(_evidence)) {
                revert MetadataHashMismatch();
            }

            IInbox.BatchProposeMetadata memory parentBatch = _evidence.proposeMeta;
            IInbox.BatchContext[] memory contexts = new IInbox.BatchContext[](_batches.length);

            for (uint256 i; i < _batches.length; ++i) {
                (parentBatch, contexts[i], _summary.lastBatchMetaHash) =
                    _proposeBatch(_bindings, _config, _summary, _batches[i], parentBatch);

                ++_summary.nextBatchId;

                if (_summary.gasIssuancePerSecond != _batches[i].gasIssuancePerSecond) {
                    _summary.gasIssuancePerSecond = _batches[i].gasIssuancePerSecond;
                    _summary.gasIssuanceUpdatedAt = uint48(block.timestamp);
                }
            }

            // Validate forced inclusion was processed if due
            if (_bindings.isForcedInclusionDue(_summary.nextBatchId)) {
                IForcedInclusionStore.ForcedInclusion memory processed =
                    _bindings.consumeForcedInclusion(msg.sender);

                LibValidate.validateForcedInclusionBatch(_batches[0], processed);
            }

            return (_summary, contexts);
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes a single batch
    /// @param _bindings Library function binding
    /// @param _config The protocol configuration
    /// @param _summary The current protocol summary
    /// @param _batch The batch to propose
    /// @param _parentBatch The parent batch metadata
    /// @return _ The propose metadata of the proposed batch
    /// @return _ The hash of the proposed batch metadata
    function _proposeBatch(
        LibBinding.Bindings memory _bindings,
        IInbox.Config memory _config,
        IInbox.Summary memory _summary,
        IInbox.Batch memory _batch,
        IInbox.BatchProposeMetadata memory _parentBatch
    )
        private
        returns (IInbox.BatchProposeMetadata memory, IInbox.BatchContext memory, bytes32)
    {
        // Validate the batch parameters and return batch and batch context data
        IInbox.BatchContext memory context =
            LibValidate.validate(_bindings, _config, _summary, _batch, _parentBatch);

        context.prover = LibProver.validateProver(_bindings, _config, _summary, _batch);

        IInbox.BatchMetadata memory metadata = LibData.buildBatchMetadata(
            msg.sender, uint48(block.number), uint48(block.timestamp), _batch, context
        );

        bytes32 batchMetaHash = LibData.hashBatch(_summary.nextBatchId, metadata);
        _bindings.saveBatchMetaHash(_config, _summary.nextBatchId, batchMetaHash);

        return (metadata.proposeMeta, context, batchMetaHash);
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
