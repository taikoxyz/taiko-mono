// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../../common/AddressResolver.sol";
import "../LibData.sol";
import "../TkoToken.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Finalizing {
    event BlockFinalized(uint256 indexed id, bytes32 blockHash, uint256 reward);

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

        emit BlockFinalized(0, _genesisBlockHash, 0);
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
                uint256 reward = getProofReward(s, proofTime);

                if (address(tkoToken) == address(0)) {
                    tkoToken = TkoToken(resolver.resolve("tko_token"));
                }

                // TODO(daniel): reward all provers
                tkoToken.mint(fc.provers[0], reward);

                _updateAvgProofTime(s, proofTime);
                emit BlockFinalized(i, fc.blockHash, reward);
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
        returns (uint256)
    {
        uint64 a = (s.avgBlockTime * 150) / 100; // 150%
        if (proofTime <= a) return s.baseFee;

        uint64 b = (s.avgBlockTime * 300) / 100; // 300%
        uint256 n = (s.baseFee * 400) / 100; // 400%
        if (proofTime >= b) return n;

        return ((n - s.baseFee) * (proofTime - a)) / (b - a) + n;
    }

    function _updateAvgProofTime(LibData.State storage s, uint64 proofTime)
        private
    {
        if (s.avgProofTime == 0) {
            s.avgProofTime = proofTime;
        } else {
            s.avgProofTime = (1023 * s.avgProofTime + proofTime) / 1024;
        }
    }
}
