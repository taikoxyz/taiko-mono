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

    struct SyncBlock {
        uint64 batchId;
        uint64 blockId;
        uint24 tid;
        bytes32 stateRoot;
    }

    struct Env {
        address signalService;
        I.Config config;
        bool paused;
    }

    function verifyBatches(
        I.State storage $,
        LibData2.Env memory _env,
        I.Summary memory _summary,
        uint8 _count
    )
        internal
    {
        _summary = _verifyBatches($, _env, _summary, _count);
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

        uint256 batchId = summary_.lastSyncedBatchId + 1;

        if (!LibFork.isBlocksInCurrentFork(_env.config, i, i)) {
            return summary_;
        }
        uint256 stopBatchId = uint256(summary_.numBatches).min(
            _count * _env.config.maxBatchesToVerify + summary_.lastSyncedBatchId + 1
        );

        // uint256 nBatches = stopBatchId - i;

        uint256 nTransitions = _trans.length;

        uint256 i;
        for (; batchId < stopBatchId; ++batchId) {
            uint256 slot = batchId % _env.config.batchRingBufferSize;

            bytes32 firstTransitionParentHash = $.transitions[slot][1].parentHash; // 1 SLOAD
            if (firstTransitionParentHash == LibData2.FIRST_TRAN_PARENT_HASH_PLACEHOLDER) {
                // this batch is not proved with at least one transition
                break;
            }

            bytes32 tranMetaHash;
            if (firstTransitionParentHash == _summary.lastBlockHash) {
                tranMetaHash = $.transitions[slot][1].metaHash;
            } else {
                tranMetaHash = $.transitionMetaHashes[batchId][_summary.lastBlockHash];
            }

            if (tranMetaHash == 0) break;

            require(i < nTransitions, "missing transitions");
            require(
                tranMetaHash == keccak256(abi.encode(_trans[i])), "Invalid transition meta hash"
            );

            summary_.lastBlockHash = _trans[i].blockHash;
            // summary_.lastSyncedBatchId = batchId;
            // summary_.lastSyncedAt = uint48(block.timestamp);

            i++;
        }
    }
}
