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
import "../libs/LibTxListValidator.sol";

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
        bytes32 ancestorAggHash,
        bytes32 proofKey,
        bytes32 proofVal
    );

    event BlockInvalidated(address invalidator, bytes32 ancestorAggHash);
    event EtherCredited(address recipient, uint256 amount);
    event EtherReturned(address recipient, uint256 amount);

    /**********************
     * Modifiers          *
     **********************/

    modifier onlyWhenNotAnchored() {
        require(lastAnchorHeight < block.number, "L2:anchored already");
        lastAnchorHeight = block.number;
        _;
    }

    /**********************
     * External Functions *
     **********************/

    receive() external payable onlyFromNamed("eth_depositor") {
        emit EtherReturned(msg.sender, msg.value);
    }

    fallback() external payable {
        revert("L2:not allowed");
    }

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function creditEther(address recipient, uint256 amount)
        external
        nonReentrant
        onlyFromNamed("eth_depositor")
    {
        require(
            recipient != address(0) && recipient != address(this),
            "L2:invalid address"
        );
        payable(recipient).transfer(amount);
        emit EtherCredited(recipient, amount);
    }

    function anchor(uint256 anchorHeight, bytes32 anchorHash)
        external
        onlyWhenNotAnchored
    {
        require(anchorHeight != 0 && anchorHash != 0, "L2:invalid anchor");
        anchorHashes[anchorHeight] = anchorHash;

        bytes32 ancestorAggHash = LibStorageProof.aggregateAncestorHashs(
            getAncestorHashes(block.number)
        );
        (bytes32 proofKey, bytes32 proofVal) = LibStorageProof
            .computeAnchorProofKV(
                block.number,
                anchorHeight,
                anchorHash,
                ancestorAggHash
            );

        assembly {
            sstore(proofKey, proofVal)
        }

        emit Anchored(
            anchorHeight,
            anchorHash,
            ancestorAggHash,
            proofKey,
            proofVal
        );
    }

    function verifyBlockInvalid(bytes calldata txList) external {
        require(
            !LibTxListValidator.isTxListValid(txList),
            "L2:txList is valid"
        );

        bytes32 ancestorAggHash = LibStorageProof.aggregateAncestorHashs(
            getAncestorHashes(block.number)
        );
        (bytes32 proofKey, bytes32 proofVal) = LibStorageProof
            .computeInvalidTxListProofKV(keccak256(txList), ancestorAggHash);

        assembly {
            sstore(proofKey, proofVal)
        }

        emit BlockInvalidated(msg.sender, ancestorAggHash);
    }

    function getAncestorHashes(uint256 blockNumber)
        public
        view
        returns (bytes32[256] memory ancestorHashes)
    {
        for (uint256 i = 0; i < 256; i++) {
            if (blockNumber > i) {
                ancestorHashes[i] = blockhash(blockNumber - i - 1);
            }
        }
    }
}
