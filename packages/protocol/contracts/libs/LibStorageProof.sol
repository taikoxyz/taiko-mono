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
    function computeAnchorProofKV(
        uint256 height,
        uint256 anchorHeight,
        bytes32 anchorHash
    ) internal pure returns (bytes32 key, bytes32 value) {
        key = keccak256(abi.encodePacked("ANCHOR_KEY", height));
        value = keccak256(abi.encodePacked(anchorHeight, anchorHash));
    }

    function computeInvalidTxListProofKV(bytes32 txListHash)
        internal
        pure
        returns (bytes32 key, bytes32 value)
    {
        key = keccak256(abi.encodePacked("TXLIST_KEY", txListHash));
        value = txListHash;
    }
}
