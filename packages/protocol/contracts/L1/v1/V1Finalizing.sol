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
import "../LibData.sol";
import "../TkoToken.sol";
import "./V1Utils.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Finalizing {
    using SafeCastUpgradeable for uint256;
    event BlockFinalized(uint256 indexed id, bytes32 blockHash);

    event HeaderSynced(
        uint256 indexed height,
        uint256 indexed srcHeight,
        bytes32 srcHash
    );

    function init(
        LibData.State storage s,
        bytes32 _genesisBlockHash,
        uint256 _avgFee
    ) public {
        require(_avgFee > 0, "L1:avgFee");

        s.genesisHeight = uint64(block.number);
        s.genesisTimestamp = uint64(block.timestamp);
        s.avgFee = _avgFee;
        s.nextBlockId = 1;
        s.lastProposedAt = uint64(block.timestamp);
        s.l2Hashes[0] = _genesisBlockHash;

        emit BlockFinalized(0, _genesisBlockHash);
        emit HeaderSynced(block.number, 0, _genesisBlockHash);
    }

    function finalizeBlocks(
        LibData.State storage s,
        AddressResolver resolver,
        uint256 maxBlocks
    ) public {
        uint64 latestL2Height = s.latestFinalizedHeight;
        bytes32 latestL2Hash = s.l2Hashes[latestL2Height];
        uint64 processed = 0;
        TkoToken tkoToken;

        for (
            uint256 i = s.latestFinalizedId + 1;
            i < s.nextBlockId && processed <= maxBlocks;
            i++
        ) {
            LibData.ForkChoice storage fc = s.forkChoices[i][latestL2Hash];
            if (fc.blockHash == 0) {
                break;
            } else {
                if (fc.blockHash != LibConstants.TAIKO_BLOCK_DEADEND_HASH) {
                    latestL2Height += 1;
                    latestL2Hash = fc.blockHash;
                }

                (uint256 reward, uint256 premiumReward) = getProofReward(
                    s,
                    fc.provenAt,
                    fc.proposedAt,
                    LibData.getProposedBlock(s, i).gasLimit
                );

                s.avgFee = V1Utils.movingAverage(s.avgFee, reward, 1024);

                s.avgProofTime = V1Utils
                    .movingAverage(
                        s.avgProofTime,
                        fc.provenAt - fc.proposedAt,
                        1024
                    )
                    .toUint64();

                if (address(tkoToken) == address(0)) {
                    tkoToken = TkoToken(resolver.resolve("tko_token"));
                }

                (
                    uint256 proposerBootstrapReward,
                    uint256 proverBootstrapReward
                ) = _calculateBootstrapReward(s);
                // TODO(daniel): reward all provers
                tkoToken.mint(
                    fc.provers[0],
                    premiumReward + proverBootstrapReward
                );
                if (proposerBootstrapReward > 0) {
                    tkoToken.mint(blk.proposer, proposerBootstrapReward);
                }

                emit BlockFinalized(i, fc.blockHash);
            }

            processed += 1;
        }

        if (processed > 0) {
            s.latestFinalizedId += processed;

            if (latestL2Height > s.latestFinalizedHeight) {
                s.latestFinalizedHeight = latestL2Height;
                s.l2Hashes[latestL2Height] = latestL2Hash;
                emit HeaderSynced(block.number, latestL2Height, latestL2Hash);
            }
        }
    }

    function getProofReward(
        LibData.State storage s,
        uint64 provenAt,
        uint64 proposedAt,
        uint64 gasLimit
    ) public view returns (uint256 reward, uint256 premiumReward) {
        uint256 scale = V1Utils.feeScale(
            uint64(block.timestamp),
            provenAt,
            proposedAt
        );

        reward = (s.avgFee * scale) / 10000;

        premiumReward =
            (V1Utils.applyOversellPremium(s, reward, true) *
                (10000 - LibConstants.TAIKO_REWARD_BURN_POINTS)) /
            10000;
    }

    function _calculateBootstrapReward(LibData.State storage s)
        private
        view
        returns (uint256 proposerReward, uint256 proverReward)
    {
        uint256 e = block.timestamp - s.genesisTimestamp;
        uint256 d = LibConstants.TAIKO_REWARD_BOOTSTRAP_DURATION;

        if (e >= d) {
            return (0, 0);
        } else {
            uint256 a = LibConstants.TAIKO_REWARD_BOOTSTRAP_AMOUNT;
            uint256 b = s.avgBlockTime;
            uint256 r = (2 * a * b * (d - e + b / 2)) / d / d;
            return (r / 4, (r * 3) / 4);
        }
    }
}
