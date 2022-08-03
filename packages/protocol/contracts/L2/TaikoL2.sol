// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../common/EssentialContract.sol";
import "../libs/LibStorageProof.sol";
import "../libs/LibTxList.sol";

contract TaikoL2 is EssentialContract {
    /**********************
     * State Variables    *
     **********************/

    mapping(uint256 => bytes32) public anchorHashes;
    uint256 public lastAnchorHeight;

    uint256[48] private __gap;

    /**********************
     * Events             *
     **********************/

    event Anchored(
        uint256 anchorHeight,
        bytes32 anchorHash,
        bytes32 proofKey,
        bytes32 proofVal
    );

    /**********************
     * Modifiers          *
     **********************/

    modifier whenAnchoreAllowed() {
        require(lastAnchorHeight < block.number, "anchored already");
        lastAnchorHeight = block.number;
        _;
    }

    /**********************
     * External Functions *
     **********************/

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @dev Transfers Ether out of this contract to an recipient. We expect
    ///      this method will be called by a Bridge on L2.
    function transferEther(address receipient, uint256 amount)
        external
        onlyFromNamed("authorized_bridge")
    {
        payable(receipient).transfer(amount);
    }

    function anchor(uint256 anchorHeight, bytes32 anchorHash)
        external
        whenAnchoreAllowed
    {
        require(anchorHeight != 0 && anchorHash != 0x0, "invalid anchor");

        if (anchorHashes[anchorHeight] == 0x0) {
            anchorHashes[anchorHeight] = anchorHash;

            (bytes32 proofKey, bytes32 proofVal) = LibStorageProof
                .computeAnchorProofKV(block.number, anchorHeight, anchorHash);

            assembly {
                sstore(proofKey, proofVal)
            }

            emit Anchored(anchorHeight, anchorHash, proofKey, proofVal);
        }
    }

    function verifyBlockInvalid(bytes calldata txList) external {
        require(!LibTxListValidator.isTxListValid(txList), "txList is valid");

        (bytes32 proofKey, bytes32 proofVal) = LibStorageProof
            .computeInvalidTxListProofKV(keccak256(txList));

        assembly {
            sstore(proofKey, proofVal)
        }
    }
}
