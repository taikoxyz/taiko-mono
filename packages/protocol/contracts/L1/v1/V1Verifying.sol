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
        LibData.State storage s,
        bytes32 _genesisBlockHash,
        uint256 _feeBase
    ) public {
        require(_feeBase > 0, "L1:feeBase");

        s.genesisHeight = uint64(block.number);
        s.genesisTimestamp = uint64(block.timestamp);
        s.feeBase = _feeBase;
        s.nextBlockId = 1;
        s.lastProposedAt = uint64(block.timestamp);
        s.l2Hashes[0] = _genesisBlockHash;

        emit BlockVerified(0, _genesisBlockHash);
        emit HeaderSynced(block.number, 0, _genesisBlockHash);
    }

    function verifyBlocks(
        LibData.State storage s,
        AddressResolver resolver,
        uint256 maxBlocks,
        bool checkHalt
    ) public {
        bool halted = V1Utils.isHalted(s);
        if (checkHalt) {
            require(!halted, "L1:halted");
        } else if (halted) {
            // skip finalizing blocks
            return;
        }

        uint64 latestL2Height = s.latestVerifiedHeight;
        bytes32 latestL2Hash = s.l2Hashes[latestL2Height];
        uint64 processed = 0;
        TkoToken tkoToken;

        for (
            uint256 i = s.latestVerifiedId + 1;
            i < s.nextBlockId && processed <= maxBlocks;
            i++
        ) {
            LibData.ForkChoice storage fc = s.forkChoices[i][latestL2Hash];

            // Uncle proof can not take more than 2x time the first proof did.
            if (
                fc.blockHash == 0 ||
                block.timestamp <= V1Utils.uncleProofDeadline(s, fc)
            ) {
                break;
            } else {
                if (fc.blockHash != LibConstants.K_BLOCK_DEADEND_HASH) {
                    latestL2Height += 1;
                    latestL2Hash = fc.blockHash;
                }

                if (LibConstants.K_TOKENOMICS_ENABLED) {
                    (uint256 reward, uint256 premiumReward) = getProofReward({
                        s: s,
                        provenAt: fc.provenAt,
                        proposedAt: fc.proposedAt
                    });

                    s.feeBase = V1Utils.movingAverage({
                        ma: s.feeBase,
                        newValue: reward,
                        maf: LibConstants.K_FEE_BASE_MAF
                    });

                    s.avgProofTime = V1Utils
                        .movingAverage({
                            ma: s.avgProofTime,
                            newValue: fc.provenAt - fc.proposedAt,
                            maf: LibConstants.K_PROOF_TIME_MAF
                        })
                        .toUint64();

                    if (address(tkoToken) == address(0)) {
                        tkoToken = TkoToken(resolver.resolve("tko_token"));
                    }

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
        }

        if (processed > 0) {
            s.latestVerifiedId += processed;

            if (latestL2Height > s.latestVerifiedHeight) {
                s.latestVerifiedHeight = latestL2Height;
                s.l2Hashes[latestL2Height] = latestL2Hash;
                emit HeaderSynced(block.number, latestL2Height, latestL2Hash);
            }
        }
    }

    function getProofReward(
        LibData.State storage s,
        uint64 provenAt,
        uint64 proposedAt
    ) public view returns (uint256 reward, uint256 premiumReward) {
        reward = V1Utils.getTimeAdjustedFee({
            s: s,
            isProposal: false,
            tNow: provenAt,
            tLast: proposedAt,
            tAvg: s.avgProofTime,
            tCap: LibConstants.K_PROOF_TIME_CAP
        });
        premiumReward = V1Utils.getSlotsAdjustedFee({
            s: s,
            isProposal: false,
            fee: reward
        });
        premiumReward =
            (premiumReward * (10000 - LibConstants.K_REWARD_BURN_POINTS)) /
            10000;
    }
}
