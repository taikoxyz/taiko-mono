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

    struct Output {
        // I.BatchProposeMetadata parentProposeMeta;
        // uint64 lastAnchorBlockId;
        bytes2 txListHash;
        uint256 lastBlockTimestamp; // TODO
        uint256 lastAnchorBlockId;
        address prover;
        // I.ProverAuth auth;
        // I.BatchParams params;
        I.Stats2 stats2;
        I.BatchMetadata meta;
        bytes32 metaHash;
    }

    function proposeBatch(
        I.State storage $,
        Context memory ctx,
        I.BatchProposeMetadata calldata parentProposeMeta,
        I.BatchParams memory params,
        bytes calldata txList,
        bytes calldata additionalData
    )
        public // reduce code size
        returns (Output memory output)
    {
        // First load stats2 in memory, as this struct only takes 1 slot in storage.
        output.stats2 = $.stats2;
        output.txListHash = bytes2(keccak256(txList));

        // Validate parentProposeMeta against it hash.
        _validateParentProposeMeta(ctx, parentProposeMeta);

        // Validate the params and returns an updated version of it.
        params = _validateParams(ctx, parentProposeMeta, params, txList, additionalData);

        output.meta = _compileBatch(parentProposeMeta, ctx, params, output);

        // Update storage
        $.batches[output.stats2.numBatches % ctx.config.batchRingBufferSize] = I.Batch({
            blockId: output.stats2.numBatches,
            verifiedTransitionId: 0,
            nextTransitionId: 1,
            metaHash: hashBatch(output.meta)
        });

        // Update the in-memory stats2. This struct will be persisted to storage in LibVerify
        // instead of here to avoid unncessary re-writes.
        output.stats2.numBatches += 1;
        output.stats2.lastProposedIn = uint56(block.number);
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
        Context memory ctx,
        I.BatchProposeMetadata calldata parentProposeMeta
    )
        internal
        view
    { }

    function _validateParams(
        Context memory ctx,
        I.BatchProposeMetadata calldata parentProposeMeta,
        I.BatchParams memory params,
        bytes calldata txList,
        bytes calldata additionalData
    )
        internal
        view
        returns (I.BatchParams memory params_)
    { }

    function _compileBatch(
        I.BatchProposeMetadata calldata parentProposeMeta,
        Context memory ctx,
        I.BatchParams memory params,
        Output memory output
    )
        internal
        view
        returns (I.BatchMetadata memory meta)
    {
        meta.buildMeta = I.BatchBuildMetadata({
            txsHash: 0, // to be set later
            blobHashes: new bytes32[](0), // to be set later
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

        (meta.buildMeta.txsHash, meta.buildMeta.blobHashes) =
            _calculateTxsHash(output.txListHash, params.blobParams);

        meta.proposeMeta = I.BatchProposeMetadata({
            lastBlockTimestamp: output.lastBlockTimestamp,
            lastBlockId: meta.buildMeta.lastBlockId,
            lastAnchorBlockId: output.lastAnchorBlockId
        });

        meta.proveMeta = I.BatchProveMetadata({
            proposer: params.proposer,
            prover: output.prover,
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
