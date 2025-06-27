// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibData2.sol";
import "./LibAuth2.sol";
import "./LibFork2.sol";

/// @title LibPropose2
/// @custom:security-contact security@taiko.xyz
library LibPropose2 {
    error AnchorIdSmallerThanParent();
    error AnchorIdTooSmall();
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
    error NotFirstProposal();
    error NotInboxWrapper();
    error SignalNotSent();
    error TimestampSmallerThanParent();
    error TimestampTooLarge();
    error TimestampTooSmall();
    error TooManyBatches();
    error TooManyBlocks();
    error TooManySignals();
    error ZeroAnchorBlockHash();

    struct Environment {
        // reads
        I.Config conf;
        address inboxWrapper;
        address sender;
        uint48 blockTimestamp;
        uint48 blockNumber;
        bytes32 parentBatchMetaHash;
        function(bytes32) view returns (bool) isSignalSent;
        function(I.Config memory, bytes32, uint256) view returns (bytes32) loadTransitionMetaHash;
        function(uint64, uint64, bytes32, bytes32, bytes calldata) view returns (address, address, uint96)
            validateProverAuth;
        function(uint256) view returns (bytes32) getBlobHash;
        // writes
        function(address, address, uint256) debitBond;
        function(address, uint256) creditBond;
        function(I.Config memory, uint256, bytes32) saveBatchMetaHash;
        function(address, address, address, uint256) transferFee;
        function(I.Config memory, uint64, bytes32) syncChainData;
    }

    struct ValidationOutput {
        bytes32 txListHash;
        bytes32 txsHash;
        bytes32[] blobHashes;
        uint48 lastAnchorBlockId;
        uint48 firstBlockId;
        uint48 lastBlockId;
        I.AnchorBlock[] anchorBlocks;
        address prover;
    }

    function proposeBatch(
        Environment memory _env,
        I.Summary memory _summary,
        I.BatchProposeMetadataEvidence calldata _evidence,
        I.BatchParams calldata _params,
        bytes calldata _txList,
        bytes calldata /*_additionalData*/
    )
        internal
        returns (I.BatchMetadata memory, I.Summary memory)
    {
        // Validate parentProposeMeta against its meta hash
        _validateBatchProposeMeta(_evidence, _env.parentBatchMetaHash);

        // Validate the params and returns an updated copy
        (I.BatchParams memory params, ValidationOutput memory output) =
            _validateBatchParams(_env, _summary, _evidence.proposeMeta, _params, _txList);

        output.prover = _validateProver(_env, _summary, _params.proverAuth, params, output);
        I.BatchMetadata memory meta = _populateBatchMetadata(_env, params, output);

        _env.saveBatchMetaHash(_env.conf, _summary.numBatches, hashBatch(_summary.numBatches, meta));

        unchecked {
            _summary.numBatches += 1;
            _summary.lastProposedIn = _env.blockNumber;
        }
        return (meta, _summary);
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
        Environment memory _env,
        I.Summary memory _summary,
        bytes calldata _proverAuth,
        I.BatchParams memory _params,
        ValidationOutput memory _output
    )
        private
        returns (address prover_)
    {
        unchecked {
            if (_params.proverAuth.length == 0) {
                _env.debitBond(
                    _env.conf.bondToken,
                    _params.proposer,
                    _env.conf.livenessBond + _env.conf.provabilityBond
                );
                return _params.proposer;
            }

            // Circular dependency so zero it out. (BatchParams has proverAuth but
            // proverAuth has also batchParamsHash)
            _params.proverAuth = "";

            // Outsource the prover authentication to the LibAuth library to
            // reduce this contract's code size.
            address feeToken;
            uint96 fee;
            (prover_, feeToken, fee) = _env.validateProverAuth(
                _env.conf.chainId,
                _summary.numBatches,
                keccak256(abi.encode(_params)),
                _output.txListHash,
                _proverAuth
            );

            if (feeToken == _env.conf.bondToken) {
                // proposer pay the prover fee with bond tokens
                _env.debitBond(
                    _env.conf.bondToken, _params.proposer, fee + _env.conf.provabilityBond
                );

                // if bondDelta is negative (proverFee < livenessBond), deduct the diff
                // if not then add the diff to the bond balance
                int256 bondDelta = int96(fee) - int96(_env.conf.livenessBond);

                bondDelta < 0
                    ? _env.debitBond(_env.conf.bondToken, prover_, uint256(-bondDelta))
                    : _env.creditBond(prover_, uint256(bondDelta));
            } else if (_params.proposer == prover_) {
                _env.debitBond(
                    _env.conf.bondToken,
                    _params.proposer,
                    _env.conf.livenessBond + _env.conf.provabilityBond
                );
            } else {
                _env.debitBond(_env.conf.bondToken, _params.proposer, _env.conf.provabilityBond);
                _env.debitBond(_env.conf.bondToken, prover_, _env.conf.livenessBond);

                if (fee != 0) {
                    _env.transferFee(feeToken, _params.proposer, prover_, fee);
                }
            }
        }
    }

    function _validateBatchParams(
        Environment memory _env,
        I.Summary memory _summary,
        I.BatchProposeMetadata calldata _parentProposeMeta,
        I.BatchParams calldata _params,
        bytes calldata _txList
    )
        private
        view
        returns (I.BatchParams memory params_, ValidationOutput memory output_)
    {
        unchecked {
            require(
                _summary.numBatches <= _summary.lastVerifiedBatchId + _env.conf.maxUnverifiedBatches,
                TooManyBatches()
            );

            params_ = _params; // no longer need to use _param below!

            if (_env.inboxWrapper == address(0)) {
                if (params_.proposer == address(0)) {
                    params_.proposer = _env.sender;
                } else {
                    require(params_.proposer == _env.sender, CustomProposerNotAllowed());
                }

                // blob hashes are only accepted if the caller is trusted.
                require(params_.blobParams.blobHashes.length == 0, InvalidBlobParams());
                require(params_.blobParams.createdIn == 0, InvalidBlobCreatedIn());
                require(params_.isForcedInclusion == false, InvalidForcedInclusion());
            } else {
                require(params_.proposer != address(0), CustomProposerMissing());
                require(_env.sender == _env.inboxWrapper, NotInboxWrapper());
            }

            // In the upcoming Shasta fork, we might need to enforce the coinbase address as the
            // preconfer address. This will allow us to implement preconfirmation features in L2
            // anchor transactions.
            if (params_.coinbase == address(0)) {
                params_.coinbase = params_.proposer;
            }

            if (params_.revertIfNotFirstProposal) {
                require(_summary.lastProposedIn != _env.blockNumber, NotFirstProposal());
            }

            if (_txList.length != 0) {
                // calldata is used for data availability
                require(params_.blobParams.firstBlobIndex == 0, InvalidBlobParams());
                require(params_.blobParams.numBlobs == 0, InvalidBlobParams());
                require(params_.blobParams.createdIn == 0, InvalidBlobCreatedIn());
                require(params_.blobParams.blobHashes.length == 0, InvalidBlobParams());
            } else if (params_.blobParams.blobHashes.length == 0) {
                // this is a normal batch, blobs are created and used in the current batches.
                // firstBlobIndex can be non-zero.
                require(params_.blobParams.numBlobs != 0, BlobNotSpecified());
                require(params_.blobParams.createdIn == 0, InvalidBlobCreatedIn());
                params_.blobParams.createdIn = _env.blockNumber;
            } else {
                // this is a forced-inclusion batch, blobs were created in early blocks and are used
                // in the current batches
                require(params_.blobParams.createdIn != 0, InvalidBlobCreatedIn());
                require(params_.blobParams.numBlobs == 0, InvalidBlobParams());
                require(params_.blobParams.firstBlobIndex == 0, InvalidBlobParams());
            }
            uint256 nBlocks = params_.blocks.length;

            require(nBlocks != 0, BlockNotFound());
            require(nBlocks <= _env.conf.maxBlocksPerBatch, TooManyBlocks());

            if (params_.lastBlockTimestamp == 0) {
                params_.lastBlockTimestamp = _env.blockTimestamp;
            } else {
                require(params_.lastBlockTimestamp <= _env.blockTimestamp, TimestampTooLarge());
            }

            require(params_.blocks[0].timeShift == 0, FirstBlockTimeShiftNotZero());

            uint64 totalShift;

            for (uint256 i; i < nBlocks; ++i) {
                I.BlockParams memory blockParams = params_.blocks[i];
                totalShift += blockParams.timeShift;

                uint256 numSignals = blockParams.signalSlots.length;
                if (numSignals == 0) continue;

                require(numSignals <= _env.conf.maxSignalsToReceive, TooManySignals());

                for (uint256 j; j < numSignals; ++j) {
                    require(_env.isSignalSent(blockParams.signalSlots[j]), SignalNotSent());
                }
            }

            require(params_.lastBlockTimestamp >= totalShift, TimestampTooSmall());

            uint256 firstBlockTimestamp = params_.lastBlockTimestamp - totalShift;

            require(
                firstBlockTimestamp
                    + _env.conf.maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                    >= _env.blockTimestamp,
                TimestampTooSmall()
            );

            require(
                firstBlockTimestamp >= _parentProposeMeta.lastBlockTimestamp,
                TimestampSmallerThanParent()
            );

            output_.anchorBlocks = new I.AnchorBlock[](nBlocks);
            output_.lastAnchorBlockId = _parentProposeMeta.lastAnchorBlockId;

            bool foundNoneZeroAnchorBlockId;
            for (uint256 i; i < nBlocks; ++i) {
                uint48 anchorBlockId = params_.blocks[i].anchorBlockId;
                if (anchorBlockId != 0) {
                    require(
                        foundNoneZeroAnchorBlockId
                            || anchorBlockId + _env.conf.maxAnchorHeightOffset >= _env.blockNumber,
                        AnchorIdTooSmall()
                    );

                    require(anchorBlockId > output_.lastAnchorBlockId, AnchorIdSmallerThanParent());
                    output_.anchorBlocks[i] =
                        I.AnchorBlock(anchorBlockId, _env.getBlobHash(anchorBlockId));
                    require(output_.anchorBlocks[i].blockHash != 0, ZeroAnchorBlockHash());

                    foundNoneZeroAnchorBlockId = true;
                    output_.lastAnchorBlockId = anchorBlockId;
                }
            }

            // Ensure that if msg.sender is not the inboxWrapper, at least one block must
            // have a non-zero anchor block id. Otherwise, delegate this validation to the
            // inboxWrapper contract.
            require(
                _env.sender == _env.inboxWrapper || foundNoneZeroAnchorBlockId,
                NoAnchorBlockIdWithinThisBatch()
            );

            output_.txListHash = keccak256(_txList);
            (output_.txsHash, output_.blobHashes) =
                _calculateTxsHash(_env, output_.txListHash, params_.blobParams);

            output_.firstBlockId = _parentProposeMeta.lastBlockId + 1;
            output_.lastBlockId = uint48(output_.firstBlockId + nBlocks);

            require(
                LibFork2.isBlocksInCurrentFork(_env.conf, output_.firstBlockId, output_.lastBlockId),
                BlocksNotInCurrentFork()
            );
        }
    }

    function _calculateTxsHash(
        Environment memory _env,
        bytes32 _txListHash,
        I.BlobParams memory _blobParams
    )
        private
        view
        returns (bytes32 txsHash_, bytes32[] memory blobHashes_)
    {
        unchecked {
            if (_blobParams.blobHashes.length != 0) {
                blobHashes_ = _blobParams.blobHashes;
            } else {
                blobHashes_ = new bytes32[](_blobParams.numBlobs);
                for (uint256 i; i < _blobParams.numBlobs; ++i) {
                    blobHashes_[i] = _env.getBlobHash(_blobParams.firstBlobIndex + i);
                }
            }

            for (uint256 i; i < blobHashes_.length; ++i) {
                require(blobHashes_[i] != 0, BlobNotFound());
            }
            txsHash_ = keccak256(abi.encode(_txListHash, blobHashes_));
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
        Environment memory _env,
        I.BatchParams memory _params,
        ValidationOutput memory _output
    )
        private
        pure
        returns (I.BatchMetadata memory meta_)
    {
        meta_.buildMeta = I.BatchBuildMetadata({
            txsHash: _output.txsHash,
            blobHashes: _output.blobHashes,
            extraData: _encodeExtraDataLower128Bits(_env.conf, _params),
            coinbase: _params.coinbase,
            proposedIn: _env.blockNumber,
            blobCreatedIn: _params.blobParams.createdIn,
            blobByteOffset: _params.blobParams.byteOffset,
            blobByteSize: _params.blobParams.byteSize,
            gasLimit: _env.conf.blockMaxGasLimit,
            lastBlockId: _output.lastBlockId,
            lastBlockTimestamp: _params.lastBlockTimestamp,
            anchorBlocks: _output.anchorBlocks,
            blocks: _params.blocks,
            baseFeeConfig: _env.conf.baseFeeConfig
        });

        meta_.proposeMeta = I.BatchProposeMetadata({
            lastBlockTimestamp: _params.lastBlockTimestamp,
            lastBlockId: meta_.buildMeta.lastBlockId,
            lastAnchorBlockId: _output.lastAnchorBlockId
        });

        meta_.proveMeta = I.BatchProveMetadata({
            proposer: _params.proposer,
            prover: _output.prover,
            proposedAt: _env.blockTimestamp,
            firstBlockId: _output.firstBlockId,
            lastBlockId: meta_.buildMeta.lastBlockId,
            livenessBond: _env.conf.livenessBond,
            provabilityBond: _env.conf.provabilityBond
        });
    }

    /// @dev The function __encodeExtraDataLower128Bits encodes certain information into a uint128
    /// - bits 0-7: used to store _config.baseFeeConfig.sharingPctg.
    /// - bit 8: used to store _batchParams.isForcedInclusion.
    function _encodeExtraDataLower128Bits(
        I.Config memory _config,
        I.BatchParams memory _params
    )
        private
        pure
        returns (bytes32)
    {
        uint128 v = _config.baseFeeConfig.sharingPctg; // bits 0-7
        v |= _params.isForcedInclusion ? 1 << 8 : 0; // bit 8
        return bytes32(uint256(v));
    }
}
