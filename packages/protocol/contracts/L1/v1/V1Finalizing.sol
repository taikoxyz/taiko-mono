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

import "../LibData.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Finalizing {
    event BlockFinalized(uint256 indexed id, bytes32 blockHash);

    event HeaderSynced(
        uint256 indexed height,
        uint256 indexed srcHeight,
        bytes32 srcHash
    );

    function init(LibData.State storage s, bytes32 _genesisBlockHash) public {
        s.l2Hashes[0] = _genesisBlockHash;
        s.nextBlockId = 1;
        s.genesisHeight = uint64(block.number);

        emit BlockFinalized(0, _genesisBlockHash);
        emit HeaderSynced(block.number, 0, _genesisBlockHash);
    }

    function finalizeBlocks(LibData.State storage s, uint256 maxBlocks) public {
        uint64 latestL2Height = s.latestFinalizedHeight;
        bytes32 latestL2Hash = s.l2Hashes[latestL2Height];
        uint64 processed = 0;

        for (
            uint256 i = s.latestFinalizedId + 1;
            i < s.nextBlockId && processed <= maxBlocks;
            i++
        ) {
            LibData.ForkChoice storage fc = s.forkChoices[i][latestL2Hash];
            LibData.Auction storage auction = s.auctions[i];

            if (fc.blockHash == LibConstants.TAIKO_BLOCK_DEADEND_HASH) {
                emit BlockFinalized(i, 0);
            } else if (fc.blockHash != 0) {
                latestL2Height += 1;
                latestL2Hash = fc.blockHash;

                if (auction.prover == fc.provers[0]) {
                    // If the block is auctioned, and if the first prover is the
                    // auction winner, we do not reward other provers.
                    // TODO(daniel): reward the first prover only
                } else {
                    for (uint256 j = 0; j < fc.provers.length; j++) {
                        // TODO(daniel): reward each prover
                    }
                }

                emit BlockFinalized(i, latestL2Hash);
            } else {
                break;
            }

            processed += 1;

            // reset storage for refund
            if (LibConstants.V1_RESET_STORAGE_FOR_REFUND) {
                auction.deposit = 0;
                auction.prover = address(0);
                auction.deadline = 0;

                fc.blockHash = 0;
                fc.proposedAt = 0;
                fc.provenAt = 0;
                address[] storage provers = fc.provers;
                for (uint256 j = 0; j <= provers.length; j++) {
                    provers[j] = address(0);
                }
                assembly {
                    sstore(provers.slot, 0)
                }
            }
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
}
