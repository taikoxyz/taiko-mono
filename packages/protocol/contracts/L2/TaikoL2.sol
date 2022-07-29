// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../libs/LibTxListDecoder.sol";

contract TaikoL2 {
    mapping(uint256 => bytes32) public l1blockhashes;

    // this function must be called in each L2 block so the expected storage writes will happen.
    function prepareBlock(uint256 anchorHeight, bytes32 anchorHash) external {
        require(anchorHash != 0x0);
        bytes32 _anchorHash = l1blockhashes[anchorHeight];

        if (_anchorHash != anchorHash) {
            require(_anchorHash == 0x0);
            l1blockhashes[anchorHeight] = anchorHash;

            bytes32 key = keccak256(
                abi.encodePacked("PREPARE BLOCK", block.number)
            );

            assembly {
                sstore(key, anchorHash)
            }
        }
    }

    function verifyBlockInvalid(bytes calldata txList) external {
        require(!isTxListDecodable(txList));
        bytes32 txListHash = keccak256(txList);
        bytes32 expectedStorageKey; // = keccak256(address(this), txListHash);

        assembly {
            sstore(expectedStorageKey, txListHash)
        }
    }

    function isTxListDecodable(bytes calldata encoded)
        public
        view
        returns (bool)
    {
        try LibTxListDecoder.decodeTxList(encoded) returns (TxList memory) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }
}