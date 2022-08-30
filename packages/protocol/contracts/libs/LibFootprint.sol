// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

library LibFootprint {
    function computeAnchorFootprint(
        uint256 height,
        bytes32 parentHash,
        uint256 anchorHeight,
        bytes32 anchorHash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "ANCHOR",
                    height,
                    parentHash,
                    anchorHeight,
                    anchorHash
                )
            );
    }

    function computeBlockInvalidationFootprint(
        uint256 height,
        bytes32 parentHash,
        bytes32 txListHash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "INVALID_BLOCK",
                    height,
                    parentHash,
                    txListHash
                )
            );
    }
}
