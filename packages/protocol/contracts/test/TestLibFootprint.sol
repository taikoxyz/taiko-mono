// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../libs/LibFootprint.sol";

contract TestLibFootprint {
    function computeAnchorFootprint(
        uint256 height,
        bytes32 parentHash,
        uint256 anchorHeight,
        bytes32 anchorHash
    ) public pure returns (bytes32) {
        return
            LibFootprint.computeAnchorFootprint(
                height,
                parentHash,
                anchorHeight,
                anchorHash
            );
    }

    function computeBlockInvalidationFootprint(
        uint256 height,
        bytes32 parentHash,
        bytes32 txListHash
    ) public pure returns (bytes32) {
        return
            LibFootprint.computeBlockInvalidationFootprint(
                height,
                parentHash,
                txListHash
            );
    }
}
