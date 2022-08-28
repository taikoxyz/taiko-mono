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
        bytes32 parentHash,
        uint256 anchorHeight,
        bytes32 anchorHash
    ) internal pure returns (bytes32 key, bytes32 value) {
        key = keccak256(
            abi.encodePacked("STORAGE_PROOF_KEY", height, parentHash)
        );
        value = keccak256(abi.encodePacked(anchorHeight, anchorHash));
    }

    function computeInvalidBlockProofKV(
        uint256 height,
        bytes32 parentHash,
        bytes32 txListHash
    ) internal pure returns (bytes32 key, bytes32 value) {
        key = keccak256(
            abi.encodePacked("STORAGE_PROOF_KEY", height, parentHash)
        );
        value = txListHash;
    }
}
