// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox as I } from "../ITaikoInbox.sol";

/// @title LibRead
/// @custom:security-contact security@taiko.xyz
library LibRead {
    function getTransitionById(
        I.State storage $,
        I.Config memory _config,
        uint64 _batchId,
        uint24 _tid
    )
        public
        view
        returns (I.TransitionState memory)
    {
        uint256 slot = _batchId % _config.batchRingBufferSize;
        I.Batch storage batch = $.batches[slot];
        require(batch.batchId == _batchId, I.BatchNotFound());
        require(_tid != 0, I.TransitionNotFound());
        require(_tid < batch.nextTransitionId, I.TransitionNotFound());
        return $.transitions[slot][_tid];
    }

    function getTransitionByParentHash(
        I.State storage $,
        I.Config memory _config,
        uint64 _batchId,
        bytes32 _parentHash
    )
        public
        view
        returns (I.TransitionState memory)
    {
        uint256 slot = _batchId % _config.batchRingBufferSize;
        I.Batch storage batch = $.batches[slot];
        require(batch.batchId == _batchId, I.BatchNotFound());

        uint24 tid;
        if (batch.nextTransitionId > 1) {
            // This batch has at least one transition.
            if ($.transitions[slot][1].parentHash == _parentHash) {
                // Overwrite the first transition.
                tid = 1;
            } else if (batch.nextTransitionId > 2) {
                // Retrieve the transition ID using the parent hash from the mapping. If the ID
                // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                // existing transition.
                tid = $.transitionIds[_batchId][_parentHash];
            }
        }

        require(tid != 0 && tid < batch.nextTransitionId, I.TransitionNotFound());
        return $.transitions[slot][tid];
    }

    function getLastVerifiedTransition(
        I.State storage $,
        I.Config memory _config
    )
        public
        view
        returns (uint64 batchId_, uint64 blockId_, I.TransitionState memory ts_)
    {
        batchId_ = $.stats2.lastVerifiedBatchId;

        require(batchId_ >= _config.forkHeights.pacaya, I.BatchNotFound());

        blockId_ = getBatch($, _config, batchId_).lastBlockId;
        ts_ = getBatchVerifyingTransition($, _config, batchId_);
    }

    function getLastSyncedTransition(
        I.State storage $,
        I.Config memory _config
    )
        external
        view
        returns (uint64 batchId_, uint64 blockId_, I.TransitionState memory ts_)
    {
        batchId_ = $.stats1.lastSyncedBatchId;
        blockId_ = getBatch($, _config, batchId_).lastBlockId;
        ts_ = getBatchVerifyingTransition($, _config, batchId_);
    }

    function getBatch(
        I.State storage $,
        I.Config memory _config,
        uint64 _batchId
    )
        internal
        view
        returns (I.Batch storage batch_)
    {
        batch_ = $.batches[_batchId % _config.batchRingBufferSize];
        require(batch_.batchId == _batchId, I.BatchNotFound());
    }

    function getBatchVerifyingTransition(
        I.State storage $,
        I.Config memory _config,
        uint64 _batchId
    )
        internal
        view
        returns (I.TransitionState memory ts_)
    {
        uint64 slot = _batchId % _config.batchRingBufferSize;
        I.Batch storage batch = $.batches[slot];
        require(batch.batchId == _batchId, I.BatchNotFound());

        if (batch.verifiedTransitionId != 0) {
            ts_ = $.transitions[slot][batch.verifiedTransitionId];
        }
    }
}
