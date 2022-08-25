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
        uint256 anchorHeight,
        bytes32 anchorHash,
        bytes32 ancestorAggHash
    ) public pure returns (bytes32 key, bytes32 value) {
        return
            LibStorageProof.computeAnchorProofKV(
                height,
                anchorHeight,
                anchorHash,
                ancestorAggHash
            );
    }

    function computeInvalidTxListProofKV(
        bytes32 txListHash,
        bytes32 ancestorAggHash
    ) public pure returns (bytes32 key, bytes32 value) {
        return
            LibStorageProof.computeInvalidTxListProofKV(
                txListHash,
                ancestorAggHash
            );
    }
}
