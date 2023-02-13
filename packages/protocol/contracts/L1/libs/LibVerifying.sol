// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../common/AddressResolver.sol";
import "../TkoToken.sol";
import "./LibUtils.sol";

/**
 * LibVerifying.
 * @author dantaik <dan@taiko.xyz>
 */
library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

    event BlockVerified(uint256 indexed id, bytes32 blockHash);

    event HeaderSynced(
        uint256 indexed height,
        uint256 indexed srcHeight,
        bytes32 srcHash
    );

    function init(
        TaikoData.State storage state,
        bytes32 genesisBlockHash,
        uint256 feeBase
    ) public {
        require(feeBase > 0, "L1:feeBase");

        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = uint64(block.timestamp);
        state.feeBase = feeBase;
        state.nextBlockId = 1;
        state.lastProposedAt = uint64(block.timestamp);
        state.l2Hashes[0] = genesisBlockHash;

        emit BlockVerified(0, genesisBlockHash);
        emit HeaderSynced(block.number, 0, genesisBlockHash);
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
            require(!halted, "L1:halted");
        } else if (halted) {
            // skip finalizing blocks
            return;
        }

        uint64 latestL2Height = state.latestVerifiedHeight;
        bytes32 latestL2Hash = state.l2Hashes[
            latestL2Height % config.blockHashHistory
        ];
        uint64 processed = 0;

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
                emit HeaderSynced(block.number, latestL2Height, latestL2Hash);
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
        uint refund = (target.deposit * (10000 - tRelBp)) / 10000;
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
        uint start;
        uint count = fc.provers.length;

        if (config.enableOracleProver) {
            start = 1;
            count -= 1;
        }

        uint sum = (1 << count) - 1;
        uint weight = 1 << (count - 1);
        for (uint i = 0; i < count; ++i) {
            uint proverReward = (reward * weight) / sum;
            if (proverReward == 0) {
                break;
            }

            if (tkoToken.balanceOf(fc.provers[start + i]) == 0) {
                // Reduce reward to 1 wei as a penalty if the prover
                // has 0 TKO balance. This allows the next prover reward
                // to be fully paid.
                proverReward = uint256(1);
            }
            tkoToken.mint(fc.provers[start + i], proverReward);
            weight = weight >> 1;
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
        for (uint i = 0; i < fc.provers.length; ++i) {
            fc.provers[i] = address(0);
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
