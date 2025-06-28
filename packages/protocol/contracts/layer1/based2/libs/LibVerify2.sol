// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/shared/libs/LibMath.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibBonds2.sol";
import "./LibFork2.sol";
import "./LibData2.sol";
import "./LibPropose2.sol";

/// @title LibVerify2
/// @custom:security-contact security@taiko.xyz
library LibVerify2 {
    using LibMath for uint256;

    error TransitionNotProvided();
    error TransitionMetaMismatch();

    function verifyBatches(
        I.Config memory _conf,
        LibPropose2.Environment memory _env,
        I.Summary memory _summary,
        I.TransitionMeta[] calldata _trans
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            uint48 batchId = _summary.lastVerifiedBatchId + 1;

            if (!LibFork2.isBlocksInCurrentFork(_conf, batchId, batchId)) {
                return _summary;
            }

            uint256 stopBatchId = uint256(_summary.numBatches).min(
                _conf.maxBatchesToVerify + _summary.lastVerifiedBatchId + 1
            );

            uint256 i;
            uint48 lastSyncedBlockId;
            bytes32 lastSyncedStateRoot;
            uint256 nTransitions = _trans.length;

            for (; batchId < stopBatchId; ++batchId) {
                (bytes32 tranMetaHash, bool isFirstTransition) =
                    _env.loadTransitionMetaHash(_conf, _summary.lastVerifiedBlockHash, batchId);

                if (tranMetaHash == 0) break;

                require(i < nTransitions, TransitionNotProvided());
                require(tranMetaHash == keccak256(abi.encode(_trans[i])), TransitionMetaMismatch());

                if (_trans[i].createdAt + _conf.cooldownWindow > _env.blockTimestamp) {
                    break;
                }

                _env.creditBond(
                    _trans[i].prover, _calcBondToProver(_conf, _trans[i], isFirstTransition)
                );

                if (batchId % _conf.stateRootSyncInternal == 0) {
                    lastSyncedBlockId = _trans[i].lastBlockId;
                    lastSyncedStateRoot = _trans[i].stateRoot;
                }

                _summary.lastVerifiedBlockHash = _trans[i++].blockHash;
            }

            if (lastSyncedBlockId != 0) {
                _summary.lastSyncedBlockId = lastSyncedBlockId;
                _summary.lastSyncedAt = uint48(block.timestamp);
                _env.syncChainData(_conf, lastSyncedBlockId, lastSyncedStateRoot);
            }
        }
        return _summary;
    }

    function _calcBondToProver(
        I.Config memory _conf,
        I.TransitionMeta memory _tran,
        bool _isFirstTransition
    )
        private
        pure
        returns (uint96 bondToReturn_)
    {
        unchecked {
            if (_tran.proofTiming == I.ProofTiming.InProvingWindow) {
                // all liveness bond is returned to the prover, this is not a reward.
                bondToReturn_ = _tran.livenessBond;
                if (_isFirstTransition) bondToReturn_ += _tran.provabilityBond;
            } else if (_tran.proofTiming == I.ProofTiming.InExtendedProvingWindow) {
                // prover is rewarded with bondRewardPtcg% of the liveness bond.
                bondToReturn_ = _tran.livenessBond * _conf.bondRewardPtcg / 100;
                if (_isFirstTransition) bondToReturn_ += _tran.provabilityBond;
            } else if (_tran.byAssignedProver) {
                // The assigned prover gets back his liveness bond, and 100% provability
                // bond. This allows him to user a higher gas price to submit his proof first.
                bondToReturn_ = _tran.provabilityBond;
            } else {
                // Other prover get bondRewardPtcg% of the provability bond.
                bondToReturn_ = _tran.provabilityBond * _conf.bondRewardPtcg / 100;
            }
        }
    }
}
