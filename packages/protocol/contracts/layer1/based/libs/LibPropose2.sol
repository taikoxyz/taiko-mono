// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/libs/LibNetwork.sol";
// import "./LibProve.sol";
// import "./LibAuth.sol";

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
        uint256 lastBlockTimestamp; // TODO
        uint256 lastAnchorBlockId;
        address prover;
        I.AnchorBlock[] anchorBlocks;
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
        // First load stats2 in memory, as this struct only takes 1 slot in storage.
        stats2_ = $.stats2;

        // Validate the params and returns an updated version of it.
        (I.BatchParams memory params, ValidationOutput memory output) =
            _validateParams(_ctx, stats2_, _parentProposeMetaEvidence.proposeMeta, _params, _txList);

        // Validate parentProposeMeta against it in-storage hash.
        _validateParentProposeMeta($, _ctx, _parentProposeMetaEvidence, stats2_.numBatches - 1);

        meta_ = _populateBatchMetadata(_ctx, _parentProposeMetaEvidence.proposeMeta, params, output);

        // Update storage -- only affecting 2 slots
        $.batches[stats2_.numBatches % _ctx.config.batchRingBufferSize] =
            I.Batch({ nextTransitionId: 1, metaHash: hashBatch(stats2_.numBatches, meta_) });

        // Update the in-memory stats2. This struct will be persisted to storage in LibVerify
        // instead of here to avoid unncessary re-writes.
        stats2_.numBatches += 1;
        stats2_.lastProposedIn = uint56(block.number);
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

    function _validateParentProposeMeta(
        I.State storage $,
        Context memory ctx,
        I.BatchProposeMetadataEvidence calldata parentProposeMetaEvidence,
        uint256 parentBatchId
    )
        private
        view
    {
        bytes32 h = keccak256(abi.encode(parentProposeMetaEvidence.proposeMeta));
        h = keccak256(abi.encode(parentProposeMetaEvidence.buildMetaHash, h));
        h = keccak256(abi.encode(parentBatchId, h, parentProposeMetaEvidence.proveVerifyHash));

        I.Batch storage parentBatch = $.batches[parentBatchId % ctx.config.batchRingBufferSize];
        require(parentBatch.metaHash == bytes30(h), "Invalid parent batch");
    }

    function _validateParams(
        Context memory _ctx,
        I.Stats2 memory _stats2,
        I.BatchProposeMetadata calldata _parentProposeMeta,
        I.BatchParams calldata _params,
        bytes calldata _txList
    )
        private
        view
        returns (I.BatchParams memory params_, ValidationOutput memory output_)
    {
        require(
            _stats2.numBatches <= _stats2.lastVerifiedBatchId + _ctx.config.maxUnverifiedBatches,
            I.TooManyBatches()
        );

        // bytes32 parentMetaHash;
        // uint64 lastBlockTimestamp;
        // // Specifies the number of blocks to be generated from this batch.
        // BlockParams[] blocks;
        // bytes proverAuth;

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

        output_.anchorBlocks = new I.AnchorBlock[](params_.blocks.length);

        bool foundNoneZeroAnchorBlockId;
        for (uint256 i; i < params_.blocks.length; ++i) {
            uint64 anchorBlockId = params_.blocks[i].anchorBlockId;
            if (anchorBlockId != 0) {
                require(
                    foundNoneZeroAnchorBlockId
                        || anchorBlockId + _ctx.config.maxAnchorHeightOffset >= block.number,
                    I.AnchorIdTooSmall()
                );

                require(anchorBlockId > output_.lastAnchorBlockId, I.AnchorIdSmallerThanParent());

                output_.anchorBlocks[i] = I.AnchorBlock(anchorBlockId, blockhash(anchorBlockId));
                require(output_.anchorBlocks[i].blockHash != 0, I.ZeroAnchorBlockHash());

                foundNoneZeroAnchorBlockId = true;
                output_.lastAnchorBlockId = anchorBlockId;
            }
        }

        // Ensure that if msg.sender is not the inboxWrapper, at least one block must
        // have a
        // non-zero anchor block id. Otherwise, delegate this validation to the
        // inboxWrapper
        // contract.
        require(
            msg.sender == _ctx.inboxWrapper || foundNoneZeroAnchorBlockId,
            I.NoAnchorBlockIdWithinThisBatch()
        );

        output_.txListHash = keccak256(_txList);
        (output_.txsHash, output_.blobHashes) =
            _calculateTxsHash(output_.txListHash, params_.blobParams);
    }

    function _populateBatchMetadata(
        Context memory _ctx,
        I.BatchProposeMetadata calldata _parentProposeMeta,
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
                extraData: bytes32(uint256(_encodeExtraDataLower128Bits(_ctx.config, _params))),
                coinbase: _params.coinbase,
                proposedIn: block.number,
                blobCreatedIn: _params.blobParams.createdIn,
                blobByteOffset: _params.blobParams.byteOffset,
                blobByteSize: _params.blobParams.byteSize,
                gasLimit: _ctx.config.blockMaxGasLimit,
                lastBlockId: _parentProposeMeta.lastBlockId + _params.blocks.length,
                lastBlockTimestamp: _parentProposeMeta.lastBlockTimestamp,
                anchorBlocks: new I.AnchorBlock[](_params.blocks.length),
                blocks: _params.blocks,
                baseFeeConfig: _ctx.config.baseFeeConfig
            });

            meta_.proposeMeta = I.BatchProposeMetadata({
                lastBlockTimestamp: _output.lastBlockTimestamp,
                lastBlockId: meta_.buildMeta.lastBlockId,
                lastAnchorBlockId: _output.lastAnchorBlockId
            });

            meta_.proveMeta = I.BatchProveMetadata({
                proposer: _params.proposer,
                prover: _output.prover,
                proposedAt: block.timestamp,
                firstBlockId: _parentProposeMeta.lastBlockId + 1,
                provabilityBond: _ctx.config.provabilityBond
            });

            meta_.verifyMeta = I.BatchVerifyMeta({
                lastBlockId: meta_.buildMeta.lastBlockId,
                provabilityBond: _ctx.config.provabilityBond,
                livenessBond: _ctx.config.livenessBond
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
        if (_blobParams.blobHashes.length != 0) {
            blobHashes_ = _blobParams.blobHashes;
        } else {
            blobHashes_ = new bytes32[](_blobParams.numBlobs);
            for (uint256 i; i < _blobParams.numBlobs; ++i) {
                unchecked {
                    blobHashes_[i] = blobhash(_blobParams.firstBlobIndex + i);
                }
            }
        }

        for (uint256 i; i < blobHashes_.length; ++i) {
            require(blobHashes_[i] != 0, I.BlobNotFound());
        }
        txsHash_ = keccak256(abi.encode(_txListHash, blobHashes_));
    }

    /// @dev The function _encodeExtraDataLower128Bits encodes certain information into a uint128
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
