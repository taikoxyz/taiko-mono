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
import "../libs/LibTxList.sol";

contract TaikoL2 {
    mapping(uint256 => bytes32) public anchorHashes;

    // this function must be called in each L2 block so the expected storage writes will happen.
    function prepareBlock(uint256 anchorHeight, bytes32 anchorHash) external {
        require(anchorHash != 0x0, "zero anchorHash");

        bytes32 _anchorHash = anchorHashes[anchorHeight];
        if (_anchorHash == 0x0) {
            anchorHashes[anchorHeight] = anchorHash;

            (bytes32 key, bytes32 value) = LibStorageProof.computeAnchorProofKV(
                block.number,
                anchorHeight,
                anchorHash
            );

            assembly {
                sstore(key, value)
            }
        } else {
            require(_anchorHash == anchorHash, "anchorHash mismatch");
        }
    }

    function verifyBlockInvalid(bytes calldata txList) external {
        require(!LibTxListValidator.isTxListValid(txList), "txList is valid");

        (bytes32 key, bytes32 value) = LibStorageProof
            .computeInvalidTxListProofKV(keccak256(txList));

        assembly {
            sstore(key, value)
        }
    }
}
