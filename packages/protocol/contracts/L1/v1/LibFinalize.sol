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

library LibFinalize {
    event BlockFinalized(
        uint256 indexed id,
        uint256 indexed height,
        bytes32 blockHash
    );

    function init(LibData.State storage s, bytes32 _genesisBlockHash) public {
        s.finalizedBlocks[0] = _genesisBlockHash;
        s.nextPendingId = 1;
        s.genesisHeight = uint64(block.number);

        emit BlockFinalized(0, 0, _genesisBlockHash);
    }

    function finalizeBlocks(LibData.State storage s, uint256 maxBlocks) public {
        uint64 id = s.lastFinalizedId + 1;
        uint256 processed = 0;

        while (id < s.nextPendingId && processed <= maxBlocks) {
            bytes32 lastFinalizedHash = s.finalizedBlocks[
                s.lastFinalizedHeight
            ];
            LibData.ForkChoice storage fc = s.forkChoices[id][
                lastFinalizedHash
            ];

            if (fc.blockHash == LibConstants.TAIKO_INVALID_BLOCK_DEADEND_HASH) {
                _finalizeBlock(s, id, fc);
            } else if (fc.blockHash != 0) {
                s.finalizedBlocks[++s.lastFinalizedHeight] = fc.blockHash;
                _finalizeBlock(s, id, fc);
            } else {
                break;
            }

            s.lastFinalizedId += 1;
            id += 1;
            processed += 1;
        }
    }

    function _finalizeBlock(
        LibData.State storage s,
        uint64 id,
        LibData.ForkChoice storage /*fc*/
    ) private {
        emit BlockFinalized(
            id,
            s.lastFinalizedHeight,
            s.finalizedBlocks[s.lastFinalizedHeight]
        );
    }
}
