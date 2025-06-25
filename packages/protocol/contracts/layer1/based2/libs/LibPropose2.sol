// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibData2.sol";
import "./LibAuth2.sol";
import "./LibFork2.sol";
import "./LibBonds2.sol";

/// @title LibPropose2
/// @custom:security-contact security@taiko.xyz
library LibPropose2 {
    using SafeERC20 for IERC20;

    error BlocksNotInCurrentFork();
    error InvalidSummary();
    error MetaHashNotMatch();

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
        I.State storage $,
        LibData2.Env memory _env,
        I.Summary calldata _summary,
        I.BatchProposeMetadataEvidence calldata __evidence,
        I.BatchParams calldata _params,
        bytes calldata _txList,
        bytes calldata /*_additionalData*/
    )
        internal
        returns (I.BatchMetadata memory meta_, I.Summary memory summary_)
    {
        unchecked {
            summary_ = _summary; // make a copy for update
            bytes32 summaryHash = $.summaryHash; // 1 SLOAD
            require(summaryHash >> 1 == keccak256(abi.encode(summary_)) >> 1, InvalidSummary());

            // Validate parentProposeMeta against it in-storage hash.
            _validateBatchProposeMeta(_env, $, __evidence, _summary.numBatches - 1);

            // Validate the params and returns an updated version of it.
            (I.BatchParams memory params, ValidationOutput memory output) =
                _validateBatchParams(_env, summary_, __evidence.proposeMeta, _params, _txList);

            output.prover = _validateProver(_env, $, summary_, params, output);
            meta_ = _populateBatchMetadata(_env, params, output);

            // Update storage -- only affecting 1 slot
            $.batches[summary_.numBatches % _env.config.batchRingBufferSize] =
                I.Batch(hashBatch(summary_.numBatches, meta_));

            // Update the in-memory stats2. This struct will be persisted to storage in LibVerify
            // instead of here to avoid unncessary re-writes.
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
        LibData2.Env memory _env,
        I.State storage $,
        I.Summary memory _summary,
        I.BatchParams memory _params,
        ValidationOutput memory _output
    )
        private
        returns (address prover_)
    {
        unchecked {
            if (_params.proverAuth.length == 0) {
                LibBonds2.debitBond(
                    $,
                    _env.bondToken,
                    _params.proposer,
                    _env.config.livenessBond + _env.config.provabilityBond
                );
                return _params.proposer;
            }

            bytes memory proverAuth = _params.proverAuth;
            // Circular dependency so zero it out. (BatchParams has proverAuth but
            // proverAuth has also batchParamsHash)
            _params.proverAuth = "";

            // Outsource the prover authentication to the LibAuth library to
            // reduce this contract's code size.
            I.ProverAuth memory auth = LibAuth2.validateProverAuth(
                _env.config.chainId,
                _summary.numBatches,
                keccak256(abi.encode(_params)),
                _output.txListHash,
                proverAuth
            );

            prover_ = auth.prover;

            if (auth.feeToken == _env.bondToken) {
                // proposer pay the prover fee with bond tokens
                LibBonds2.debitBond(
                    $, _env.bondToken, _params.proposer, auth.fee + _env.config.provabilityBond
                );

                // if bondDelta is negative (proverFee < livenessBond), deduct the diff
                // if not then add the diff to the bond balance
                int256 bondDelta = int96(auth.fee) - int96(_env.config.livenessBond);

                if (bondDelta < 0) {
                    LibBonds2.debitBond($, _env.bondToken, prover_, uint256(-bondDelta));
                } else {
                    LibBonds2.creditBond($, prover_, uint256(bondDelta));
                }
            } else if (_params.proposer == prover_) {
                LibBonds2.debitBond(
                    $,
                    _env.bondToken,
                    _params.proposer,
                    _env.config.livenessBond + _env.config.provabilityBond
                );
            } else {
                LibBonds2.debitBond(
                    $, _env.bondToken, _params.proposer, _env.config.provabilityBond
                );
                LibBonds2.debitBond($, _env.bondToken, prover_, _env.config.livenessBond);

                if (auth.fee != 0) {
                    IERC20(auth.feeToken).safeTransferFrom(_params.proposer, prover_, auth.fee);
                }
            }
        }
    }

    function _validateBatchProposeMeta(
        LibData2.Env memory _env,
        I.State storage $,
        I.BatchProposeMetadataEvidence calldata _evidence,
        uint256 _batchId
    )
        private
        view
    {
        bytes32 proposeMetaHash = keccak256(abi.encode(_evidence.proposeMeta));
        bytes32 rightHash = keccak256(abi.encode(proposeMetaHash, _evidence.proveMetaHash));
        bytes32 metaHash = keccak256(abi.encode(_evidence.idAndBuildHash, rightHash));

        I.Batch storage batch = $.batches[_batchId % _env.config.batchRingBufferSize];
        require(batch.metaHash == metaHash, MetaHashNotMatch());
    }

    function _validateBatchParams(
        LibData2.Env memory _env,
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
                _summary.numBatches <= _summary.lastSyncedBatchId + _env.config.maxUnverifiedBatches,
                I.TooManyBatches()
            );

            params_ = _params; // no longer need to use _param below!

            if (_env.inboxWrapper == address(0)) {
                if (params_.proposer == address(0)) {
                    params_.proposer = msg.sender;
                } else {
                    require(params_.proposer == msg.sender, I.CustomProposerNotAllowed());
                }

                // blob hashes are only accepted if the caller is trusted.
                require(params_.blobParams.blobHashes.length == 0, I.InvalidBlobParams());
                require(params_.blobParams.createdIn == 0, I.InvalidBlobCreatedIn());
                require(params_.isForcedInclusion == false, I.InvalidForcedInclusion());
            } else {
                require(params_.proposer != address(0), I.CustomProposerMissing());
                require(msg.sender == _env.inboxWrapper, I.NotInboxWrapper());
            }

            // In the upcoming Shasta fork, we might need to enforce the coinbase address as the
            // preconfer address. This will allow us to implement preconfirmation features in L2
            // anchor transactions.
            if (params_.coinbase == address(0)) {
                params_.coinbase = params_.proposer;
            }

            if (params_.revertIfNotFirstProposal) {
                require(_summary.lastProposedIn != block.number, I.NotFirstProposal());
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
                params_.blobParams.createdIn = uint48(block.number);
            } else {
                // this is a forced-inclusion batch, blobs were created in early blocks and are used
                // in the current batches
                require(params_.blobParams.createdIn != 0, I.InvalidBlobCreatedIn());
                require(params_.blobParams.numBlobs == 0, I.InvalidBlobParams());
                require(params_.blobParams.firstBlobIndex == 0, I.InvalidBlobParams());
            }
            uint256 nBlocks = params_.blocks.length;

            require(nBlocks != 0, I.BlockNotFound());
            require(nBlocks <= _env.config.maxBlocksPerBatch, I.TooManyBlocks());

            if (params_.lastBlockTimestamp == 0) {
                params_.lastBlockTimestamp = uint48(block.timestamp);
            } else {
                require(params_.lastBlockTimestamp <= block.timestamp, I.TimestampTooLarge());
            }

            require(params_.blocks[0].timeShift == 0, I.FirstBlockTimeShiftNotZero());

            uint64 totalShift;

            for (uint256 i; i < nBlocks; ++i) {
                I.BlockParams memory blockParams = params_.blocks[i];
                totalShift += blockParams.timeShift;

                uint256 numSignals = blockParams.signalSlots.length;
                if (numSignals == 0) continue;

                require(numSignals <= _env.config.maxSignalsToReceive, I.TooManySignals());

                for (uint256 j; j < numSignals; ++j) {
                    require(
                        ISignalService(_env.signalService).isSignalSent(blockParams.signalSlots[j]),
                        I.SignalNotSent()
                    );
                }
            }

            require(params_.lastBlockTimestamp >= totalShift, I.TimestampTooSmall());

            uint256 firstBlockTimestamp = params_.lastBlockTimestamp - totalShift;

            require(
                firstBlockTimestamp
                    + _env.config.maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                    >= block.timestamp,
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
                            || anchorBlockId + _env.config.maxAnchorHeightOffset >= block.number,
                        I.AnchorIdTooSmall()
                    );

                    require(
                        anchorBlockId > output_.lastAnchorBlockId, I.AnchorIdSmallerThanParent()
                    );
                    output_.anchorBlocks[i] = I.AnchorBlock(anchorBlockId, blockhash(anchorBlockId));
                    require(output_.anchorBlocks[i].blockHash != 0, I.ZeroAnchorBlockHash());

                    foundNoneZeroAnchorBlockId = true;
                    output_.lastAnchorBlockId = anchorBlockId;
                }
            }

            // Ensure that if msg.sender is not the inboxWrapper, at least one block must
            // have a non-zero anchor block id. Otherwise, delegate this validation to the
            // inboxWrapper contract.
            require(
                msg.sender == _env.inboxWrapper || foundNoneZeroAnchorBlockId,
                I.NoAnchorBlockIdWithinThisBatch()
            );

            output_.txListHash = keccak256(_txList);
            (output_.txsHash, output_.blobHashes) =
                _calculateTxsHash(output_.txListHash, params_.blobParams);

            output_.firstBlockId = _parentProposeMeta.lastBlockId + 1;
            output_.lastBlockId = uint48(output_.firstBlockId + nBlocks);

            require(
                LibFork2.isBlocksInCurrentFork(
                    _env.config, output_.firstBlockId, output_.lastBlockId
                ),
                BlocksNotInCurrentFork()
            );
        }
    }

    function _populateBatchMetadata(
        LibData2.Env memory _env,
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
                extraData: bytes32(uint256(_encodeExtraDataLower128Bits(_env.config, _params))),
                coinbase: _params.coinbase,
                proposedIn: uint48(block.number),
                blobCreatedIn: _params.blobParams.createdIn,
                blobByteOffset: _params.blobParams.byteOffset,
                blobByteSize: _params.blobParams.byteSize,
                gasLimit: _env.config.blockMaxGasLimit,
                lastBlockId: _output.lastBlockId,
                lastBlockTimestamp: _params.lastBlockTimestamp,
                anchorBlocks: _output.anchorBlocks,
                blocks: _params.blocks,
                baseFeeConfig: _env.config.baseFeeConfig
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
                livenessBond: _env.config.livenessBond,
                provabilityBond: _env.config.provabilityBond
            });
        }
    }

    function _calculateTxsHash(
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
                    blobHashes_[i] = blobhash(_blobParams.firstBlobIndex + i);
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
}
