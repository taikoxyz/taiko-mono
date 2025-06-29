// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibBatchValidation.sol";
import "./LibForks.sol";
import "./LibDataUtils.sol";
import "./LibProverValidation.sol";

/// @title LibBatchProposal
/// @custom:security-contact security@taiko.xyz
library LibBatchProposal {
    function proposeBatches(
        I.Config memory _conf,
        LibBatchValidation.ReadWrite memory _rw,
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
                _rw.getBatchMetaHash(_conf, _summary.numBatches - 1)
                    == LibDataUtils.hashBatch(_evidence),
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

    function _proposeBatch(
        I.Config memory _conf,
        LibBatchValidation.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parent
    )
        private
        returns (I.BatchMetadata memory meta_)
    {
        // Validate the params and returns an updated copy
        LibBatchValidation.ValidationOutput memory output =
            LibBatchValidation.validateBatch(_conf, _rw, _batch, _parent);

        output.prover =
            LibProverValidation.validateProver(_conf, _rw, _summary, _batch.proverAuth, _batch);

        meta_ = _populateBatchMetadata(_conf, _batch, output);

        bytes32 batchMetaHash = LibDataUtils.hashBatch(_summary.numBatches, meta_);
        _rw.saveBatchMetaHash(_conf, _summary.numBatches, batchMetaHash);

        emit I.BatchProposed(_summary.numBatches, LibDataUtils.packBatchMetadata(meta_));
    }

    function _populateBatchMetadata(
        I.Config memory _conf,
        I.Batch memory _batch,
        LibBatchValidation.ValidationOutput memory _output
    )
        private
        view
        returns (I.BatchMetadata memory meta_)
    {
        meta_.buildMeta = I.BatchBuildMetadata({
            txsHash: _output.txsHash,
            blobHashes: _output.blobHashes,
            extraData: LibDataUtils.encodeExtraDataLower128Bits(_conf, _batch),
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

        meta_.proposeMeta = I.BatchProposeMetadata({
            lastBlockTimestamp: _batch.lastBlockTimestamp,
            lastBlockId: meta_.buildMeta.lastBlockId,
            lastAnchorBlockId: _output.lastAnchorBlockId
        });

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

    // --- ERRORs --------------------------------------------------------------------------------

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
