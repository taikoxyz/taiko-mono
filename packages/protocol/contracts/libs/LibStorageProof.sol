// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

library LibStorageProof {
    function aggregateAncestorHashs(bytes32[256] memory ancestorHashes)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(ancestorHashes));
    }

    function computeAnchorProofKV(
        uint256 height,
        uint256 anchorHeight,
        bytes32 anchorHash,
        bytes32 ancestorAggregatedHash
    ) internal pure returns (bytes32 key, bytes32 value) {
        key = keccak256(abi.encodePacked("ANCHOR_KEY", height));
        value = keccak256(
            abi.encodePacked(anchorHeight, anchorHash, ancestorAggregatedHash)
        );
    }

    function computeInvalidTxListProofKV(
        bytes32 txListHash,
        bytes32 ancestorAggregatedHash
    ) internal pure returns (bytes32 key, bytes32 value) {
        key = keccak256(abi.encodePacked("TXLIST_KEY", txListHash));
        value = keccak256(abi.encodePacked(txListHash, ancestorAggregatedHash));
    }
}
