// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";
import { LibRLP } from "solady/src/utils/LibRLP.sol";

/// @title LibBlockHeader
/// @custom:security-contact security@taiko.xyz
library LibBlockHeader {
    // Taiko block header
    struct BlockHeader {
        bytes32 parentHash;
        bytes32 ommersHash;
        address coinbase;
        bytes32 stateRoot;
        bytes32 transactionsRoot;
        bytes32 receiptRoot;
        bytes bloom; // 256 bytes
        uint256 difficulty;
        uint256 number;
        uint256 gasLimit;
        uint256 gasUsed;
        uint256 timestamp;
        bytes extraData;
        bytes32 prevRandao;
        bytes8 nonce;
        uint256 baseFeePerGas;
        bytes32 withdrawalsRoot;
    }

    function encodeRLP(BlockHeader memory _blockHeader) internal pure returns (bytes memory) {
        LibRLP.List memory list = LibRLP.p();
        list = LibRLP.p(list, abi.encodePacked(_blockHeader.parentHash));
        list = LibRLP.p(list, abi.encodePacked(_blockHeader.ommersHash));
        list = LibRLP.p(list, _blockHeader.coinbase);
        list = LibRLP.p(list, abi.encodePacked(_blockHeader.stateRoot));
        list = LibRLP.p(list, abi.encodePacked(_blockHeader.transactionsRoot));
        list = LibRLP.p(list, abi.encodePacked(_blockHeader.receiptRoot));
        list = LibRLP.p(list, _blockHeader.bloom);
        list = LibRLP.p(list, _blockHeader.difficulty);
        list = LibRLP.p(list, _blockHeader.number);
        list = LibRLP.p(list, _blockHeader.gasLimit);
        list = LibRLP.p(list, _blockHeader.gasUsed);
        list = LibRLP.p(list, _blockHeader.timestamp);
        list = LibRLP.p(list, _blockHeader.extraData);
        list = LibRLP.p(list, abi.encodePacked(_blockHeader.prevRandao));
        list = LibRLP.p(list, abi.encodePacked(_blockHeader.nonce));
        list = LibRLP.p(list, _blockHeader.baseFeePerGas);
        list = LibRLP.p(list, abi.encodePacked(_blockHeader.withdrawalsRoot));
        return LibRLP.encode(list);
    }

    function hash(BlockHeader memory _blockHeader) internal pure returns (bytes32) {
        return EfficientHashLib.hash(encodeRLP(_blockHeader));
    }
}
