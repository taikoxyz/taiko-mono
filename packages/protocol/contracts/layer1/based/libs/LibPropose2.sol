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

    struct ValidationResult {
        bytes32 calldataTxsHash;
        bytes32 txsHash;
        bytes32[] blobHashes;
        uint256 lastBlockTimestamp; // TODO
        uint256 lastAnchorBlockId;
        address prover;
    }

    struct Output {
        ValidationResult result;
        I.Stats2 stats2;
        I.BatchMetadata meta;
        bytes32 metaHash;
    }

    function proposeBatch(
        I.State storage $,
        Context memory ctx,
        I.BatchProposeMetadataEvidence calldata parentProposeMetaEvidence,
        I.BatchParams memory params,
        bytes calldata txList,
        bytes calldata additionalData
    )
        public // reduce code size
        returns (I.BatchMetadata memory meta, I.Stats2 memory stats2)
    {
        // First load stats2 in memory, as this struct only takes 1 slot in storage.
        stats2 = $.stats2;

        // Validate parentProposeMeta against it hash.
        _validateParentProposeMeta($, ctx, stats2, parentProposeMetaEvidence);

        // Validate the params and returns an updated version of it.
        ValidationResult memory result;
        (params, result) = _validateParams(
            ctx, parentProposeMetaEvidence.proposeMeta, params, txList, additionalData
        );

        meta = _populateBatchMetadata(parentProposeMetaEvidence.proposeMeta, ctx, params, result);

        // Update storage -- only affecting 2 slots
        $.batches[stats2.numBatches % ctx.config.batchRingBufferSize] = I.Batch({
            blockId: stats2.numBatches,
            verifiedTransitionId: 0,
            nextTransitionId: 1,
            metaHash: hashBatch(meta)
        });

        // Update the in-memory stats2. This struct will be persisted to storage in LibVerify
        // instead of here to avoid unncessary re-writes.
        stats2.numBatches += 1;
        stats2.lastProposedIn = uint56(block.number);
    }

    function hashBatch(I.BatchMetadata memory meta) internal pure returns (bytes32) {
        bytes32 hBuild = keccak256(abi.encode(meta.buildMeta));
        bytes32 hPropose = keccak256(abi.encode(meta.proposeMeta));
        bytes32 hProve = keccak256(abi.encode(meta.proveMeta));
        bytes32 hVerify = keccak256(abi.encode(meta.verifyMeta));
        bytes32 hBuildPropose = keccak256(abi.encode(hBuild, hPropose));
        bytes32 hProveVerify = keccak256(abi.encode(hProve, hVerify));
        return keccak256(abi.encode(hBuildPropose, hProveVerify));
    }

    function _validateParentProposeMeta(
        I.State storage $,
        Context memory ctx,
        I.Stats2 memory stats2,
        I.BatchProposeMetadataEvidence calldata parentProposeMetaEvidence
    )
        internal
        view
    {
        I.Batch storage parentBatch =
            $.batches[(stats2.numBatches - 1) % ctx.config.batchRingBufferSize];
        bytes32 h = keccak256(abi.encode(parentProposeMetaEvidence.proposeMeta));
        h = keccak256(abi.encode(parentProposeMetaEvidence.buildMetaHash, h));
        h = keccak256(abi.encode(h, parentProposeMetaEvidence.proveVerifyHash));
        require(parentBatch.metaHash == h, "Invalid parent batch");
    }

    function _validateParams(
        Context memory ctx,
        I.BatchProposeMetadata calldata parentProposeMeta,
        I.BatchParams memory params,
        bytes calldata calldataTxList,
        bytes calldata additionalData
    )
        internal
        view
        returns (I.BatchParams memory params_, ValidationResult memory result_)
    {
        result_.calldataTxsHash = keccak256(calldataTxList);
        (result_.txsHash, result_.blobHashes) =
            _calculateTxsHash(result_.calldataTxsHash, params.blobParams);
    }

    function _populateBatchMetadata(
        I.BatchProposeMetadata calldata parentProposeMeta,
        Context memory ctx,
        I.BatchParams memory params,
        ValidationResult memory result
    )
        internal
        view
        returns (I.BatchMetadata memory meta)
    {
        meta.buildMeta = I.BatchBuildMetadata({
            txsHash: result.txsHash,
            blobHashes: result.blobHashes,
            extraData: bytes32(uint256(_encodeExtraDataLower128Bits(ctx.config, params))),
            coinbase: params.coinbase,
            proposedIn: block.number,
            blobCreatedIn: params.blobParams.createdIn,
            blobByteOffset: params.blobParams.byteOffset,
            blobByteSize: params.blobParams.byteSize,
            gasLimit: ctx.config.blockMaxGasLimit,
            lastBlockId: parentProposeMeta.lastBlockId + params.blocks.length,
            lastBlockTimestamp: parentProposeMeta.lastBlockTimestamp,
            anchorBlocks: new I.AnchorBlock[](params.blocks.length),
            blocks: params.blocks,
            baseFeeConfig: ctx.config.baseFeeConfig
        });

        meta.proposeMeta = I.BatchProposeMetadata({
            lastBlockTimestamp: result.lastBlockTimestamp,
            lastBlockId: meta.buildMeta.lastBlockId,
            lastAnchorBlockId: result.lastAnchorBlockId
        });

        meta.proveMeta = I.BatchProveMetadata({
            proposer: params.proposer,
            prover: result.prover,
            proposedAt: block.timestamp,
            firstBlockId: parentProposeMeta.lastBlockId + 1,
            provabilityBond: ctx.config.provabilityBond
        });

        meta.verifyMeta = I.BatchVerifyMeta({
            lastBlockId: meta.buildMeta.lastBlockId,
            provabilityBond: ctx.config.provabilityBond,
            livenessBond: ctx.config.livenessBond
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
        returns (bytes32 hash_, bytes32[] memory blobHashes_)
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
        hash_ = keccak256(abi.encode(_txListHash, blobHashes_));
    }
}
