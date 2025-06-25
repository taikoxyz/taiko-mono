// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/shared/libs/LibMath.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibBonds2.sol";
import "./LibFork.sol";
import "./LibData2.sol";

/// @title LibVerify2
/// @custom:security-contact security@taiko.xyz
library LibVerify2 {
    using LibMath for uint256;

    error TransitionNotProvided();

    struct SyncBlock {
        uint48 batchId;
        uint48 blockId;
        bytes32 stateRoot;
    }

    function verifyBatches(
        I.State storage $,
        LibData2.Env memory _env,
        I.Summary memory _summary,
        I.TransitionMeta[] calldata _trans,
        uint8 _count
    )
        internal
    {
        _summary = _verifyBatches($, _env, _summary, _trans, _count);
        bytes32 newSummaryHash = (keccak256(abi.encode(_summary)) & ~bytes32(uint256(1)))
            | (_env.prevSummaryHash & bytes32(uint256(1)));
        $.summaryHash = newSummaryHash;
        emit I.SummaryUpdated(_summary, newSummaryHash);
    }

    function _verifyBatches(
        I.State storage $,
        LibData2.Env memory _env,
        I.Summary memory _summary,
        I.TransitionMeta[] calldata _trans,
        uint256 _count
    )
        private
        returns (I.Summary memory summary_)
    {
        summary_ = _summary; // make a copy for update

        uint48 batchId = summary_.lastSyncedBatchId + 1;

        if (!LibFork.isBlocksInCurrentFork(_env.config, batchId, batchId)) {
            return summary_;
        }
        uint256 stopBatchId = uint256(summary_.numBatches).min(
            _count * _env.config.maxBatchesToVerify + summary_.lastSyncedBatchId + 1
        );

        uint256 nTransitions = _trans.length;
        SyncBlock memory synced;

        uint256 i;
        for (; batchId < stopBatchId; ++batchId) {
            uint256 slot = batchId % _env.config.batchRingBufferSize;

            bytes32 firstTransitionParentHash = $.transitions[slot][1].parentHash; // 1 SLOAD
            if (firstTransitionParentHash == LibData2.FIRST_TRAN_PARENT_HASH_PLACEHOLDER) {
                // this batch is not proved with at least one transition
                break;
            }

            bytes32 tranMetaHash;
            if (firstTransitionParentHash == _summary.lastVerifiedBlockHash) {
                tranMetaHash = $.transitions[slot][1].metaHash;
            } else {
                tranMetaHash = $.transitionMetaHashes[batchId][_summary.lastVerifiedBlockHash];
            }

            if (tranMetaHash == 0) break;

            require(i < nTransitions, "missing transitions");
            require(tranMetaHash == keccak256(abi.encode(_trans[i])), TransitionNotProvided());

            summary_.lastVerifiedBlockHash = _trans[i].blockHash;

            if (batchId % _env.config.stateRootSyncInternal == 0) {
                synced.batchId = batchId;
                synced.blockId = _trans[i].lastBlockId;
                synced.stateRoot = _trans[i].stateRoot;
            }

            i++;
        }

        if (synced.batchId != 0) {
            summary_.lastSyncedBatchId = synced.batchId;
            summary_.lastSyncedAt = uint48(block.timestamp);
            ISignalService(_env.signalService).syncChainData(
                _env.config.chainId, LibSignals.STATE_ROOT, synced.blockId, synced.stateRoot
            );
        }
    }
}
