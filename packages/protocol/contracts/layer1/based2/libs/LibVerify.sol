// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibMath.sol";
import { IInbox as I } from "../IInbox.sol";
import "./LibForks.sol";
import "./LibState.sol";
import "./LibData.sol";

/// @title LibVerify
/// @notice Library for batch verification and bond distribution in Taiko protocol
/// @dev Handles the final verification stage of batch processing including:
///      - Sequential batch verification with transition metadata validation
///      - Cooldown period enforcement before verification
///      - Bond distribution to provers based on timing and conditions
///      - Periodic state root synchronization with L2
///      - Fork boundary checks for verification eligibility
/// @custom:security-contact security@taiko.xyz
library LibVerify {
    using LibMath for uint256;
    using LibData for uint16;

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Verifies multiple batches and updates the protocol summary
    /// @dev Processes batches sequentially, validating transition metadata,
    ///      enforcing cooldown periods, and distributing bonds to provers.
    ///      Also handles periodic state root synchronization.
    /// @param _conf Protocol configuration parameters
    /// @param _rw Read/write access functions for blockchain state
    /// @param _summary Current protocol summary state
    /// @param _trans Array of transition metadata for verification
    /// @return Updated summary with verification results
    function verify(
        I.Config memory _conf,
        LibState.ReadWrite memory _rw,
        I.Summary memory _summary,
        I.TransitionMeta[] memory _trans
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
            uint256 lastSyncedBatchId;
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

                uint16 bondToProver = _calcBondToProver(_conf, _trans[i], isFirstTransition);
                _rw.creditBond(
                    _trans[i].prover, bondToProver.bondToWei(_conf.bondConfig.bondDecimals)
                );

                if (batchId % _conf.stateRootSyncInternal == 0) {
                    lastSyncedBatchId = batchId;
                }

                emit I.Verified(batchId << 48 | _trans[i].lastBlockId, _trans[i].blockHash);
                _summary.lastVerifiedBlockHash = _trans[i++].blockHash;
            }

            if (lastSyncedBatchId != 0) {
                _summary.lastSyncedAt = uint48(block.timestamp);
                _summary.lastSyncedBlockId = _trans[lastSyncedBatchId].lastBlockId;
                _rw.syncChainData(
                    _conf, _summary.lastSyncedBlockId, _trans[lastSyncedBatchId].stateRoot
                );
            }
        }
        return _summary;
    }

    // -------------------------------------------------------------------------
    // Private Functions - Bond Calculation
    // -------------------------------------------------------------------------

    /// @notice Calculates the bond amount to return to the prover based on timing and conditions
    /// @dev Bond distribution logic:
    ///      - InProvingWindow: Full bonds returned (liveness + provability for first transition)
    ///      - InExtendedProvingWindow: Partial reward based on bondRewardPtcg
    ///      - Assigned prover: Gets back provability bond
    ///      - Other provers: Get percentage of provability bond
    /// @param _conf Protocol configuration containing bond parameters
    /// @param _tran Transition metadata containing bond and timing information
    /// @param _isFirstTransition Whether this is the first transition for the batch
    /// @return Bond amount to credit to the prover
    function _calcBondToProver(
        I.Config memory _conf,
        I.TransitionMeta memory _tran,
        bool _isFirstTransition
    )
        private
        pure
        returns (uint16)
    {
        unchecked {
            if (_tran.proofTiming == I.ProofTiming.InProvingWindow) {
                // All liveness bond is returned to the prover, this is not a reward
                return _isFirstTransition
                    ? _tran.bondConfig.livenessBond + _tran.bondConfig.provabilityBond
                    : _tran.bondConfig.livenessBond;
            }

            if (_tran.proofTiming == I.ProofTiming.InExtendedProvingWindow) {
                // Prover is rewarded with bondRewardPtcg% of the liveness bond
                uint16 amount = (_tran.bondConfig.livenessBond * _conf.bondRewardPtcg) / 100;
                return _isFirstTransition ? amount + _tran.bondConfig.provabilityBond : amount;
            }

            if (_tran.byAssignedProver) {
                // The assigned prover gets back his liveness bond, and 100% provability
                // bond. This allows him to use a higher gas price to submit his proof first
                return _tran.bondConfig.provabilityBond;
            }

            // Other provers get bondRewardPtcg% of the provability bond
            return (_tran.bondConfig.provabilityBond * _conf.bondRewardPtcg) / 100;
        }
    }

    // -------------------------------------------------------------------------
    // Custom Errors
    // -------------------------------------------------------------------------

    error TransitionMetaMismatch();
    error TransitionNotProvided();
}
