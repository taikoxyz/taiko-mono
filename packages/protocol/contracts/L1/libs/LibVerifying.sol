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

/**
 * LibVerifying.
 * @author dantaik <dan@taiko.xyz>
 */
library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

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

            // Uncle proof can not take more than 2x time the first proof did.
            if (
                !isVerifiable({
                    state: state,
                    config: config,
                    fc: fc,
                    blockId: i
                })
            ) {
                break;
            } else {
                (latestL2Height, latestL2Hash) = _verifyBlock({
                    state: state,
                    config: config,
                    resolver: resolver,
                    fc: fc,
                    target: target,
                    latestL2Height: latestL2Height,
                    latestL2Hash: latestL2Hash
                });
                processed += 1;
                emit BlockVerified(i, fc.blockHash);
                _cleanUp(fc);
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

    /**
     * A function that calculates the weight for each prover based on the number
     * of provers and a random seed. The weight is a number between 0 and 100.
     * The sum of the weights will be 100. The weight is calculated in bips,
     * so the weight of 1 will be 0.01%.
     *
     * @param config The config of the Taiko protocol (stores the randomized percentage)
     * @param numProvers The number of provers
     * @return bips The weight of each prover in bips
     */
    function getProverRewardBips(
        TaikoData.Config memory config,
        uint256 numProvers
    ) public view returns (uint256[] memory bips) {
        bips = new uint256[](numProvers);

        uint256 randomized = config.proverRewardRandomizedPercentage;
        if (randomized > 100) {
            randomized = 100;
        }

        uint256 sum;
        uint256 i;

        // Calculate the randomized weight
        if (randomized > 0) {
            unchecked {
                uint256 seed = block.prevrandao;
                for (i = 0; i < numProvers; ++i) {
                    // Get an uint16, note that smart provers may
                    // choose the right timing to maximize their rewards
                    // which helps blocks to be verified sooner.
                    bips[i] = uint16(seed * (1 + i));
                    sum += bips[i];
                }
                for (i = 0; i < numProvers; ++i) {
                    bips[i] = (bips[i] * 100 * randomized) / sum;
                }
            }
        }

        // Add the fixed weight. If there are 5 provers, then their
        // weight will be:
        // 1<<4=16, 1<<3=8, 1<<2=4, 1<<1=2, 1<<0=1
        if (randomized != 100) {
            unchecked {
                sum = (1 << numProvers) - 1;
                uint256 fix = 100 - randomized;
                uint256 weight = 1 << (numProvers - 1);
                for (i = 0; i < numProvers; ++i) {
                    bips[i] += (weight * 100 * fix) / sum;
                    weight >>= 1;
                }
            }
        }
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

    function _rewardProvers(
        TaikoData.Config memory config,
        TaikoData.ForkChoice storage fc,
        uint256 reward,
        TkoToken tkoToken
    ) private {
        uint256 offset;
        uint256 count = fc.provers.length;

        if (config.enableOracleProver) {
            offset = 1;
            count -= 1;
        }

        uint256[] memory bips = getProverRewardBips(config, count);

        for (uint256 i; i < count; ++i) {
            uint256 proverReward = (reward * bips[i]) / 10000;
            if (proverReward != 0) {
                if (tkoToken.balanceOf(fc.provers[offset + i].addr) == 0) {
                    // Reduce reward to 1 wei as a penalty if the prover
                    // has 0 TKO balance. This allows the next prover reward
                    // to be fully paid.
                    proverReward = uint256(1);
                }
                tkoToken.mint(fc.provers[offset + i].addr, proverReward);
            }
        }
    }

    function _verifyBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.ForkChoice storage fc,
        TaikoData.ProposedBlock storage target,
        uint64 latestL2Height,
        bytes32 latestL2Hash
    ) private returns (uint64 _latestL2Height, bytes32 _latestL2Hash) {
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

                _rewardProvers(config, fc, reward, tkoToken);
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

        if (fc.blockHash != LibUtils.BLOCK_DEADEND_HASH) {
            _latestL2Height = latestL2Height + 1;
            _latestL2Hash = fc.blockHash;
        } else {
            _latestL2Height = latestL2Height;
            _latestL2Hash = latestL2Hash;
        }
    }

    function _cleanUp(TaikoData.ForkChoice storage fc) private {
        fc.blockHash = 0;
        fc.provenAt = 0;
        for (uint256 i; i < fc.provers.length; ++i) {
            fc.provers[i].addr = address(0);
            fc.provers[i].nonce = 0;
        }
        delete fc.provers;
    }

    function isVerifiable(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.ForkChoice storage fc,
        uint256 blockId
    ) public view returns (bool) {
        return
            // TODO(daniel): remove the next line.
            (!config.enableOracleProver || fc.provers.length > 1) &&
            fc.blockHash != 0 &&
            block.timestamp >
            LibUtils.getUncleProofDeadline({
                state: state,
                config: config,
                fc: fc,
                blockId: blockId
            });
    }
}
