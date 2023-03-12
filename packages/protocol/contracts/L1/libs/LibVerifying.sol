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
import {TaikoToken} from "../TaikoToken.sol";
import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

/**
 * LibVerifying.
 */
library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

    event BlockVerified(uint256 indexed id, bytes32 blockHash);
    event HeaderSynced(uint256 indexed srcHeight, bytes32 srcHash);

    error L1_0_FEE_BASE();
    error L1_INVALID_CONFIG();

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 genesisBlockHash,
        uint feeBase
    ) internal {
        if (
            config.chainId <= 1 ||
            config.maxNumBlocks <= 1 ||
            config.blockHashHistory == 0 ||
            config.blockMaxGasLimit == 0 ||
            config.maxTransactionsPerBlock == 0 ||
            config.maxBytesPerTxList == 0 ||
            config.minTxGasLimit == 0 ||
            config.slotSmoothingFactor == 0 ||
            config.rewardBurnBips >= 10000 ||
            config.feeBaseMAF == 0 ||
            config.blockTimeMAF == 0 ||
            config.proofTimeMAF == 0 ||
            config.blockTimeCap == 0 ||
            config.proofTimeCap == 0 ||
            config.feeGracePeriodPctg > config.feeMaxPeriodPctg ||
            config.rewardMultiplierPctg < 100
        ) revert L1_INVALID_CONFIG();

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
        uint256 maxBlocks
    ) public {
        uint64 latestL2Height = state.latestVerifiedHeight;
        bytes32 latestL2Hash = state.l2Hashes[
            latestL2Height % config.blockHashHistory
        ];
        uint64 processed;

        for (
            uint256 i = state.latestVerifiedId + 1;
            i < state.nextBlockId && processed < maxBlocks;

        ) {
            TaikoData.ForkChoice storage fc = state.forkChoices[i][
                latestL2Hash
            ];
            TaikoData.ProposedBlock storage target = state.getProposedBlock(
                config.maxNumBlocks,
                i
            );

            if (fc.prover == address(0)) {
                break;
            } else {
                (latestL2Height, latestL2Hash) = _verifyBlock({
                    state: state,
                    config: config,
                    fc: fc,
                    target: target,
                    latestL2Height: latestL2Height,
                    latestL2Hash: latestL2Hash
                });
                processed += 1;
                emit BlockVerified(i, fc.blockHash);

                // clean up the fork choice
                fc.blockHash = 0;
                fc.prover = address(0);
                fc.provenAt = 0;
            }

            unchecked {
                ++i;
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

    function withdrawBalance(
        TaikoData.State storage state,
        AddressResolver resolver
    ) public {
        uint256 balance = state.balances[msg.sender];
        if (balance <= 1) return;

        state.balances[msg.sender] = 1;
        TaikoToken(resolver.resolve("tko_token", false)).mint(
            msg.sender,
            balance - 1
        );
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
            tAvg: state.avgProofTime,
            tCap: config.proofTimeCap
        });
        reward = LibUtils.getSlotsAdjustedFee({
            state: state,
            config: config,
            isProposal: false,
            feeBase: newFeeBase
        });
        reward = (reward * (10000 - config.rewardBurnBips)) / 10000;
    }

    function _verifyBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
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

                // reward the prover
                if (reward > 0) {
                    if (state.balances[fc.prover] == 0) {
                        // Reduce reward to 1 wei as a penalty if the prover
                        // has 0 TKO outstanding balance.
                        state.balances[fc.prover] = 1;
                    } else {
                        state.balances[fc.prover] += reward;
                    }
                }

                // refund proposer deposit
                uint256 refund = (target.deposit * (10000 - tRelBp)) / 10000;
                if (refund > 0) {
                    if (state.balances[target.proposer] == 0) {
                        // Reduce refund to 1 wei as a penalty if the proposer
                        // has 0 TKO outstanding balance.
                        state.balances[target.proposer] = 1;
                    } else {
                        state.balances[target.proposer] += refund;
                    }
                }
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
}
