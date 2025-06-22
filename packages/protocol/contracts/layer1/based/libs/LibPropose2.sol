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
        // bytes2 txListHash;
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

        // Validate parentProposeMeta against it hash.
        _validateParentProposeMeta(ctx, parentProposeMeta);

        // Validate the params and returns an updated version of it.
        params = _validateParams(ctx, parentProposeMeta, params, txList, additionalData);

        output.meta = _compileBatch();

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

    function _compileBatch() internal view returns (I.BatchMetadata memory meta) { }
}
