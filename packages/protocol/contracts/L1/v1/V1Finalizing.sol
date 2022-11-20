// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "./V1Utils.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Finalizing {
    event BlockVerified(uint256 indexed id, bytes32 blockHash);

    event HeaderSynced(
        uint256 indexed height,
        uint256 indexed srcHeight,
        bytes32 srcHash
    );

    function init(LibData.State storage s, bytes32 _genesisBlockHash) public {
        s.l2Hashes[0] = _genesisBlockHash;
        s.nextBlockId = 1;
        s.genesisHeight = uint64(block.number);

        emit BlockVerified(0, _genesisBlockHash);
        emit HeaderSynced(block.number, 0, _genesisBlockHash);
    }

    function verifyBlocks(
        LibData.State storage s,
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

        uint64 latestL2Height = s.latestFinalizedHeight;
        bytes32 latestL2Hash = s.l2Hashes[latestL2Height];
        uint64 processed = 0;

        for (
            uint256 i = s.latestVerifiedId + 1;
            i < s.nextBlockId && processed <= maxBlocks;
            i++
        ) {
            LibData.ForkChoice storage fc = s.forkChoices[i][latestL2Hash];

            // TODO(daniel): use the average proof-time.
            if (
                block.timestamp <=
                fc.provenAt + LibConstants.K_VERIFICATION_DELAY
            ) {
                // This block is proven but still needs to wait for verificaiton.
                break;
            }

            if (fc.blockHash == LibConstants.TAIKO_BLOCK_DEADEND_HASH) {
                emit BlockVerified(i, 0);
            } else if (fc.blockHash != 0) {
                latestL2Height += 1;
                latestL2Hash = fc.blockHash;
                emit BlockVerified(i, latestL2Hash);
            } else {
                break;
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
}
