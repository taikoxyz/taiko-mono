// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import {AddressResolver} from "../../common/AddressResolver.sol";
import {TkoToken} from "../TkoToken.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";
import {LibAddress} from "../../libs/LibAddress.sol";

/**
 * LibVerifying.
 */
library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;
    using LibAddress for address;

    event BlockVerified(uint256 indexed id, bytes32 blockHash);

    event HeaderSynced(uint256 indexed srcHeight, bytes32 srcHash);

    error L1_HALTED();
    error L1_0_FEE_BASE();

    function init(
        TaikoData.State storage state,
        bytes32 genesisBlockHash,
        uint256 feeBase
    ) public {
        if (feeBase == 0) revert L1_0_FEE_BASE();

        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = uint64(block.timestamp);
        state.feeBase = feeBase;
        state.nextBlockId = 1;
        state.lastProposedAt = uint64(block.timestamp);
        state.l2Hashes[0] = genesisBlockHash;

        emit BlockVerified(0, genesisBlockHash);
        emit HeaderSynced(0, genesisBlockHash);
    }

    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 maxBlocks,
        bool checkHalt
    ) public {
        bool halted = LibUtils.isHalted(state);
        if (checkHalt) {
            if (halted) revert L1_HALTED();
        } else if (halted) {
            // skip finalizing blocks
            return;
        }

        uint64 latestL2Height = state.latestVerifiedHeight;
        bytes32 latestL2Hash = state.l2Hashes[
            latestL2Height % config.blockHashHistory
        ];
        uint64 processed;

        for (
            uint256 i = state.latestVerifiedId + 1;
            i < state.nextBlockId && processed < maxBlocks;
            i++
        ) {
            TaikoData.ForkChoice storage fc = state.forkChoices[i][
                latestL2Hash
            ];
            TaikoData.ProposedBlock storage target = state.getProposedBlock(
                config.maxNumBlocks,
                i
            );

            if (!isVerifiable({config: config, fc: fc})) {
                break;
            } else {
                _verifyBlock({
                    state: state,
                    config: config,
                    resolver: resolver,
                    fc: fc,
                    target: target,
                    blockId: i
                });
                if (fc.blockHash != LibUtils.BLOCK_DEADEND_HASH) {
                    latestL2Height = latestL2Height + 1;
                    latestL2Hash = fc.blockHash;
                } else {
                    latestL2Height = latestL2Height;
                    latestL2Hash = latestL2Hash;
                }
                processed += 1;
                emit BlockVerified(i, fc.blockHash);
                _cleanUp(fc, state.claims[i]);
            }
        }

        if (processed > 0) {
            state.latestVerifiedId += processed;

            if (latestL2Height > state.latestVerifiedHeight) {
                state.latestVerifiedHeight = latestL2Height;

                // Note: Not all L2 hashes are stored on L1, only the last
                // verified one in a batch. This is sufficient because the last
                // verified hash is the only one needed checking the existence
                // of a cross-chain message with a merkle proof.
                state.l2Hashes[
                    latestL2Height % config.blockHashHistory
                ] = latestL2Hash;
                emit HeaderSynced(latestL2Height, latestL2Hash);
            }
        }
    }

    function getProofReward(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 provenAt,
        uint64 proposedAt
    ) public view returns (uint256 newFeeBase, uint256 reward, uint256 tRelBp) {
        (newFeeBase, tRelBp) = LibUtils.getTimeAdjustedFee({
            state: state,
            config: config,
            isProposal: false,
            tNow: provenAt,
            tLast: proposedAt,
            tAvg: state.avgProofTime
        });
        reward = LibUtils.getSlotsAdjustedFee({
            state: state,
            config: config,
            isProposal: false,
            feeBase: newFeeBase
        });
        reward = (reward * (10000 - config.rewardBurnBips)) / 10000;
    }

    function _refundProposerDeposit(
        TaikoData.ProposedBlock storage target,
        uint256 tRelBp,
        TkoToken tkoToken
    ) private {
        uint256 refund = (target.deposit * (10000 - tRelBp)) / 10000;
        if (refund > 0 && tkoToken.balanceOf(target.proposer) > 0) {
            // Do not refund proposer with 0 TKO balance.
            tkoToken.mint(target.proposer, refund);
        }
    }

    function _refundClaimerDeposit(address claimer, uint256 deposit) private {
        claimer.sendEther(deposit);
    }

    function _rewardProver(
        address prover,
        uint256 reward,
        TkoToken tkoToken,
        TaikoData.State storage state,
        uint256 blockId
    ) private {
        if (tkoToken.balanceOf(prover) == 0) {
            // Reduce reward to 1 wei as a penalty if the prover
            // has 0 TKO balance. This allows the next prover reward
            // to be fully paid.
            reward = uint256(1);
        }

        tkoToken.mint(prover, reward);

        TaikoData.Claim storage claim = state.claims[blockId];

        if (prover != claim.claimer) {
            prover.sendEther(claim.deposit);
        } else {
            _refundClaimerDeposit(prover, claim.deposit);
        }
        state.timesProofNotDeliveredForClaim[claim.claimer] += 1;
    }

    function _verifyBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.ForkChoice storage fc,
        TaikoData.ProposedBlock storage target,
        uint256 blockId
    ) private {
        if (config.enableTokenomics) {
            uint256 newFeeBase;
            {
                uint256 reward;
                uint256 tRelBp; // [0-10000], see the whitepaper
                (newFeeBase, reward, tRelBp) = getProofReward({
                    state: state,
                    config: config,
                    provenAt: fc.provenAt,
                    proposedAt: target.proposedAt
                });

                TkoToken tkoToken = TkoToken(
                    resolver.resolve("tko_token", false)
                );

                _rewardProver(fc.prover, reward, tkoToken, state, blockId);
                _refundProposerDeposit(target, tRelBp, tkoToken);
            }
            // Update feeBase and avgProofTime
            state.feeBase = LibUtils.movingAverage({
                maValue: state.feeBase,
                newValue: newFeeBase,
                maf: config.feeBaseMAF
            });
        }

        state.avgProofTime = LibUtils
            .movingAverage({
                maValue: state.avgProofTime,
                newValue: fc.provenAt - target.proposedAt,
                maf: config.proofTimeMAF
            })
            .toUint64();
    }

    function _cleanUp(
        TaikoData.ForkChoice storage fc,
        TaikoData.Claim storage claim
    ) private {
        fc.blockHash = 0;
        fc.provenAt = 0;
        fc.prover = address(0);
        claim.deposit = 0;
        claim.claimedAt = 0;
        claim.claimer = address(0);
    }

    function isVerifiable(
        TaikoData.Config memory config,
        TaikoData.ForkChoice storage fc
    ) public view returns (bool) {
        return
            // TODO(daniel): remove the next line.
            (!config.enableOracleProver || fc.prover != address(0)) &&
            fc.blockHash != 0;
    }
}
