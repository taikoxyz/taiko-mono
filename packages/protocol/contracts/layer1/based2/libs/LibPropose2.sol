// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibSummary.sol";
import "./LibAuth2.sol";
import "./LibFork2.sol";
import "./LibParams.sol";

/// @title LibPropose2
/// @custom:security-contact security@taiko.xyz
library LibPropose2 {
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

    struct ParamsValidationOutput {
        bytes32 txsHash;
        bytes32[] blobHashes;
        uint48 lastAnchorBlockId;
        uint48 firstBlockId;
        uint48 lastBlockId;
        bytes32[] anchorBlockHashes;
        I.Block[] blocks;
        address proposer; // TODO
        address prover;
        address coinbase; // TODO
    }

    function proposeBatches(
        I.Config memory _conf,
        LibParams.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.Batch[] memory _batch,
        I.BatchProposeMetadataEvidence calldata _evidence
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            require(_batch.length != 0, NoBatchesToPropose());
            // Validate parentProposeMeta against its meta hash
            _validateBatchProposeMeta(_evidence, _rw.parentBatchMetaHash);
            I.BatchProposeMetadata memory parentProposeMeta = _evidence.proposeMeta;

            for (uint256 i; i < _batch.length; ++i) {
                parentProposeMeta =
                    _proposeBatch(_conf, _rw, _summary, _batch[i], parentProposeMeta);
                _summary.numBatches += 1;
                _summary.lastProposedIn = _rw.blockNumber;
            }

            return _summary;
        }
    }

    function _proposeBatch(
        I.Config memory _conf,
        LibParams.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parentProposeMeta
    )
        private
        returns (I.BatchProposeMetadata memory)
    {
        require(
            _summary.numBatches <= _summary.lastVerifiedBatchId + _conf.maxUnverifiedBatches,
            TooManyBatches()
        );

        // Validate the params and returns an updated copy
        (I.Batch memory params, LibParams.ValidationOutput memory output) =
            LibParams.validateBatch(_conf, _rw, _batch, _parentProposeMeta);

        output.prover = _validateProver(_conf, _rw, _summary, params.proverAuth, params);

        I.BatchMetadata memory meta = _populateBatchMetadata(_conf, _rw, params, output);

        bytes32 batchMetaHash = hashBatch(_summary.numBatches, meta);
        _rw.saveBatchMetaHash(_conf, _summary.numBatches, batchMetaHash);

        emit I.BatchProposed(_summary.numBatches, _rw.encodeBatchMetadata(meta));

        return meta.proposeMeta;
    }

    function hashBatch(
        uint256 batchId,
        I.BatchMetadata memory meta
    )
        internal
        pure
        returns (bytes32)
    {
        bytes32 buildMetaHash = keccak256(abi.encode(meta.buildMeta));
        bytes32 proposeMetaHash = keccak256(abi.encode(meta.proposeMeta));
        bytes32 proveMetaHash = keccak256(abi.encode(meta.proveMeta));
        bytes32 leftHash = keccak256(abi.encode(batchId, buildMetaHash));
        bytes32 rightHash = keccak256(abi.encode(proposeMetaHash, proveMetaHash));
        return keccak256(abi.encode(leftHash, rightHash));
    }

    function _validateProver(
        I.Config memory _conf,
        LibParams.ReadWrite memory _rw,
        I.Summary memory _summary,
        bytes memory _proverAuth,
        I.Batch memory _batch
    )
        private
        returns (address prover_)
    {
        unchecked {
            if (_batch.proverAuth.length == 0) {
                _rw.debitBond(_conf, _batch.proposer, _conf.livenessBond + _conf.provabilityBond);
                return _batch.proposer;
            }

            // Circular dependency so zero it out. (Batch has proverAuth but
            // proverAuth has also batchHash)
            _batch.proverAuth = "";

            // Outsource the prover authentication to the LibAuth library to
            // reduce this contract's code size.
            address feeToken;
            uint96 fee;
            (prover_, feeToken, fee) = _rw.validateProverAuth(
                _conf.chainId, _summary.numBatches, keccak256(abi.encode(_batch)), _proverAuth
            );

            if (feeToken == _conf.bondToken) {
                // proposer pay the prover fee with bond tokens
                _rw.debitBond(_conf, _batch.proposer, fee + _conf.provabilityBond);

                // if bondDelta is negative (proverFee < livenessBond), deduct the diff
                // if not then add the diff to the bond balance
                int256 bondDelta = int96(fee) - int96(_conf.livenessBond);

                bondDelta < 0
                    ? _rw.debitBond(_conf, prover_, uint256(-bondDelta))
                    : _rw.creditBond(prover_, uint256(bondDelta));
            } else if (_batch.proposer == prover_) {
                _rw.debitBond(_conf, _batch.proposer, _conf.livenessBond + _conf.provabilityBond);
            } else {
                _rw.debitBond(_conf, _batch.proposer, _conf.provabilityBond);
                _rw.debitBond(_conf, prover_, _conf.livenessBond);

                if (fee != 0) {
                    _rw.transferFee(feeToken, _batch.proposer, prover_, fee);
                }
            }
        }
    }

    function _validateBatchProposeMeta(
        I.BatchProposeMetadataEvidence calldata _evidence,
        bytes32 _batchMetaHash
    )
        private
        pure
    {
        bytes32 proposeMetaHash = keccak256(abi.encode(_evidence.proposeMeta));
        bytes32 rightHash = keccak256(abi.encode(proposeMetaHash, _evidence.proveMetaHash));
        bytes32 metaHash = keccak256(abi.encode(_evidence.idAndBuildHash, rightHash));
        require(_batchMetaHash == metaHash, MetaHashNotMatch());
    }

    function _populateBatchMetadata(
        I.Config memory _conf,
        LibParams.ReadWrite memory _rw,
        I.Batch memory _batch,
        LibParams.ValidationOutput memory _output
    )
        private
        pure
        returns (I.BatchMetadata memory meta_)
    {
        meta_.buildMeta = I.BatchBuildMetadata({
            txsHash: _output.txsHash,
            blobHashes: _output.blobHashes,
            extraData: _encodeExtraDataLower128Bits(_conf, _batch),
            coinbase: _batch.coinbase,
            proposedIn: _rw.blockNumber,
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
            proposer: _batch.proposer,
            prover: _output.prover,
            proposedAt: _rw.blockTimestamp,
            firstBlockId: _output.firstBlockId,
            lastBlockId: meta_.buildMeta.lastBlockId,
            livenessBond: _conf.livenessBond,
            provabilityBond: _conf.provabilityBond
        });
    }

    /// @dev The function __encodeExtraDataLower128Bits encodes certain information into a uint128
    /// - bits 0-7: used to store _conf.baseFeeConfig.sharingPctg.
    /// - bit 8: used to store _batch.isForcedInclusion.
    function _encodeExtraDataLower128Bits(
        I.Config memory _conf,
        I.Batch memory _batch
    )
        private
        pure
        returns (bytes32)
    {
        uint128 v = _conf.baseFeeConfig.sharingPctg; // bits 0-7
        v |= _batch.isForcedInclusion ? 1 << 8 : 0; // bit 8
        return bytes32(uint256(v));
    }
}
