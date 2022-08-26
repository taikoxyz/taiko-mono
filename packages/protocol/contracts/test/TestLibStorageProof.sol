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
    function aggregateAncestorHashs(bytes32[256] memory ancestorHashes)
        public
        pure
        returns (bytes32)
    {
        return LibStorageProof.aggregateAncestorHashs(ancestorHashes);
    }

    function computeAnchorProofKV(
        uint256 height,
        bytes32 ancestorAggHash,
        uint256 anchorHeight,
        bytes32 anchorHash
    ) public pure returns (bytes32 key, bytes32 value) {
        return
            LibStorageProof.computeAnchorProofKV(
                height,
                ancestorAggHash,
                anchorHeight,
                anchorHash
            );
    }

    function computeInvalidTxListProofKV(
        uint256 height,
        bytes32 ancestorAggHash,
        bytes32 txListHash
    ) public pure returns (bytes32 key, bytes32 value) {
        return
            LibStorageProof.computeInvalidBlockProofKV(
                height,
                ancestorAggHash,
                txListHash
            );
    }
}
