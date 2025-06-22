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
        bytes32 calldataTxsHash;
        bytes32 txsHash;
        bytes32[] blobHashes;
        uint256 lastBlockTimestamp; // TODO
        uint256 lastAnchorBlockId;
        address prover;
    }

    struct Output {
        ValidationOutput result;
        I.Stats2 stats2;
        I.BatchMetadata meta;
        bytes32 metaHash;
    }

    function proposeBatch(
        I.State storage $,
        Context memory _ctx,
        I.BatchProposeMetadataEvidence calldata _parentProposeMetaEvidence,
        I.BatchParams memory _params,
        bytes calldata _txList,
        bytes calldata _additionalData
    )
        public // reduce code size
        returns (I.BatchMetadata memory meta_, I.Stats2 memory stats2_)
    {
        // First load stats2 in memory, as this struct only takes 1 slot in storage.
        stats2_ = $.stats2;

        // Validate parentProposeMeta against it in-storage hash.
        _validateParentProposeMeta($, _ctx, _parentProposeMetaEvidence, stats2_.numBatches - 1);

        // Validate the params and returns an updated version of it.
        ValidationOutput memory output;
        (_params, output) =
            _validateParams(_ctx, _parentProposeMetaEvidence.proposeMeta, _params, _txList);

        meta_ =
            _populateBatchMetadata(_ctx, _parentProposeMetaEvidence.proposeMeta, _params, output);

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
        internal
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
        I.BatchProposeMetadata calldata _parentProposeMeta,
        I.BatchParams memory _params,
        bytes calldata _calldata
    )
        internal
        view
        returns (I.BatchParams memory params_, ValidationOutput memory output_)
    {
        output_.calldataTxsHash = keccak256(_calldata);
        (output_.txsHash, output_.blobHashes) =
            _calculateTxsHash(output_.calldataTxsHash, _params.blobParams);
    }

    function _populateBatchMetadata(
        Context memory _ctx,
        I.BatchProposeMetadata calldata _parentProposeMeta,
        I.BatchParams memory _params,
        ValidationOutput memory _output
    )
        internal
        view
        returns (I.BatchMetadata memory meta_)
    {
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

    function _calculateTxsHash(
        bytes32 _txListHash,
        I.BlobParams memory _blobParams
    )
        internal
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
}
