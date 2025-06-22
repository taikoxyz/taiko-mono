// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/libs/LibNetwork.sol";
// import "./LibProve.sol";
// import "./LibAuth.sol";
import "./LibFork.sol";

/// @title LibPropose
/// @custom:security-contact security@taiko.xyz
library LibPropose {
    using SafeERC20 for IERC20;

    struct Context {
        I.Config config;
        address bondToken;
        address inboxWrapper;
        address signalService;
    }

    struct ValidationOutput {
        bytes32 txListHash;
        bytes32 txsHash;
        bytes32[] blobHashes;
        uint256 lastAnchorBlockId;
        uint256 firstBlockId;
        uint256 lastBlockId;
        I.AnchorBlock[] anchorBlocks;
        address prover;
    }

    function proposeBatch(
        I.State storage $,
        Context memory _ctx,
        I.BatchProposeMetadataEvidence calldata _parentProposeMetaEvidence,
        I.BatchParams calldata _params,
        bytes calldata _txList,
        bytes calldata /*_additionalData*/
    )
        public // reduce code size
        returns (I.BatchMetadata memory meta_, I.Stats2 memory stats2_)
    {
        unchecked {
            // First load stats2 in memory, as this struct only takes 1 slot in storage.
            stats2_ = $.stats2;

            // Validate parentProposeMeta against it in-storage hash.
            validateParentProposeMeta($, _ctx, _parentProposeMetaEvidence, stats2_.numBatches - 1);

            // Validate the params and returns an updated version of it.
            (I.BatchParams memory params, ValidationOutput memory output) = validateBatchParams(
                _ctx, stats2_, _parentProposeMetaEvidence.proposeMeta, _params, _txList
            );

            meta_ = populateBatchMetadata(_ctx, params, output);

            // Update storage -- only affecting 1 slot
            $.batches[stats2_.numBatches % _ctx.config.batchRingBufferSize] =
                I.Batch({ nextTransitionId: 1, metaHash: hashBatch(stats2_.numBatches, meta_) });

            // Update the in-memory stats2. This struct will be persisted to storage in LibVerify
            // instead of here to avoid unncessary re-writes.
            stats2_.numBatches += 1;
            stats2_.lastProposedIn = uint56(block.number);
        }
    }

    function validateParentProposeMeta(
        I.State storage $,
        Context memory ctx,
        I.BatchProposeMetadataEvidence calldata parentProposeMetaEvidence,
        uint256 parentBatchId
    )
        internal
        view
    {
        bytes32 h = keccak256(abi.encode(parentProposeMetaEvidence.proposeMeta));
        h = keccak256(abi.encode(parentProposeMetaEvidence.buildMetaHash, h));
        h = keccak256(abi.encode(parentBatchId, h, parentProposeMetaEvidence.proveVerifyHash));

        I.Batch storage parentBatch = $.batches[parentBatchId % ctx.config.batchRingBufferSize];
        require(parentBatch.metaHash == bytes30(h), "Invalid parent batch");
    }

    function validateBatchParams(
        Context memory _ctx,
        I.Stats2 memory _stats2,
        I.BatchProposeMetadata calldata _parentProposeMeta,
        I.BatchParams calldata _params,
        bytes calldata _txList
    )
        internal
        view
        returns (I.BatchParams memory params_, ValidationOutput memory output_)
    {
        unchecked {
            require(
                _stats2.numBatches <= _stats2.lastVerifiedBatchId + _ctx.config.maxUnverifiedBatches,
                I.TooManyBatches()
            );

            params_ = _params; // no longer need to use _param below!

            if (_ctx.inboxWrapper == address(0)) {
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
                require(msg.sender == _ctx.inboxWrapper, I.NotInboxWrapper());
            }

            // In the upcoming Shasta fork, we might need to enforce the coinbase address as the
            // preconfer address. This will allow us to implement preconfirmation features in L2
            // anchor transactions.
            if (params_.coinbase == address(0)) {
                params_.coinbase = params_.proposer;
            }

            if (params_.revertIfNotFirstProposal) {
                require(_stats2.lastProposedIn != block.number, I.NotFirstProposal());
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
                params_.blobParams.createdIn = uint64(block.number);
            } else {
                // this is a forced-inclusion batch, blobs were created in early blocks and are used
                // in the current batches
                require(params_.blobParams.createdIn != 0, I.InvalidBlobCreatedIn());
                require(params_.blobParams.numBlobs == 0, I.InvalidBlobParams());
                require(params_.blobParams.firstBlobIndex == 0, I.InvalidBlobParams());
            }
            uint256 nBlocks = params_.blocks.length;

            require(nBlocks != 0, I.BlockNotFound());
            require(nBlocks <= _ctx.config.maxBlocksPerBatch, I.TooManyBlocks());

            if (params_.lastBlockTimestamp == 0) {
                params_.lastBlockTimestamp = block.timestamp;
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

                require(numSignals <= _ctx.config.maxSignalsToReceive, I.TooManySignals());

                for (uint256 j; j < numSignals; ++j) {
                    require(
                        ISignalService(_ctx.signalService).isSignalSent(blockParams.signalSlots[j]),
                        I.SignalNotSent()
                    );
                }
            }

            require(params_.lastBlockTimestamp >= totalShift, I.TimestampTooSmall());

            uint256 firstBlockTimestamp = params_.lastBlockTimestamp - totalShift;

            require(
                firstBlockTimestamp
                    + _ctx.config.maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                    >= block.timestamp,
                I.TimestampTooSmall()
            );

            require(
                firstBlockTimestamp >= _parentProposeMeta.lastBlockTimestamp,
                I.TimestampSmallerThanParent()
            );

            output_.anchorBlocks = new I.AnchorBlock[](nBlocks);

            bool foundNoneZeroAnchorBlockId;
            for (uint256 i; i < nBlocks; ++i) {
                uint64 anchorBlockId = params_.blocks[i].anchorBlockId;
                if (anchorBlockId != 0) {
                    require(
                        foundNoneZeroAnchorBlockId
                            || anchorBlockId + _ctx.config.maxAnchorHeightOffset >= block.number,
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
                msg.sender == _ctx.inboxWrapper || foundNoneZeroAnchorBlockId,
                I.NoAnchorBlockIdWithinThisBatch()
            );

            output_.txListHash = keccak256(_txList);
            (output_.txsHash, output_.blobHashes) =
                calculateTxsHash(output_.txListHash, params_.blobParams);

            output_.firstBlockId = _parentProposeMeta.lastBlockId + 1;
            output_.lastBlockId = output_.firstBlockId + nBlocks;

            LibFork.checkBlocksInShastaFork(_ctx.config, output_.firstBlockId, output_.lastBlockId);
        }
    }

    function calculateTxsHash(
        bytes32 _txListHash,
        I.BlobParams memory _blobParams
    )
        internal
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

    function populateBatchMetadata(
        Context memory _ctx,
        I.BatchParams memory _params,
        ValidationOutput memory _output
    )
        internal
        view
        returns (I.BatchMetadata memory meta_)
    {
        unchecked {
            meta_.buildMeta = I.BatchBuildMetadata({
                txsHash: _output.txsHash,
                blobHashes: _output.blobHashes,
                extraData: bytes32(uint256(encodeExtraDataLower128Bits(_ctx.config, _params))),
                coinbase: _params.coinbase,
                proposedIn: block.number,
                blobCreatedIn: _params.blobParams.createdIn,
                blobByteOffset: _params.blobParams.byteOffset,
                blobByteSize: _params.blobParams.byteSize,
                gasLimit: _ctx.config.blockMaxGasLimit,
                lastBlockId: _output.lastBlockId,
                lastBlockTimestamp: _params.lastBlockTimestamp,
                anchorBlocks: _output.anchorBlocks,
                blocks: _params.blocks,
                baseFeeConfig: _ctx.config.baseFeeConfig
            });

            meta_.proposeMeta = I.BatchProposeMetadata({
                lastBlockTimestamp: _params.lastBlockTimestamp,
                lastBlockId: meta_.buildMeta.lastBlockId,
                lastAnchorBlockId: _output.lastAnchorBlockId
            });

            meta_.proveMeta = I.BatchProveMetadata({
                proposer: _params.proposer,
                prover: _output.prover,
                proposedAt: block.timestamp,
                firstBlockId: _output.firstBlockId,
                provabilityBond: _ctx.config.provabilityBond
            });

            meta_.verifyMeta = I.BatchVerifyMeta({
                lastBlockId: meta_.buildMeta.lastBlockId,
                provabilityBond: _ctx.config.provabilityBond,
                livenessBond: _ctx.config.livenessBond
            });
        }
    }

    function hashBatch(
        uint256 batchId,
        I.BatchMetadata memory meta
    )
        internal
        pure
        returns (bytes30)
    {
        bytes32 hBuild = keccak256(abi.encode(meta.buildMeta));
        bytes32 hPropose = keccak256(abi.encode(meta.proposeMeta));
        bytes32 hProve = keccak256(abi.encode(meta.proveMeta));
        bytes32 hVerify = keccak256(abi.encode(meta.verifyMeta));
        bytes32 hBuildPropose = keccak256(abi.encode(hBuild, hPropose));
        bytes32 hProveVerify = keccak256(abi.encode(hProve, hVerify));
        return bytes30(keccak256(abi.encode(batchId, hBuildPropose, hProveVerify)));
    }

    /// @dev The function _encodeExtraDataLower128Bits encodes certain information into a uint128
    /// - bits 0-7: used to store _config.baseFeeConfig.sharingPctg.
    /// - bit 8: used to store _batchParams.isForcedInclusion.
    function encodeExtraDataLower128Bits(
        I.Config memory _config,
        I.BatchParams memory _params
    )
        internal
        pure
        returns (uint128 encoded_)
    {
        encoded_ |= _config.baseFeeConfig.sharingPctg; // bits 0-7
        encoded_ |= _params.isForcedInclusion ? 1 << 8 : 0; // bit 8
    }
}
