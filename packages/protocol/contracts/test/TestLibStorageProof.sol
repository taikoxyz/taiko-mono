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
        uint256 anchorHeight,
        bytes32 anchorHash
    ) public pure returns (bytes32 key, bytes32 value) {
        return
            LibStorageProof.computeAnchorProofKV(
                height,
                anchorHeight,
                anchorHash
            );
    }

    function computeInvalidTxListProofKV(bytes32 txListHash)
        public
        pure
        returns (bytes32 key, bytes32 value)
    {
        return LibStorageProof.computeInvalidTxListProofKV(txListHash);
    }
}
