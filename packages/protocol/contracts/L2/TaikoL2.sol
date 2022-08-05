// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    receive() external payable {}

    function unwrapEther(address receipient, uint256 amount) external {
        if (amount == 0) return;

        IERC20(resolve("WETH")).transferFrom(msg.sender, address(this), amount);
        payable(receipient).transfer(amount);
    }

    function wrapEther(address receipient) external payable {
        if (msg.value == 0) return;

        IERC20(resolve("WETH")).transfer(receipient, msg.value);
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
