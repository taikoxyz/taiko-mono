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
    error BlocksNotInCurrentFork();
    error InvalidSummary();
    error MetaHashNotMatch();

    struct Environment {
        // immutables
        I.Config conf;
        address inboxWrapper;
        address sender;
        uint48 blockTimestamp;
        uint48 blockNumber;
        // reads
        bytes32 parentBatchMetaHash;
        function(bytes32) view returns (bool) isSignalSent;
        function(I.Config memory, I.Summary memory, uint256) view returns (bytes32)
            loadTransitionMetaHash;
        function(uint64, uint64, bytes32, bytes32, bytes calldata) view returns (address, address, uint96)
            validateProverAuth;
        function(uint256) view returns (bytes32) getBlobHash;
        // writes
        function(I.Config memory, uint256, bytes32) saveBatchMetaHash;
        function(address, address, uint256) debitBond;
        function(address, uint256) creditBond;
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
        I.Summary calldata _summary,
        I.BatchProposeMetadataEvidence calldata _evidence,
        I.BatchParams calldata _params,
        bytes calldata _txList,
        bytes calldata /*_additionalData*/
    )
        internal
        returns (I.BatchMetadata memory meta_, I.Summary memory summary_)
    {
        summary_ = _summary; // make a copy for update
        unchecked {
            // Validate parentProposeMeta against its meta hash
            _validateBatchProposeMeta(_evidence, _env.parentBatchMetaHash);

            // Validate the params and returns an updated copy
            (I.BatchParams memory params, ValidationOutput memory output) =
                _validateBatchParams(_env, summary_, _evidence.proposeMeta, _params, _txList);

            output.prover = _validateProver(_env, summary_, _params.proverAuth, params, output);
            meta_ = _populateBatchMetadata(_env, params, output);

            _env.saveBatchMetaHash(
                _env.conf, summary_.numBatches, hashBatch(summary_.numBatches, meta_)
            );

            summary_.numBatches += 1;
            summary_.lastProposedIn = uint48(block.number);
        }
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

                if (bondDelta < 0) {
                    _env.debitBond(_env.conf.bondToken, prover_, uint256(-bondDelta));
                } else {
                    _env.creditBond(prover_, uint256(bondDelta));
                }
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
                I.TooManyBatches()
            );

            params_ = _params; // no longer need to use _param below!

            if (_env.inboxWrapper == address(0)) {
                if (params_.proposer == address(0)) {
                    params_.proposer = _env.sender;
                } else {
                    require(params_.proposer == _env.sender, I.CustomProposerNotAllowed());
                }

                // blob hashes are only accepted if the caller is trusted.
                require(params_.blobParams.blobHashes.length == 0, I.InvalidBlobParams());
                require(params_.blobParams.createdIn == 0, I.InvalidBlobCreatedIn());
                require(params_.isForcedInclusion == false, I.InvalidForcedInclusion());
            } else {
                require(params_.proposer != address(0), I.CustomProposerMissing());
                require(_env.sender == _env.inboxWrapper, I.NotInboxWrapper());
            }

            // In the upcoming Shasta fork, we might need to enforce the coinbase address as the
            // preconfer address. This will allow us to implement preconfirmation features in L2
            // anchor transactions.
            if (params_.coinbase == address(0)) {
                params_.coinbase = params_.proposer;
            }

            if (params_.revertIfNotFirstProposal) {
                require(_summary.lastProposedIn != _env.blockNumber, I.NotFirstProposal());
            }

            if (_txList.length != 0) {
                // calldata is used for data availability
                require(params_.blobParams.firstBlobIndex == 0, I.InvalidBlobParams());
                require(params_.blobParams.numBlobs == 0, I.InvalidBlobParams());
                require(params_.blobParams.createdIn == 0, I.InvalidBlobCreatedIn());
                require(params_.blobParams.blobHashes.length == 0, I.InvalidBlobParams());
            } else if (params_.blobParams.blobHashes.length == 0) {
                // this is a normal batch, blobs are created and used in the current batches.
                // firstBlobIndex can be non-zero.
                require(params_.blobParams.numBlobs != 0, I.BlobNotSpecified());
                require(params_.blobParams.createdIn == 0, I.InvalidBlobCreatedIn());
                params_.blobParams.createdIn = _env.blockNumber;
            } else {
                // this is a forced-inclusion batch, blobs were created in early blocks and are used
                // in the current batches
                require(params_.blobParams.createdIn != 0, I.InvalidBlobCreatedIn());
                require(params_.blobParams.numBlobs == 0, I.InvalidBlobParams());
                require(params_.blobParams.firstBlobIndex == 0, I.InvalidBlobParams());
            }
            uint256 nBlocks = params_.blocks.length;

            require(nBlocks != 0, I.BlockNotFound());
            require(nBlocks <= _env.conf.maxBlocksPerBatch, I.TooManyBlocks());

            if (params_.lastBlockTimestamp == 0) {
                params_.lastBlockTimestamp = _env.blockTimestamp;
            } else {
                require(params_.lastBlockTimestamp <= _env.blockTimestamp, I.TimestampTooLarge());
            }

            require(params_.blocks[0].timeShift == 0, I.FirstBlockTimeShiftNotZero());

            uint64 totalShift;

            for (uint256 i; i < nBlocks; ++i) {
                I.BlockParams memory blockParams = params_.blocks[i];
                totalShift += blockParams.timeShift;

                uint256 numSignals = blockParams.signalSlots.length;
                if (numSignals == 0) continue;

                require(numSignals <= _env.conf.maxSignalsToReceive, I.TooManySignals());

                for (uint256 j; j < numSignals; ++j) {
                    require(_env.isSignalSent(blockParams.signalSlots[j]), I.SignalNotSent());
                }
            }

            require(params_.lastBlockTimestamp >= totalShift, I.TimestampTooSmall());

            uint256 firstBlockTimestamp = params_.lastBlockTimestamp - totalShift;

            require(
                firstBlockTimestamp
                    + _env.conf.maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                    >= _env.blockTimestamp,
                I.TimestampTooSmall()
            );

            require(
                firstBlockTimestamp >= _parentProposeMeta.lastBlockTimestamp,
                I.TimestampSmallerThanParent()
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
                        I.AnchorIdTooSmall()
                    );

                    require(
                        anchorBlockId > output_.lastAnchorBlockId, I.AnchorIdSmallerThanParent()
                    );
                    output_.anchorBlocks[i] =
                        I.AnchorBlock(anchorBlockId, _env.getBlobHash(anchorBlockId));
                    require(output_.anchorBlocks[i].blockHash != 0, I.ZeroAnchorBlockHash());

                    foundNoneZeroAnchorBlockId = true;
                    output_.lastAnchorBlockId = anchorBlockId;
                }
            }

            // Ensure that if msg.sender is not the inboxWrapper, at least one block must
            // have a non-zero anchor block id. Otherwise, delegate this validation to the
            // inboxWrapper contract.
            require(
                _env.sender == _env.inboxWrapper || foundNoneZeroAnchorBlockId,
                I.NoAnchorBlockIdWithinThisBatch()
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

    function _populateBatchMetadata(
        Environment memory _env,
        I.BatchParams memory _params,
        ValidationOutput memory _output
    )
        private
        view
        returns (I.BatchMetadata memory meta_)
    {
        unchecked {
            meta_.buildMeta = I.BatchBuildMetadata({
                txsHash: _output.txsHash,
                blobHashes: _output.blobHashes,
                extraData: bytes32(uint256(_encodeExtraDataLower128Bits(_env.conf, _params))),
                coinbase: _params.coinbase,
                proposedIn: uint48(block.number),
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
                proposedAt: uint48(block.timestamp),
                firstBlockId: _output.firstBlockId,
                lastBlockId: meta_.buildMeta.lastBlockId,
                livenessBond: _env.conf.livenessBond,
                provabilityBond: _env.conf.provabilityBond
            });
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
                require(blobHashes_[i] != 0, I.BlobNotFound());
            }
            txsHash_ = keccak256(abi.encode(_txListHash, blobHashes_));
        }
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
        returns (uint128 encoded_)
    {
        encoded_ |= _config.baseFeeConfig.sharingPctg; // bits 0-7
        encoded_ |= _params.isForcedInclusion ? 1 << 8 : 0; // bit 8
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
}
