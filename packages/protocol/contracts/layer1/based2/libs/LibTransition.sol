// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

library LibTransition {
    function saveBatchMetaHash(
        I.State storage $,
        I.Config memory _conf,
        uint256 _batchId,
        bytes32 _metaHash
    )
        internal
    {
        $.batches[_batchId % _conf.batchRingBufferSize] = _metaHash;
    }

    function getBatchMetaHash(
        I.State storage $,
        I.Config memory _conf,
        uint256 _batchId
    )
        internal
        view
        returns (bytes32)
    {
        return $.batches[_batchId % _conf.batchRingBufferSize];
    }

    function loadTransitionMetaHash(
        I.State storage $,
        I.Config memory _conf,
        bytes32 _lastVerifiedBlockHash,
        uint256 _batchId
    )
        internal
        view
        returns (bytes32 metaHash_, bool isFirstTransition_)
    {
        uint256 slot = _batchId % _conf.batchRingBufferSize;
        // 1 SLOAD
        (uint48 embededBatchId, bytes32 partialParentHash) =
            _loadBatchIdAndPartialParentHash($, slot);

        if (embededBatchId != _batchId) return (0, false);

        if (partialParentHash == _lastVerifiedBlockHash >> 48) {
            return ($.transitions[slot][1].metaHash, true);
        } else {
            return ($.transitionMetaHashes[_batchId][_lastVerifiedBlockHash], false);
        }
    }

    function saveTransition(
        I.State storage $,
        I.Config memory _conf,
        uint48 _batchId,
        bytes32 _parentHash,
        bytes32 _tranMetahash
    )
        internal
        returns (bool isFirstTransition_)
    {
        uint256 slot = _batchId % _conf.batchRingBufferSize;

        // In the next code section, we always use `$.transitions[slot][1]` to reuse a previously
        // declared $ variable -- note that the second mapping key is always 1.
        // Tip: the reuse of the first transition slot can save 3900 gas per batch.
        (uint48 embededBatchId, bytes32 partialParentHash) =
            _loadBatchIdAndPartialParentHash($, slot);

        isFirstTransition_ = embededBatchId != _batchId;

        if (isFirstTransition_) {
            // This is the very first transition of the batch, or a transition with the same parent
            // hash. We can reuse the transition $ slot to reduce gas cost.
            $.transitions[slot][1].batchIdAndPartialParentHash =
                uint256(partialParentHash) & ~type(uint48).max | _batchId;

            // SSTORE
            $.transitions[slot][1].metaHash = _tranMetahash; // 1 SSTORE
        } else if (partialParentHash == _parentHash >> 48) {
            // Overwrite the first proof
            $.transitions[slot][1].metaHash = _tranMetahash; // 1 SSTORE
        } else {
            // This is not the very first transition of the batch, or a transition with the same
            // parent hash. Use a mapping to store the meta hash of the transition. The mapping
            // slots are not reusable.
            $.transitionMetaHashes[_batchId][_parentHash] = _tranMetahash; // 1 SSTORE
        }
    }

    function _loadBatchIdAndPartialParentHash(
        I.State storage $,
        uint256 _slot
    )
        private
        view
        returns (uint48 embededBatchId_, bytes32 partialParentHash_)
    {
        uint256 value = $.transitions[_slot][1].batchIdAndPartialParentHash; // 1 SLOAD
        embededBatchId_ = uint48(value);
        partialParentHash_ = bytes32(value >> 48);
    }
}
