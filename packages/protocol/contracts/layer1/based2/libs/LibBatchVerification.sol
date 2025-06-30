// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibMath.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibBondManagement.sol";
import "./LibForks.sol";
import "./LibBatchProposal.sol";

/// @title LibBatchVerification
/// @custom:security-contact security@taiko.xyz
library LibBatchVerification {
    using LibMath for uint256;

    function verifyBatches(
        I.Config memory _conf,
        LibReadWrite.RW memory _rw,
        I.Summary memory _summary,
        I.TransitionMeta[] calldata _trans
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            uint48 batchId = _summary.lastVerifiedBatchId + 1;

            if (!LibForks.isBlocksInCurrentFork(_conf, batchId, batchId)) {
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
                    _rw.loadTransitionMetaHash(_conf, _summary.lastVerifiedBlockHash, batchId);

                if (tranMetaHash == 0) break;

                require(i < nTransitions, TransitionNotProvided());
                require(tranMetaHash == keccak256(abi.encode(_trans[i])), TransitionMetaMismatch());

                if (_trans[i].createdAt + _conf.cooldownWindow > block.timestamp) {
                    break;
                }

                uint96 bondToProver = _calcBondToProver(_conf, _trans[i], isFirstTransition);
                _rw.creditBond(_trans[i].prover, bondToProver);

                if (batchId % _conf.stateRootSyncInternal == 0) {
                    lastSyncedBlockId = _trans[i].lastBlockId;
                    lastSyncedStateRoot = _trans[i].stateRoot;
                }

                emit I.BatchesVerified(batchId, _trans[i].blockHash);
                _summary.lastVerifiedBlockHash = _trans[i++].blockHash;
            }

            if (lastSyncedBlockId != 0) {
                _summary.lastSyncedBlockId = lastSyncedBlockId;
                _summary.lastSyncedAt = uint48(block.timestamp);
                _rw.syncChainData(_conf, lastSyncedBlockId, lastSyncedStateRoot);
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
        returns (uint96)
    {
        unchecked {
            if (_tran.proofTiming == I.ProofTiming.InProvingWindow) {
                // all liveness bond is returned to the prover, this is not a reward.
                return _isFirstTransition
                    ? _tran.livenessBond + _tran.provabilityBond
                    : _tran.livenessBond;
            }

            if (_tran.proofTiming == I.ProofTiming.InExtendedProvingWindow) {
                // prover is rewarded with bondRewardPtcg% of the liveness bond.
                uint96 amount = _tran.livenessBond * _conf.bondRewardPtcg / 100;
                return _isFirstTransition ? amount + _tran.provabilityBond : amount;
            }

            if (_tran.byAssignedProver) {
                // The assigned prover gets back his liveness bond, and 100% provability
                // bond. This allows him to user a higher gas price to submit his proof first.
                return _tran.provabilityBond;
            }

            // Other prover get bondRewardPtcg% of the provability bond.
            return _tran.provabilityBond * _conf.bondRewardPtcg / 100;
        }
    }

    // --- ERRORs --------------------------------------------------------------------------------
    error TransitionNotProvided();
    error TransitionMetaMismatch();
}
