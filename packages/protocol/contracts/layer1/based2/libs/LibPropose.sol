// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibValidate.sol";
import "./LibForks.sol";
import "./LibData.sol";
import "./LibProvers.sol";

/// @title LibPropose
/// @notice Library for handling batch proposals in the Taiko protocol
/// @dev This library manages the creation and validation of batch proposals
/// @custom:security-contact security@taiko.xyz
library LibPropose {
    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Proposes multiple batches in a single transaction
    /// @param _conf The protocol configuration
    /// @param _rw Read/write function pointers for storage access
    /// @param _summary The current protocol summary
    /// @param _batch Array of batches to propose
    /// @param _evidence Evidence containing parent batch metadata
    /// @return The updated protocol summary
    function propose(
        I.Config memory _conf,
        LibData.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.Batch[] memory _batch,
        I.BatchProposeMetadataEvidence memory _evidence
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            require(_batch.length != 0, NoBatchesToPropose());
            require(
                _summary.numBatches + _batch.length
                    <= _summary.lastVerifiedBatchId + _conf.maxUnverifiedBatches + 1,
                TooManyBatches()
            );

            require(
                _rw.loadBatchMetaHash(_conf, _summary.numBatches - 1)
                    == LibData.hashBatch(_evidence),
                MetaHashNotMatch()
            );

            I.BatchProposeMetadata memory parent = _evidence.proposeMeta;

            for (uint256 i; i < _batch.length; ++i) {
                I.BatchMetadata memory meta = _proposeBatch(_conf, _rw, _summary, _batch[i], parent);

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
        LibData.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parent
    )
        private
        returns (I.BatchMetadata memory meta_)
    {
        // Validate the batch parameters and return validation output
        LibValidate.ValidationOutput memory output =
            LibValidate.validate(_conf, _rw, _batch, _parent);

        output.prover = LibProvers.validateProver(_conf, _rw, _summary, _batch.proverAuth, _batch);

        meta_ = _populateBatchMetadata(_conf, _batch, output);

        bytes32 batchMetaHash = LibData.hashBatch(_summary.numBatches, meta_);
        _rw.saveBatchMetaHash(_conf, _summary.numBatches, batchMetaHash);

        emit I.Proposed(_summary.numBatches, LibData.packBatchMetadata(meta_));
    }

    /// @notice Populates batch metadata from validation output
    /// @param _conf The protocol configuration
    /// @param _batch The batch being proposed
    /// @param _output The validation output containing computed values
    /// @return meta_ The populated batch metadata
    function _populateBatchMetadata(
        I.Config memory _conf,
        I.Batch memory _batch,
        LibValidate.ValidationOutput memory _output
    )
        private
        view
        returns (I.BatchMetadata memory meta_)
    {
        // Build metadata section
        meta_.buildMeta = I.BatchBuildMetadata({
            txsHash: _output.txsHash,
            blobHashes: _output.blobHashes,
            extraData: LibData.encodeExtraDataLower128Bits(_conf, _batch),
            coinbase: _output.coinbase,
            proposedIn: uint48(block.number),
            blobCreatedIn: _batch.blobs.createdIn,
            blobByteOffset: _batch.blobs.byteOffset,
            blobByteSize: _batch.blobs.byteSize,
            gasLimit: _conf.blockMaxGasLimit,
            lastBlockId: _output.lastBlockId,
            lastBlockTimestamp: _batch.lastBlockTimestamp,
            anchorBlockIds: _batch.anchorBlockIds,
            anchorBlockHashes: _output.anchorBlockHashes,
            encodedBlocks: _batch.encodedBlocks,
            baseFeeConfig: _conf.baseFeeConfig
        });

        // Propose metadata section
        meta_.proposeMeta = I.BatchProposeMetadata({
            lastBlockTimestamp: _batch.lastBlockTimestamp,
            lastBlockId: meta_.buildMeta.lastBlockId,
            lastAnchorBlockId: _output.lastAnchorBlockId
        });

        // Prove metadata section
        meta_.proveMeta = I.BatchProveMetadata({
            proposer: _output.proposer,
            prover: _output.prover,
            proposedAt: uint48(block.timestamp),
            firstBlockId: _output.firstBlockId,
            lastBlockId: meta_.buildMeta.lastBlockId,
            livenessBond: _conf.livenessBond,
            provabilityBond: _conf.provabilityBond
        });
    }

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    // Batch validation errors
    /// @notice Thrown when no batches are provided for proposal
    error NoBatchesToPropose();
    /// @notice Thrown when too many unverified batches would exist
    error TooManyBatches();
    /// @notice Thrown when parent batch metadata hash doesn't match
    error MetaHashNotMatch();

    // Anchor block errors
    /// @notice Thrown when anchor ID is smaller than parent's anchor ID
    error AnchorIdSmallerThanParent();
    /// @notice Thrown when anchor ID is too small relative to last verified
    error AnchorIdTooSmall();
    /// @notice Thrown when anchor ID is zero
    error AnchorIdZero();
    /// @notice Thrown when no anchor block ID is within the batch
    error NoAnchorBlockIdWithinThisBatch();
    /// @notice Thrown when anchor block hash is zero
    error ZeroAnchorBlockHash();

    // Timestamp errors
    /// @notice Thrown when timestamp is smaller than parent's timestamp
    error TimestampSmallerThanParent();
    /// @notice Thrown when timestamp is too far in the future
    error TimestampTooLarge();
    /// @notice Thrown when timestamp is too old
    error TimestampTooSmall();
    /// @notice Thrown when first block's time shift is not zero
    error FirstBlockTimeShiftNotZero();

    // Other errors
    /// @notice Thrown when blob is not found at expected block
    error BlobNotFound();
    /// @notice Thrown when blocks are not in the current fork
    error BlocksNotInCurrentFork();
    /// @notice Thrown when required signal was not sent
    error SignalNotSent();
}
