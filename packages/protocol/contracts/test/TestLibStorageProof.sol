// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../libs/LibStorageProof.sol";

contract TestLibStorageProof {
    function computeAnchorProofKV(
        uint256 height,
        bytes32 parentHash,
        uint256 anchorHeight,
        bytes32 anchorHash
    ) public pure returns (bytes32 key, bytes32 value) {
        return
            LibStorageProof.computeAnchorProofKV(
                height,
                parentHash,
                anchorHeight,
                anchorHash
            );
    }

    function computeInvalidTxListProofKV(
        uint256 height,
        bytes32 parentHash,
        bytes32 txListHash
    ) public pure returns (bytes32 key, bytes32 value) {
        return
            LibStorageProof.computeInvalidBlockProofKV(
                height,
                parentHash,
                txListHash
            );
    }
}
