// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibValidate.sol";
import "./LibData.sol";
import "./LibProvers.sol";

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
        I.Batch[] calldata _batches,
        I.BatchProposeMetadataEvidence memory _evidence
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            require(_batches.length != 0, NoBatchesToPropose());
            require(
                _summary.numBatches + _batches.length
                    <= _summary.lastVerifiedBatchId + _conf.maxUnverifiedBatches + 1,
                TooManyBatches()
            );

            require(
                _rw.loadBatchMetaHash(_conf, _summary.numBatches - 1)
                    == LibData.hashBatch(_evidence),
                MetaHashNotMatch()
            );

            I.BatchProposeMetadata memory parent = _evidence.proposeMeta;

            for (uint256 i; i < _batches.length; ++i) {
                I.BatchMetadata memory meta =
                    _proposeBatch(_conf, _rw, _summary, _batches[i], parent);

                parent = meta.proposeMeta;
                _summary.numBatches += 1;
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
    function _proposeBatch(
        I.Config memory _conf,
        LibState.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.Batch calldata _batch,
        I.BatchProposeMetadata memory _parent
    )
        private
        returns (I.BatchMetadata memory meta_)
    {
        // Validate the batch parameters and return validation output
        I.BatchContext memory context = LibValidate.validate(_conf, _rw, _batch, _parent);

        context.prover = LibProvers.validateProver(_conf, _rw, _summary, _batch.proverAuth, _batch);

        meta_ = _populateBatchMetadata(_conf, _batch, context);

        bytes32 batchMetaHash = LibData.hashBatch(_summary.numBatches, meta_);
        _rw.saveBatchMetaHash(_conf, _summary.numBatches, batchMetaHash);

        emit I.Proposed(_summary.numBatches, meta_);
    }

    /// @notice Populates batch metadata from validation output
    /// @param _conf The protocol configuration
    /// @param _batch The batch being proposed
    /// @param _context The validation output containing computed values
    /// @return meta_ The populated batch metadata
    function _populateBatchMetadata(
        I.Config memory _conf,
        I.Batch calldata _batch,
        I.BatchContext memory _context
    )
        private
        view
        returns (I.BatchMetadata memory meta_)
    {
        // Build metadata section
        meta_.buildMeta = I.BatchBuildMetadata({
            txsHash: _context.txsHash,
            blobHashes: _context.blobHashes,
            extraData: LibData.encodeExtraDataLower128Bits(_conf, _batch),
            coinbase: _context.coinbase,
            proposedIn: uint48(block.number),
            blobCreatedIn: _batch.blobs.createdIn,
            blobByteOffset: _batch.blobs.byteOffset,
            blobByteSize: _batch.blobs.byteSize,
            gasLimit: _conf.blockMaxGasLimit,
            lastBlockId: _context.lastBlockId,
            lastBlockTimestamp: _batch.lastBlockTimestamp,
            anchorBlockIds: _batch.anchorBlockIds,
            anchorBlockHashes: _context.anchorBlockHashes,
            encodedBlocks: _batch.encodedBlocks,
            baseFeeConfig: _conf.baseFeeConfig
        });

        // Propose metadata section
        meta_.proposeMeta = I.BatchProposeMetadata({
            lastBlockTimestamp: _batch.lastBlockTimestamp,
            lastBlockId: meta_.buildMeta.lastBlockId,
            lastAnchorBlockId: _context.lastAnchorBlockId
        });

        // Prove metadata section
        meta_.proveMeta = I.BatchProveMetadata({
            proposer: _context.proposer,
            prover: _context.prover,
            proposedAt: uint48(block.timestamp),
            firstBlockId: _context.firstBlockId,
            lastBlockId: meta_.buildMeta.lastBlockId,
            livenessBond: _conf.livenessBond,
            provabilityBond: _conf.provabilityBond
        });
    }

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------
    error AnchorIdSmallerThanParent();
    error AnchorIdTooSmall();
    error AnchorIdZero();
    error BlobNotFound();
    error BlocksNotInCurrentFork();
    error FirstBlockTimeShiftNotZero();
    error MetaHashNotMatch();
    error NoAnchorBlockIdWithinThisBatch();
    error NoBatchesToPropose();
    error SignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error TooManyBatches();
    error ZeroAnchorBlockHash();
}
