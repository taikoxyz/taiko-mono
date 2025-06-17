// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../ITaikoInbox.sol";

/// @title LibRead
/// @custom:security-contact security@taiko.xyz
library LibRead {
    function getTransitionById(
        ITaikoInbox.State storage $,
        ITaikoInbox.Config memory _config,
        uint64 _batchId,
        uint24 _tid
    )
        public
        view
        returns (ITaikoInbox.TransitionState memory)
    {
        uint256 slot = _batchId % _config.batchRingBufferSize;
        ITaikoInbox.Batch storage batch = $.batches[slot];
        require(batch.batchId == _batchId, ITaikoInbox.BatchNotFound());
        require(_tid != 0, ITaikoInbox.TransitionNotFound());
        require(_tid < batch.nextTransitionId, ITaikoInbox.TransitionNotFound());
        return $.transitions[slot][_tid];
    }

    function getTransitionByParentHash(
        ITaikoInbox.State storage $,
        ITaikoInbox.Config memory _config,
        uint64 _batchId,
        bytes32 _parentHash
    )
        public
        view
        returns (ITaikoInbox.TransitionState memory)
    {
        uint256 slot = _batchId % _config.batchRingBufferSize;
        ITaikoInbox.Batch storage batch = $.batches[slot];
        require(batch.batchId == _batchId, ITaikoInbox.BatchNotFound());

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

        require(tid != 0 && tid < batch.nextTransitionId, ITaikoInbox.TransitionNotFound());
        return $.transitions[slot][tid];
    }

    function getBatch(
        ITaikoInbox.State storage $,
        ITaikoInbox.Config memory _config,
        uint64 _batchId
    )
        internal
        view
        returns (ITaikoInbox.Batch storage batch_)
    {
        batch_ = $.batches[_batchId % _config.batchRingBufferSize];
        require(batch_.batchId == _batchId, ITaikoInbox.BatchNotFound());
    }

    function getBatchVerifyingTransition(
        ITaikoInbox.State storage $,
        ITaikoInbox.Config memory _config,
        uint64 _batchId
    )
        internal
        view
        returns (ITaikoInbox.TransitionState memory ts_)
    {
        uint64 slot = _batchId % _config.batchRingBufferSize;
        ITaikoInbox.Batch storage batch = $.batches[slot];
        require(batch.batchId == _batchId, ITaikoInbox.BatchNotFound());

        if (batch.verifiedTransitionId != 0) {
            ts_ = $.transitions[slot][batch.verifiedTransitionId];
        }
    }
}
