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
            if (
                fc.blockHash == 0 ||
                block.timestamp <= V1Utils.uncleProofDeadline(state, fc)
            ) {
                break;
            } else {
                if (fc.blockHash != LibConstants.K_BLOCK_DEADEND_HASH) {
                    latestL2Height += 1;
                    latestL2Hash = fc.blockHash;
                }

                if (LibConstants.K_TOKENOMICS_ENABLED) {
                    (uint256 reward, uint256 premiumReward) = getProofReward({
                        state: state,
                        provenAt: fc.provenAt,
                        proposedAt: target.proposedAt
                    });

                    state.feeBase = V1Utils.movingAverage({
                        maValue: state.feeBase,
                        newValue: reward,
                        maf: LibConstants.K_FEE_BASE_MAF
                    });

                    state.avgProofTime = V1Utils
                        .movingAverage({
                            maValue: state.avgProofTime,
                            newValue: fc.provenAt - target.proposedAt,
                            maf: LibConstants.K_PROOF_TIME_MAF
                        })
                        .toUint64();

                    if (address(tkoToken) == address(0)) {
                        tkoToken = TkoToken(resolver.resolve("tko_token"));
                    }

                    // Return proposer deposit?

                    // Reward multiple provers
                    uint sum = 2 ** fc.provers.length - 1;
                    for (uint k = 0; k < fc.provers.length; k++) {
                        uint weight = (1 << (fc.provers.length - k - 1));
                        uint proverReward = (premiumReward * weight) / sum;

                        if (tkoToken.balanceOf(fc.provers[k]) == 0) {
                            // reduce reward if the prover has 0 TKO balance.
                            proverReward /= 2;
                        }
                        tkoToken.mint(fc.provers[k], proverReward);
                    }
                }

                emit BlockVerified(i, fc.blockHash);
            }

            processed += 1;
            _cleanUp(fc);
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
    ) public view returns (uint256 reward, uint256 premiumReward) {
        reward = V1Utils.getTimeAdjustedFee({
            state: state,
            isProposal: false,
            tNow: provenAt,
            tLast: proposedAt,
            tAvg: state.avgProofTime,
            tCap: LibConstants.K_PROOF_TIME_CAP
        });
        premiumReward = V1Utils.getSlotsAdjustedFee({
            state: state,
            isProposal: false,
            fee: reward
        });
        premiumReward =
            (premiumReward * (10000 - LibConstants.K_REWARD_BURN_POINTS)) /
            10000;
    }

    function _cleanUp(LibData.ForkChoice storage fc) private {
        fc.blockHash = 0;
        fc.provenAt = 0;
        for (uint i = 0; i < fc.provers.length; i++) {
            fc.provers[i] = address(0);
        }
        delete fc.provers;
    }
}
