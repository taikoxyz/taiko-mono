// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/shared/libs/LibMath.sol";
import "../ITaikoInbox.sol";

/// @title LibVerification
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
library LibVerification {
    using LibMath for uint256;

    struct SyncBlock {
        uint64 batchId;
        uint64 blockId;
        uint24 tid;
        bytes32 stateRoot;
    }

    function verifyBatches(
        ITaikoInbox.State storage _state,
        ITaikoInbox.Config memory _config,
        ITaikoInbox.Stats2 memory _stats2,
        ISignalService _signalService,
        uint8 _count
    )
        public // reduce code size
    {
        unchecked {
            uint64 batchId = _stats2.lastVerifiedBatchId;

            if (_config.forkHeights.shasta == 0 || batchId >= _config.forkHeights.shasta - 1) {
                uint256 slot = batchId % _config.batchRingBufferSize;
                ITaikoInbox.Batch storage batch = _state.batches[slot];
                uint24 tid = batch.verifiedTransitionId;
                bytes32 blockHash = _state.transitions[slot][tid].blockHash;

                SyncBlock memory synced;

                uint256 stopBatchId = uint256(
                    _config.maxBatchesToVerify * _count + _stats2.lastVerifiedBatchId + 1
                ).min(_stats2.numBatches);

                for (++batchId; batchId < stopBatchId; ++batchId) {
                    slot = batchId % _config.batchRingBufferSize;
                    batch = _state.batches[slot];
                    uint24 nextTransitionId = batch.nextTransitionId;

                    if (_stats2.paused) break;
                    if (nextTransitionId <= 1) break;

                    if (
                        _config.forkHeights.unzen != 0
                            && batch.lastBlockId >= _config.forkHeights.unzen
                    ) break;

                    ITaikoInbox.TransitionState storage ts = _state.transitions[slot][1];
                    if (ts.parentHash == blockHash) {
                        tid = 1;
                    } else if (nextTransitionId > 2) {
                        uint24 _tid = _state.transitionIds[batchId][blockHash];
                        if (_tid == 0) break;
                        tid = _tid;
                        ts = _state.transitions[slot][tid];
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

                    uint96 bondToReturn =
                        ts.inProvingWindow ? batch.livenessBond : batch.livenessBond / 2;
                    creditBond(_state, ts.prover, bondToReturn);

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

                    batch =
                        _state.batches[_stats2.lastVerifiedBatchId % _config.batchRingBufferSize];
                    batch.verifiedTransitionId = tid;
                    emit ITaikoInbox.BatchesVerified(_stats2.lastVerifiedBatchId, blockHash);

                    if (synced.batchId != 0) {
                        if (synced.batchId != _stats2.lastVerifiedBatchId) {
                            // We write the synced batch's verifiedTransitionId to storage
                            batch = _state.batches[synced.batchId % _config.batchRingBufferSize];
                            batch.verifiedTransitionId = synced.tid;
                        }

                        ITaikoInbox.Stats1 memory stats1 = _state.stats1;
                        stats1.lastSyncedBatchId = batch.batchId;
                        stats1.lastSyncedAt = uint64(block.timestamp);
                        _state.stats1 = stats1;

                        emit ITaikoInbox.Stats1Updated(stats1);

                        // Ask signal service to write cross chain signal
                        _signalService.syncChainData(
                            _config.chainId, LibSignals.STATE_ROOT, synced.blockId, synced.stateRoot
                        );
                    }
                }
            }

            _state.stats2 = _stats2;
            emit ITaikoInbox.Stats2Updated(_stats2);
        }
    }

    function getBatchVerifyingTransition(
        ITaikoInbox.State storage _state,
        ITaikoInbox.Config memory _config,
        uint64 _batchId
    )
        public
        view
        returns (ITaikoInbox.TransitionState memory ts_)
    {
        uint64 slot = _batchId % _config.batchRingBufferSize;
        ITaikoInbox.Batch storage batch = _state.batches[slot];
        require(batch.batchId == _batchId, ITaikoInbox.BatchNotFound());

        if (batch.verifiedTransitionId != 0) {
            ts_ = _state.transitions[slot][batch.verifiedTransitionId];
        }
    }

    function creditBond(
        ITaikoInbox.State storage _state,
        address _user,
        uint256 _amount
    )
        internal
    {
        if (_amount == 0) return;
        unchecked {
            _state.bondBalance[_user] += _amount;
        }
        emit IBondManager.BondCredited(_user, _amount);
    }

    function getBatch(
        ITaikoInbox.State storage _state,
        ITaikoInbox.Config memory _config,
        uint64 _batchId
    )
        internal
        view
        returns (ITaikoInbox.Batch storage batch_)
    {
        batch_ = _state.batches[_batchId % _config.batchRingBufferSize];
        require(batch_.batchId == _batchId, ITaikoInbox.BatchNotFound());
    }
}
