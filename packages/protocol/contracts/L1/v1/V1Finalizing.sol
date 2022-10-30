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
        uint256 _baseFee
    ) public {
        require(_baseFee > 0, "L1:baseFee");

        s.l2Hashes[0] = _genesisBlockHash;
        s.nextBlockId = 1;
        s.genesisHeight = uint64(block.number);
        s.baseFee = _baseFee;
        s.lastProposedAt = uint64(block.timestamp);

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

                uint64 proofTime = fc.provenAt - fc.proposedAt;

                (uint256 reward, uint256 premiumReward) = getProofReward(
                    s,
                    proofTime
                );

                s.baseFee = V1Utils.movingAverage(s.baseFee, reward, 1024);

                s.avgProofTime = V1Utils
                    .movingAverage(s.avgProofTime, proofTime, 1024)
                    .toUint64();

                if (address(tkoToken) == address(0)) {
                    tkoToken = TkoToken(resolver.resolve("tko_token"));
                }

                // TODO(daniel): reward all provers
                tkoToken.mint(fc.provers[0], premiumReward);

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

    function getProofReward(LibData.State storage s, uint64 proofTime)
        public
        view
        returns (uint256 reward, uint256 premiumReward)
    {
        uint64 a = (s.avgBlockTime * 125) / 100; // 125%
        uint64 b = (s.avgBlockTime * 400) / 100; // 400%
        uint256 n = s.baseFee * LibConstants.TAIKO_BLOCK_REWARD_MAX_FACTOR;

        if (proofTime <= a) {
            reward = s.baseFee;
        } else if (proofTime >= b) {
            reward = n;
        } else {
            reward = ((n - s.baseFee) * (proofTime - a)) / (b - a) + n;
        }

        premiumReward = V1Utils.applyOversellPremium(s, reward, true);
    }
}
