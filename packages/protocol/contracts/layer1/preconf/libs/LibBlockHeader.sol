// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "solady/src/utils/LibRLP.sol";

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
        uint64 blobGasUsed;
        uint64 excessBlobGas;
        bytes32 parentBeaconBlockRoot;
    }

    function rlpEncodeBlockHeader(BlockHeader memory _blockHeader)
        internal
        pure
        returns (bytes memory)
    {
        LibRLP.List memory headerList = LibRLP.l();
        headerList = LibRLP.p(headerList, uint256(_blockHeader.parentHash));
        headerList = LibRLP.p(headerList, uint256(_blockHeader.ommersHash));
        headerList = LibRLP.p(headerList, _blockHeader.coinbase);
        headerList = LibRLP.p(headerList, uint256(_blockHeader.stateRoot));
        headerList = LibRLP.p(headerList, uint256(_blockHeader.transactionsRoot));
        headerList = LibRLP.p(headerList, uint256(_blockHeader.receiptRoot));
        headerList = LibRLP.p(headerList, _blockHeader.bloom);
        headerList = LibRLP.p(headerList, _blockHeader.difficulty);
        headerList = LibRLP.p(headerList, _blockHeader.number);
        headerList = LibRLP.p(headerList, _blockHeader.gasLimit);
        headerList = LibRLP.p(headerList, _blockHeader.gasUsed);
        headerList = LibRLP.p(headerList, _blockHeader.timestamp);
        headerList = LibRLP.p(headerList, _blockHeader.extraData);
        headerList = LibRLP.p(headerList, uint256(_blockHeader.prevRandao));
        headerList = LibRLP.p(headerList, uint64(_blockHeader.nonce));
        headerList = LibRLP.p(headerList, _blockHeader.baseFeePerGas);
        headerList = LibRLP.p(headerList, uint256(_blockHeader.withdrawalsRoot));
        headerList = LibRLP.p(headerList, _blockHeader.blobGasUsed);
        headerList = LibRLP.p(headerList, _blockHeader.excessBlobGas);
        headerList = LibRLP.p(headerList, uint256(_blockHeader.parentBeaconBlockRoot));
        return LibRLP.encode(headerList);
    }
}
