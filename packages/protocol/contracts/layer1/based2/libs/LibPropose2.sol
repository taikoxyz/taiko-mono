// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibSummary.sol";
import "./LibAuth2.sol";
import "./LibFork2.sol";

/// @title LibPropose2
/// @custom:security-contact security@taiko.xyz
library LibPropose2 {
    error AnchorIdSmallerThanParent();
    error AnchorIdTooSmall();
    error AnchorIdZero();
    error BlobNotFound();
    error BlobNotSpecified();
    error BlockNotFound();
    error BlocksNotInCurrentFork();
    error CustomProposerMissing();
    error CustomProposerNotAllowed();
    error FirstBlockTimeShiftNotZero();
    error InvalidBlobCreatedIn();
    error InvalidBlobParams();
    error InvalidForcedInclusion();
    error InvalidSummary();
    error MetaHashNotMatch();
    error NoAnchorBlockIdWithinThisBatch();
    error NotEnoughAnchorIds();
    error NoBatchesToPropose();
    error NotInboxWrapper();
    error SignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error TooManyBatches();
    error TooManyBlocks();
    error TooManySignals();
    error ZeroAnchorBlockHash();

    struct ReadWrite {
        // reads
        uint48 blockTimestamp;
        uint48 blockNumber;
        bytes32 parentBatchMetaHash;
        function(I.BatchMetadata memory) pure returns (bytes memory) encodeBatchMetadata;
        function(I.Config memory, bytes32) view returns (bool) isSignalSent;
        function(I.Config memory, bytes32, uint256) view returns (bytes32, bool)
            loadTransitionMetaHash;
        function(uint64, uint64, bytes32,  bytes memory) view returns (address, address, uint96)
            validateProverAuth;
        function(uint256) view returns (bytes32) getBlobHash;
        // writes
        function(address, address, address, uint256) transferFee;
        function(address, uint256) creditBond;
        function(I.Config memory, address, uint256) debitBond;
        function(I.Config memory, uint256, bytes32) saveBatchMetaHash;
        function(I.Config memory, uint64, bytes32) syncChainData;
    }

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
        ReadWrite memory _rw,
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
        ReadWrite memory _rw,
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
        (I.Batch memory params, ParamsValidationOutput memory output) =
            _validateBatch(_conf, _rw, _batch, _parentProposeMeta);

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
        ReadWrite memory _rw,
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

    function _validateBatch(
        I.Config memory _conf,
        ReadWrite memory _rw,
        I.Batch memory _batch,
        I.BatchProposeMetadata memory _parentProposeMeta
    )
        private
        view
        returns (I.Batch memory, ParamsValidationOutput memory)
    {
        ParamsValidationOutput memory output;

        if (_conf.inboxWrapper == address(0)) {
            if (_batch.proposer == address(0)) {
                _batch.proposer = msg.sender;
            } else {
                require(_batch.proposer == msg.sender, CustomProposerNotAllowed());
            }

            // blob hashes are only accepted if the caller is trusted.
            require(_batch.blobs.hashes.length == 0, InvalidBlobParams());
            require(_batch.blobs.createdIn == 0, InvalidBlobCreatedIn());
            require(_batch.isForcedInclusion == false, InvalidForcedInclusion());
        } else {
            require(_batch.proposer != address(0), CustomProposerMissing());
            require(msg.sender == _conf.inboxWrapper, NotInboxWrapper());
        }

        // In the upcoming Shasta fork, we might need to enforce the coinbase address as the
        // preconfer address. This will allow us to implement preconfirmation features in L2
        // anchor transactions.
        if (_batch.coinbase == address(0)) {
            _batch.coinbase = _batch.proposer;
        }

        if (_batch.blobs.hashes.length == 0) {
            // this is a normal batch, blobs are created and used in the current batches.
            // firstBlobIndex can be non-zero.
            require(_batch.blobs.numBlobs != 0, BlobNotSpecified());
            require(_batch.blobs.createdIn == 0, InvalidBlobCreatedIn());
            _batch.blobs.createdIn = _rw.blockNumber;
        } else {
            // this is a forced-inclusion batch, blobs were created in early blocks and are used
            // in the current batches
            require(_batch.blobs.createdIn != 0, InvalidBlobCreatedIn());
            require(_batch.blobs.numBlobs == 0, InvalidBlobParams());
            require(_batch.blobs.firstBlobIndex == 0, InvalidBlobParams());
        }
        uint256 nBlocks = _batch.encodedBlocks.length;

        require(nBlocks != 0, BlockNotFound());
        require(nBlocks <= _conf.maxBlocksPerBatch, TooManyBlocks());

        output.blocks = new I.Block[](nBlocks);

        for (uint256 i; i < nBlocks; ++i) {
            output.blocks[i].numTransactions = uint16(uint256(_batch.encodedBlocks[i]));
            output.blocks[i].timeShift = uint8(uint256(_batch.encodedBlocks[i]) >> 16);
            output.blocks[i].anchorBlockId = uint48(uint256(_batch.encodedBlocks[i]) >> 24);
            output.blocks[i].numSignals = uint8(uint256(_batch.encodedBlocks[i]) >> 32 & 0xFF);
        }

        if (_batch.lastBlockTimestamp == 0) {
            _batch.lastBlockTimestamp = _rw.blockTimestamp;
        } else {
            require(_batch.lastBlockTimestamp <= _rw.blockTimestamp, TimestampTooLarge());
        }

        require(output.blocks[0].timeShift == 0, FirstBlockTimeShiftNotZero());

        uint64 totalShift;
        uint256 signalSlotsIdx;

        for (uint256 i; i < nBlocks; ++i) {
            totalShift += output.blocks[i].timeShift;

            if (output.blocks[i].numSignals == 0) continue;

            require(output.blocks[i].numSignals <= _conf.maxSignalsToReceive, TooManySignals());

            for (uint256 j; j < output.blocks[i].numSignals; ++j) {
                require(
                    _rw.isSignalSent(_conf, _batch.signalSlots[signalSlotsIdx]), SignalNotSent()
                );
                signalSlotsIdx++;
            }
        }

        require(_batch.lastBlockTimestamp >= totalShift, TimestampTooSmall());

        uint256 firstBlockTimestamp = _batch.lastBlockTimestamp - totalShift;

        require(
            firstBlockTimestamp + _conf.maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                >= _rw.blockTimestamp,
            TimestampTooSmall()
        );

        require(
            firstBlockTimestamp >= _parentProposeMeta.lastBlockTimestamp,
            TimestampSmallerThanParent()
        );

        output.anchorBlockHashes = new bytes32[](nBlocks);
        output.lastAnchorBlockId = _parentProposeMeta.lastAnchorBlockId;
        uint256 k;

        bool foundNoneZeroAnchorBlockId;
        for (uint256 i; i < nBlocks; ++i) {
            if (output.blocks[i].hasAnchorBlock) {
                require(k < _batch.anchorBlockIds.length, NotEnoughAnchorIds());
                uint48 anchorBlockId = _batch.anchorBlockIds[k];

                require(anchorBlockId != 0, AnchorIdZero());

                require(
                    foundNoneZeroAnchorBlockId
                        || anchorBlockId + _conf.maxAnchorHeightOffset >= _rw.blockNumber,
                    AnchorIdTooSmall()
                );

                require(anchorBlockId > output.lastAnchorBlockId, AnchorIdSmallerThanParent());
                output.anchorBlockHashes[k] = _rw.getBlobHash(anchorBlockId);
                require(output.anchorBlockHashes[k] != 0, ZeroAnchorBlockHash());

                foundNoneZeroAnchorBlockId = true;
                output.lastAnchorBlockId = anchorBlockId;
                k++;
            }
        }

        // Ensure that if msg.sender is not the inboxWrapper, at least one block must
        // have a non-zero anchor block id. Otherwise, delegate this validation to the
        // inboxWrapper contract.
        require(
            msg.sender == _conf.inboxWrapper || foundNoneZeroAnchorBlockId,
            NoAnchorBlockIdWithinThisBatch()
        );

        (output.txsHash, output.blobHashes) = _calculateTxsHash(_rw, _batch.blobs);

        output.firstBlockId = _parentProposeMeta.lastBlockId + 1;
        output.lastBlockId = uint48(output.firstBlockId + nBlocks);

        require(
            LibFork2.isBlocksInCurrentFork(_conf, output.firstBlockId, output.lastBlockId),
            BlocksNotInCurrentFork()
        );
        return (_batch, output);
    }

    function _calculateTxsHash(
        ReadWrite memory _rw,
        I.Blobs memory _blobs
    )
        private
        view
        returns (bytes32 txsHash_, bytes32[] memory blobHashes_)
    {
        unchecked {
            if (_blobs.hashes.length != 0) {
                blobHashes_ = _blobs.hashes;
            } else {
                blobHashes_ = new bytes32[](_blobs.numBlobs);
                for (uint256 i; i < _blobs.numBlobs; ++i) {
                    blobHashes_[i] = _rw.getBlobHash(_blobs.firstBlobIndex + i);
                }
            }

            for (uint256 i; i < blobHashes_.length; ++i) {
                require(blobHashes_[i] != 0, BlobNotFound());
            }
            txsHash_ = keccak256(abi.encode(blobHashes_));
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
        ReadWrite memory _rw,
        I.Batch memory _batch,
        ParamsValidationOutput memory _output
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
