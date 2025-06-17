// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/shared/libs/LibMath.sol";
import { ITaikoInbox as I } from "../ITaikoInbox.sol";
import "./LibBonds.sol";

/// @title LibVerify
/// @custom:security-contact security@taiko.xyz
library LibVerify {
    using LibMath for uint256;

    struct SyncBlock {
        uint64 batchId;
        uint64 blockId;
        uint24 tid;
        bytes32 stateRoot;
    }

    function verifyBatches(
        I.State storage $,
        I.Config memory _config,
        I.Stats2 memory _stats2,
        ISignalService _signalService,
        uint8 _count
    )
        public // reduce code size
    {
        unchecked {
            uint64 batchId = _stats2.lastVerifiedBatchId;

            if (_config.forkHeights.shasta == 0 || batchId >= _config.forkHeights.shasta - 1) {
                uint256 slot = batchId % _config.batchRingBufferSize;
                I.Batch storage batch = $.batches[slot];
                uint24 tid = batch.verifiedTransitionId;
                bytes32 blockHash = $.transitions[slot][tid].blockHash;

                SyncBlock memory synced;

                uint256 stopBatchId = uint256(
                    _config.maxBatchesToVerify * _count + _stats2.lastVerifiedBatchId + 1
                ).min(_stats2.numBatches);

                for (++batchId; batchId < stopBatchId; ++batchId) {
                    slot = batchId % _config.batchRingBufferSize;
                    batch = $.batches[slot];
                    uint24 nextTransitionId = batch.nextTransitionId;

                    if (_stats2.paused) break;
                    if (nextTransitionId <= 1) break;

                    if (
                        _config.forkHeights.unzen != 0
                            && batch.lastBlockId >= _config.forkHeights.unzen
                    ) break;

                    I.TransitionState storage ts = $.transitions[slot][1];
                    if (ts.parentHash == blockHash) {
                        tid = 1;
                    } else if (nextTransitionId > 2) {
                        uint24 _tid = $.transitionIds[batchId][blockHash];
                        if (_tid == 0) break;
                        tid = _tid;
                        ts = $.transitions[slot][tid];
                    } else {
                        break;
                    }

                    {
                        bytes32 _blockHash = ts.blockHash;
                        // This transition has been invalidated due to conflicting proof
                        if (_blockHash == 0) break;

                        if (ts.createdAt + _config.cooldownWindow > block.timestamp) {
                            break;
                        }
                        blockHash = _blockHash;
                    }

                    {
                        uint96 bondToReturn;
                        if (ts.proofTiming == I.ProofTiming.InProvingWindow) {
                            // all liveness bond is returned to the prover, this is not a reward.
                            bondToReturn = batch.livenessBond;
                            if (tid == 1) bondToReturn += batch.provabilityBond;
                        } else if (
                            ts.proofTiming == I.ProofTiming.InExtendedProvingWindow
                        ) {
                            // prover is rewarded with bondRewardPtcg% of the liveness bond.
                            bondToReturn = batch.livenessBond * _config.bondRewardPtcg / 100;
                            if (tid == 1) bondToReturn += batch.provabilityBond;
                        } else if (ts.byAssignedProver) {
                            // The assigned prover gets back his liveness bond, and 100% provability
                            // bond.
                            // This allows him to user a higher gas price to submit his proof first.
                            bondToReturn = batch.provabilityBond;
                        } else {
                            // Other prover get bondRewardPtcg% of the provability bond.
                            bondToReturn = batch.provabilityBond * _config.bondRewardPtcg / 100;
                        }

                        LibBonds.creditBond($, ts.prover, bondToReturn);
                    }

                    if (batchId % _config.stateRootSyncInternal == 0) {
                        synced.batchId = batchId;
                        synced.blockId = batch.lastBlockId;
                        synced.tid = tid;
                        synced.stateRoot = ts.stateRoot;
                    }
                }

                --batchId;

                if (_stats2.lastVerifiedBatchId != batchId) {
                    _stats2.lastVerifiedBatchId = batchId;

                    batch = $.batches[_stats2.lastVerifiedBatchId % _config.batchRingBufferSize];
                    batch.verifiedTransitionId = tid;
                    emit I.BatchesVerified(_stats2.lastVerifiedBatchId, blockHash);

                    if (synced.batchId != 0) {
                        if (synced.batchId != _stats2.lastVerifiedBatchId) {
                            // We write the synced batch's verifiedTransitionId to storage
                            batch = $.batches[synced.batchId % _config.batchRingBufferSize];
                            batch.verifiedTransitionId = synced.tid;
                        }

                        I.Stats1 memory stats1 = $.stats1;
                        stats1.lastSyncedBatchId = batch.batchId;
                        stats1.lastSyncedAt = uint64(block.timestamp);
                        $.stats1 = stats1;

                        emit I.Stats1Updated(stats1);

                        // Ask signal service to write cross chain signal
                        _signalService.syncChainData(
                            _config.chainId, LibSignals.STATE_ROOT, synced.blockId, synced.stateRoot
                        );
                    }
                }
            }

            $.stats2 = _stats2;
            emit I.Stats2Updated(_stats2);
        }
    }
}
