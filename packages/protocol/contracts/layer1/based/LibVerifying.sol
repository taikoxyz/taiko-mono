// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITaikoInbox.sol";
import "./LibBonds.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/signal/ISignalService.sol";
import "src/layer1/surge/verifiers/ISurgeVerifier.sol";
import "src/layer1/surge/verifiers/LibProofType.sol";

/// @title LibVerifying
/// @notice This library is used to verify batches
/// @dev This library's verify function is made public to reduce TaikoInbox's code size.
/// @custom:security-contact security@nethermind.io
library LibVerifying {
    using LibMath for uint256;
    using LibProofType for LibProofType.ProofType;

    // Surge: Use local state struct to avoid stack too deep
    struct LocalState {
        uint64 batchId;
        bytes32 blockHash;
        uint24 tid;
        uint256 fti; // Surge: finalising transition index
        bool canVerifyBlocks;
        uint256 stopBatchId;
        uint256 slot;
        uint256 nextTransitionId;
    }

    function verifyBatches(
        ITaikoInbox.State storage _state,
        ITaikoInbox.Config memory _config,
        ITaikoInbox.Stats2 memory _stats2,
        uint256 _length,
        address _dao,
        address _verifier,
        ISignalService _signalService
    )
        public
    {
        LocalState memory ls;

        ls.batchId = _stats2.lastVerifiedBatchId;

        unchecked {
            uint64 pacayaForkHeight = _config.forkHeights.pacaya;
            ls.canVerifyBlocks = pacayaForkHeight == 0 || ls.batchId >= pacayaForkHeight - 1;
        }

        if (ls.canVerifyBlocks) {
            ls.slot = ls.batchId % _config.batchRingBufferSize;
            ITaikoInbox.Batch storage batch = _state.batches[ls.slot];
            ls.tid = batch.verifiedTransitionId;
            // Surge: get the block hash of the finalising transition
            ls.blockHash =
                _state.transitions[ls.slot][ls.tid][batch.finalisingTransitionIndex].blockHash;

            // Surge: If the verification streak has been broken, we reset the streak timestamp
            // `batch` points to the last verified batch, so we can use it to check if the streak
            // has been broken.
            if (block.timestamp - batch.lastBlockTimestamp > _config.maxVerificationDelay) {
                _state.stats1.verificationStreakStartedAt = uint64(block.timestamp);
            }

            SyncBlock memory synced;

            unchecked {
                ls.stopBatchId = (
                    _config.maxBatchesToVerify * _length + _stats2.lastVerifiedBatchId + 1
                ).min(_stats2.numBatches);

                if (_config.forkHeights.shasta != 0) {
                    ls.stopBatchId = ls.stopBatchId.min(_config.forkHeights.shasta);
                }
            }

            for (++ls.batchId; ls.batchId < ls.stopBatchId; ++ls.batchId) {
                ls.slot = ls.batchId % _config.batchRingBufferSize;
                batch = _state.batches[ls.slot];

                // Surge: remove redundant pause check

                ITaikoInbox.TransitionState[] storage transitions;

                // Surge: avoid stack too deep errors

                ls.nextTransitionId = batch.nextTransitionId;
                if (ls.nextTransitionId <= 1) break;

                transitions = _state.transitions[ls.slot][1];
                if (transitions[0].parentHash == ls.blockHash) {
                    ls.tid = 1;
                } else if (ls.nextTransitionId > 2) {
                    uint24 _tid = _state.transitionIds[ls.batchId][ls.blockHash];
                    if (_tid == 0) break;
                    ls.tid = _tid;
                    transitions = _state.transitions[ls.slot][ls.tid];
                } else {
                    break;
                }

                // Surge: remove conflicting transition and cooldown window checks

                // Surge: Handle verification based on proof types and conflicts
                uint256 _fti = _tryFinalising(
                    _state, transitions, _config, batch.livenessBond, _dao, _verifier
                );

                // Surge: Do not verify the batch if no finalising transition is found
                if (_fti == type(uint256).max) {
                    break;
                }

                ls.fti = _fti;

                // Surge: use the finalising transition index to update the local blockhash
                ls.blockHash = transitions[ls.fti].blockHash;

                if (ls.batchId % _config.stateRootSyncInternal == 0) {
                    synced.batchId = ls.batchId;
                    synced.blockId = batch.lastBlockId;
                    synced.tid = ls.tid;
                    synced.fti = ls.fti;
                    synced.stateRoot = transitions[ls.fti].stateRoot;
                }
            }

            unchecked {
                --ls.batchId;
            }

            if (_stats2.lastVerifiedBatchId != ls.batchId) {
                _stats2.lastVerifiedBatchId = ls.batchId;

                batch = _state.batches[_stats2.lastVerifiedBatchId % _config.batchRingBufferSize];
                batch.verifiedTransitionId = ls.tid;
                // Surge: update the finalising transition index for the batch
                batch.finalisingTransitionIndex = uint8(ls.fti);

                emit ITaikoInbox.BatchesVerified(_stats2.lastVerifiedBatchId, ls.blockHash);

                if (synced.batchId != 0) {
                    if (synced.batchId != _stats2.lastVerifiedBatchId) {
                        // We write the synced batch's verifiedTransitionId to storage
                        batch = _state.batches[synced.batchId % _config.batchRingBufferSize];
                        batch.verifiedTransitionId = synced.tid;
                        batch.finalisingTransitionIndex = uint8(synced.fti);
                    }

                    ITaikoInbox.Stats1 memory stats1 = _state.stats1;
                    stats1.lastSyncedBatchId = batch.batchId;
                    stats1.lastSyncedAt = uint64(block.timestamp);
                    _state.stats1 = stats1;

                    emit ITaikoInbox.Stats1Updated(stats1);

                    // Ask signal service to write cross chain signal
                    _signalService.syncChainData(
                        _config.chainId, LibStrings.H_STATE_ROOT, synced.blockId, synced.stateRoot
                    );
                }
            }
        }

        _state.stats2 = _stats2;
        emit ITaikoInbox.Stats2Updated(_stats2);
    }

    // Surge: core finality gadget logic
    function _tryFinalising(
        ITaikoInbox.State storage _state,
        ITaikoInbox.TransitionState[] storage _transitions,
        ITaikoInbox.Config memory _config,
        uint256 _livenessBond,
        address _dao,
        address _verifier
    )
        internal
        returns (uint256)
    {
        // `fti` is used to store the finalising transition index
        uint256 fti = type(uint256).max;

        uint256 numTransitions = _transitions.length;

        // If there are no conflicting transitions
        if (numTransitions == 1) {
            // If the first transition is just ZK or TEE proven
            if (!_transitions[0].proofType.isZkTeeProof()) {
                // If the cooldown window has not expired, we cannot finalise the transition
                if (_transitions[0].createdAt + _config.cooldownWindow > block.timestamp) {
                    return fti;
                }
            }

            // The first transition itself is the finalising transition
            fti = 0;
        } else {
            // Proof type(s) to upgrade
            LibProofType.ProofType ptToUpgrade;

            // Try to find a finalising proof
            for (uint256 i; i < numTransitions; ++i) {
                if (_transitions[i].proofType.isZkTeeProof()) {
                    fti = i;
                } else {
                    ptToUpgrade = ptToUpgrade.combine(_transitions[i].proofType);
                }
            }

            // If no finalising transition is found, we return
            if (fti == type(uint256).max) {
                return fti;
            } else {
                // Mark non finalising verifiers for upgrade
                ISurgeVerifier(_verifier).markUpgradeable(ptToUpgrade);
            }
        }

        address bondReceiver = _transitions[fti].bondReceiver;
        if (bondReceiver == address(0)) {
            // This is only possible if the batch is finalised via the cooldown window, so
            // we set the bond receiver to the DAO
            bondReceiver = _dao;
        }

        LibBonds.creditBond(_state, bondReceiver, _livenessBond);

        return fti;
    }

    // Memory-only structs ----------------------------------------------------------------------

    struct SyncBlock {
        uint64 batchId;
        uint64 blockId;
        uint24 tid;
        uint256 fti;
        bytes32 stateRoot;
    }
}
