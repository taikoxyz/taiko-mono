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
    event BlockVerified(uint256 indexed id, bytes32 blockHash);

    event HeaderSynced(
        uint256 indexed height,
        uint256 indexed srcHeight,
        bytes32 srcHash
    );

    function init(
        LibData.State storage state,
        bytes32 _genesisBlockHash,
        uint256 _feeBase
    ) public {
        require(_feeBase > 0, "L1:feeBase");

        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = uint64(block.timestamp);
        state.feeBase = _feeBase;
        state.nextBlockId = 1;
        state.lastProposedAt = uint64(block.timestamp);
        state.l2Hashes[0] = _genesisBlockHash;

        emit BlockVerified(0, _genesisBlockHash);
        emit HeaderSynced(block.number, 0, _genesisBlockHash);
    }

    function verifyBlocks(
        LibData.State storage state,
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
        TkoToken tkoToken;

        for (
            uint256 i = state.latestVerifiedId + 1;
            i < state.nextBlockId && processed <= maxBlocks;
            i++
        ) {
            LibData.ForkChoice storage fc = state.forkChoices[i][latestL2Hash];
            LibData.ProposedBlock storage target = LibData.getProposedBlock(
                state,
                i
            );

            // Uncle proof can not take more than 2x time the first proof did.
            if (!_isVerifiable(state, fc)) {
                break;
            } else {
                if (LibConstants.K_TOKENOMICS_ENABLED) {
                    uint256 newFeeBase;
                    {
                        uint256 reward;
                        uint256 tRelBp; // [0-10000], see the whitepaper
                        (newFeeBase, reward, tRelBp) = getProofReward({
                            state: state,
                            provenAt: fc.provenAt,
                            proposedAt: target.proposedAt
                        });

                        if (address(tkoToken) == address(0)) {
                            tkoToken = TkoToken(resolver.resolve("tko_token"));
                        }

                        _rewardProvers(fc, reward, tkoToken);
                        _refundProposerDeposit(target, tRelBp, tkoToken);
                    }
                    // Update feeBase and avgProofTime
                    state.feeBase = V1Utils.movingAverage({
                        maValue: state.feeBase,
                        newValue: newFeeBase,
                        maf: LibConstants.K_FEE_BASE_MAF
                    });

                    state.avgProofTime = V1Utils
                        .movingAverage({
                            maValue: state.avgProofTime,
                            newValue: fc.provenAt - target.proposedAt,
                            maf: LibConstants.K_PROOF_TIME_MAF
                        })
                        .toUint64();
                }

                if (fc.blockHash != LibConstants.K_BLOCK_DEADEND_HASH) {
                    latestL2Height += 1;
                    latestL2Hash = fc.blockHash;
                }
                processed += 1;
                _cleanUp(fc);
                emit BlockVerified(i, fc.blockHash);
            }
        }

        if (processed > 0) {
            state.latestVerifiedId += processed;

            if (latestL2Height > state.latestVerifiedHeight) {
                state.latestVerifiedHeight = latestL2Height;
                state.l2Hashes[latestL2Height] = latestL2Hash;
                emit HeaderSynced(block.number, latestL2Height, latestL2Hash);
            }
        }
    }

    function getProofReward(
        LibData.State storage state,
        uint64 provenAt,
        uint64 proposedAt
    ) public view returns (uint256 newFeeBase, uint256 reward, uint256 tRelBp) {
        (newFeeBase, tRelBp) = V1Utils.getTimeAdjustedFee({
            state: state,
            isProposal: false,
            tNow: provenAt,
            tLast: proposedAt,
            tAvg: state.avgProofTime,
            tCap: LibConstants.K_PROOF_TIME_CAP
        });
        reward = V1Utils.getSlotsAdjustedFee({
            state: state,
            isProposal: false,
            feeBase: newFeeBase
        });
        reward = (reward * (10000 - LibConstants.K_REWARD_BURN_BP)) / 10000;
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
        LibData.ForkChoice storage fc
    ) private view returns (bool) {
        return
            fc.blockHash != 0 &&
            block.timestamp > V1Utils.uncleProofDeadline(state, fc);
    }
}
