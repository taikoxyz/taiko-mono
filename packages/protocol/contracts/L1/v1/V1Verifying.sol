// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/AddressResolver.sol";
import "../TkoToken.sol";
import "./V1Utils.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Verifying {
    using SafeCastUpgradeable for uint256;
    using V1Utils for LibData.State;

    event BlockVerified(uint256 indexed id, bytes32 blockHash);

    event HeaderSynced(
        uint256 indexed height,
        uint256 indexed srcHeight,
        bytes32 srcHash
    );

    function init(
        LibData.State storage state,
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
        LibData.State storage state,
        LibData.Config memory config,
        AddressResolver resolver,
        uint256 maxBlocks,
        bool checkHalt
    ) public {
        bool halted = V1Utils.isHalted(state);
        if (checkHalt) {
            require(!halted, "L1:halted");
        } else if (halted) {
            // skip finalizing blocks
            return;
        }

        uint64 latestL2Height = state.latestVerifiedHeight;
        bytes32 latestL2Hash = state.l2Hashes[latestL2Height];
        uint64 processed = 0;

        for (
            uint256 i = state.latestVerifiedId + 1;
            i < state.nextBlockId && processed <= maxBlocks;
            i++
        ) {
            LibData.ForkChoice storage fc = state.forkChoices[i][latestL2Hash];
            LibData.ProposedBlock storage target = state.getProposedBlock(
                config.maxNumBlocks,
                i
            );

            // Uncle proof can not take more than 2x time the first proof did.
            if (
                !_isVerifiable({
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

                // Note that not all L2 hashes are stored on L1, only the last
                // verified one in a batch.
                state.l2Hashes[
                    latestL2Height % config.blockHashHistory
                ] = latestL2Hash;
                emit HeaderSynced(block.number, latestL2Height, latestL2Hash);
            }
        }
    }

    function getProofReward(
        LibData.State storage state,
        LibData.Config memory config,
        uint64 provenAt,
        uint64 proposedAt
    ) public view returns (uint256 newFeeBase, uint256 reward, uint256 tRelBp) {
        (newFeeBase, tRelBp) = V1Utils.getTimeAdjustedFee({
            state: state,
            config: config,
            isProposal: false,
            tNow: provenAt,
            tLast: proposedAt,
            tAvg: state.avgProofTime
        });
        reward = V1Utils.getSlotsAdjustedFee({
            state: state,
            config: config,
            isProposal: false,
            feeBase: newFeeBase
        });
        reward = (reward * (10000 - config.rewardBurnBips)) / 10000;
    }

    function _refundProposerDeposit(
        LibData.ProposedBlock storage target,
        uint256 tRelBp,
        TkoToken tkoToken
    ) private {
        uint refund = (target.deposit * (10000 - tRelBp)) / 10000;
        if (refund > 0) {
            tkoToken.mint(target.proposer, refund);
        }
    }

    function _rewardProvers(
        LibData.ForkChoice storage fc,
        uint256 reward,
        TkoToken tkoToken
    ) private {
        uint sum = 2 ** fc.provers.length - 1;
        for (uint i = 0; i < fc.provers.length; i++) {
            uint weight = (1 << (fc.provers.length - i - 1));
            uint proverReward = (reward * weight) / sum;

            if (tkoToken.balanceOf(fc.provers[i]) == 0) {
                // reduce reward if the prover has 0 TKO balance.
                proverReward /= 2;
            }
            tkoToken.mint(fc.provers[i], proverReward);
        }
    }

    function _verifyBlock(
        LibData.State storage state,
        LibData.Config memory config,
        AddressResolver resolver,
        LibData.ForkChoice storage fc,
        LibData.ProposedBlock storage target,
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

                TkoToken tkoToken = TkoToken(resolver.resolve("tko_token"));

                _rewardProvers(fc, reward, tkoToken);
                _refundProposerDeposit(target, tRelBp, tkoToken);
            }
            // Update feeBase and avgProofTime
            state.feeBase = V1Utils.movingAverage({
                maValue: state.feeBase,
                newValue: newFeeBase,
                maf: config.feeBaseMAF
            });
        }

        state.avgProofTime = V1Utils
            .movingAverage({
                maValue: state.avgProofTime,
                newValue: fc.provenAt - target.proposedAt,
                maf: config.proofTimeMAF
            })
            .toUint64();

        if (fc.blockHash != V1Utils.BLOCK_DEADEND_HASH) {
            _latestL2Height = latestL2Height + 1;
            _latestL2Hash = fc.blockHash;
        } else {
            _latestL2Height = latestL2Height;
            _latestL2Hash = latestL2Hash;
        }
    }

    function _cleanUp(LibData.ForkChoice storage fc) private {
        fc.blockHash = 0;
        fc.provenAt = 0;
        for (uint i = 0; i < fc.provers.length; i++) {
            fc.provers[i] = address(0);
        }
        delete fc.provers;
    }

    function _isVerifiable(
        LibData.State storage state,
        LibData.Config memory config,
        LibData.ForkChoice storage fc,
        uint256 blockId
    ) private view returns (bool) {
        return
            fc.blockHash != 0 &&
            block.timestamp >
            V1Utils.uncleProofDeadline({
                state: state,
                config: config,
                fc: fc,
                blockId: blockId
            });
    }
}
