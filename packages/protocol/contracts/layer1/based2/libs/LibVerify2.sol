// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/shared/libs/LibMath.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibBonds2.sol";
import "./LibFork2.sol";
import "./LibData2.sol";

/// @title LibVerify2
/// @custom:security-contact security@taiko.xyz
library LibVerify2 {
    using LibMath for uint256;

    error TransitionNotProvided();
    error TransitionMetaMismatch();

    function verifyBatches(
        I.State storage $,
        LibData2.Env memory _env,
        I.Summary memory _summary,
        I.TransitionMeta[] calldata _trans
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            uint48 batchId = _summary.lastVerifiedBatchId + 1;

            if (!LibFork2.isBlocksInCurrentFork(_env.config, batchId, batchId)) {
                return _summary;
            }
            uint256 stopBatchId = uint256(_summary.numBatches).min(
                _env.config.maxBatchesToVerify + _summary.lastVerifiedBatchId + 1
            );

            uint256 nTransitions = _trans.length;
            uint256 i;
            uint48 lastSyncedBlockId;
            bytes32 lastSyncedStateRoot;

            for (; batchId < stopBatchId; ++batchId) {
                uint256 slot = batchId % _env.config.batchRingBufferSize;

                bytes32 firstTransitionParentHash = $.transitions[slot][1].parentHash; // 1 SLOAD
                if (firstTransitionParentHash == LibData2.FIRST_TRAN_PARENT_HASH_PLACEHOLDER) {
                    // this batch is not proved with at least one transition
                    break;
                }

                bytes32 tranMetaHash = firstTransitionParentHash == _summary.lastVerifiedBlockHash
                    ? $.transitions[slot][1].metaHash
                    : $.transitionMetaHashes[batchId][_summary.lastVerifiedBlockHash];

                if (tranMetaHash == 0) break;

                $.transitions[slot][1].parentHash = LibData2.FIRST_TRAN_PARENT_HASH_PLACEHOLDER;

                require(i < nTransitions, TransitionNotProvided());
                require(tranMetaHash == keccak256(abi.encode(_trans[i])), TransitionMetaMismatch());

                _summary.lastVerifiedBlockHash = _trans[i].blockHash;

                if (batchId % _env.config.stateRootSyncInternal == 0) {
                    lastSyncedBlockId = _trans[i].lastBlockId;
                    lastSyncedStateRoot = _trans[i].stateRoot;
                }

                i++;
            }

            if (lastSyncedBlockId != 0) {
                _summary.lastSyncedBlockId = lastSyncedBlockId;
                _summary.lastSyncedAt = uint48(block.timestamp);

                ISignalService(_env.signalService).syncChainData(
                    _env.config.chainId,
                    LibSignals.STATE_ROOT,
                    lastSyncedBlockId,
                    lastSyncedStateRoot
                );
            }

            return _summary;
        }
    }
}
