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
import "../libs/LibTrieProof.sol";

struct ShortHeader {
    bytes32 blockHash;
    bytes32 stateRoot;
    uint256 height;
}

struct BlockHeader {
    bytes32 parentHash; // the hash of the parent's BlockHeader
    bytes32 ommersHash;
    address beneficiary;
    bytes32 stateRoot;
    bytes32 transactionsRoot;
    bytes32 receiptsRoot;
    bytes32[8] logsBloom;
    uint256 difficulty;
    uint128 height;
    uint64 gasLimit;
    uint64 gasUsed;
    uint64 timestamp;
    bytes extraData;
    bytes32 mixHash;
    uint64 nonce;
}

struct PendingBlock {
    uint256 anchorHeight; // known L1 block height
    bytes32 anchorHash; // known L1 block hash
    bytes32 txListHash; // the hash or KGZ commitment of the encoded txList
    uint64 timestamp;
    uint64 gasLimit;
    address beneficiary;
    bytes32 mixHash;
    uint64 nonce;
}

struct ProofRecord {
    address prover; // msg.sender of proveBlock tx
    ShortHeader header;
}

contract TaikoL1 {
    bytes32 public constant INVALID_BLOCK_MARKER =
        keccak256("INVALID_BLOCK_MARKER");
    // Finalized taiko block headers
    ShortHeader[] finalizedBlockHeaders;

    // Pending Taiko blocks
    mapping(uint256 => PendingBlock) pendingBlocks;

    mapping(uint256 => mapping(bytes32 => ProofRecord)) proofRecords;

    address taikoL2Address;
    uint64 lastFinalizedBlockIndex;
    uint64 nextPendingBlockIndex;

    modifier mayFinalizeBlocks() {
        _;
        tryToFinalizedMoreBlocks();
    }

    modifier blockIsPending(uint256 index) {
        require(
            index > lastFinalizedBlockIndex && index < nextPendingBlockIndex
        );
        _;
    }

    function proposeBlock(
        PendingBlock memory blk,
        bytes calldata txList // or bytes32 txListHash when using blob
    ) external {
        require(txList.length > 0);
        require(blk.timestamp == 0);
        require(blk.txListHash == keccak256(txList));

        require(
            blk.anchorHeight >= block.number - 100 &&
                blockhash(blk.anchorHeight) == blk.anchorHash
        );

        uint256 parentTimestamp = pendingBlocks[nextPendingBlockIndex - 1]
            .timestamp;

        if (block.timestamp <= parentTimestamp) {
            blk.timestamp = uint64(parentTimestamp + 1);
        } else {
            blk.timestamp = uint64(block.timestamp);
        }

        pendingBlocks[nextPendingBlockIndex++] = blk;
    }

    //TODO:add MAX_PENDING_SIZE
    function proveBlock(
        uint256 index,
        BlockHeader calldata header,
        bytes32 anchorHash,
        bytes calldata zkproof,
        bytes calldata mkproof
    ) external blockIsPending(index) mayFinalizeBlocks {
        PendingBlock memory blk = pendingBlocks[index];
        verifyBlockHeader(header, blk);
        bytes32 blockHash = hashBlockHeader(header);

        verifyZKProof(header.parentHash, blockHash, blk.txListHash, zkproof);

        // we need to calculate key based on taikoL2Address,  pendingBlocks[index].anchorHeight
        // but the following calculation is not correct.
        //
        // see TaikoL2.sol `prepareBlock`
        bytes32 expectedKey = keccak256(
            abi.encodePacked("PREPARE BLOCK", header.height)
        );

        // The prepareBlock tx may fail due to out-of-gas, therefore, we have to accept
        // an 0x0 value. In such case, we need to punish the block proposer for the failed
        // prepareBlock tx.
        require(
            anchorHash == 0x0 || anchorHash == pendingBlocks[index].anchorHash
        );

        LibTrieProof.verify(
            header.stateRoot,
            taikoL2Address,
            expectedKey,
            anchorHash,
            mkproof
        );

        proofRecords[index][header.parentHash] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({
                blockHash: blockHash,
                stateRoot: header.stateRoot,
                height: header.height
            })
        });
    }

    function proveBlockInvalid(
        uint256 index,
        bytes32 txListHash, // hash of a txList that contains a verifyBlockInvalid tx on L2.
        BlockHeader calldata header,
        bytes calldata zkproof,
        bytes calldata mkproof
    ) external blockIsPending(index) mayFinalizeBlocks {
        PendingBlock memory blk = pendingBlocks[index];
        verifyBlockHeader(header, blk);
        bytes32 blockHash = hashBlockHeader(header);

        require(
            header.parentHash ==
                finalizedBlockHeaders[header.height - 1].blockHash
        );

        verifyZKProof(header.parentHash, blockHash, txListHash, zkproof);

        // we need to calculate key based on taikoL2Address and pendingBlocks[index].txListHash
        // but the following calculation is not correct.
        bytes32 expectedKey; // = keccak256(taikoL2Address, pendingBlocks[index].txListHash);

        LibTrieProof.verify(
            header.stateRoot,
            taikoL2Address,
            expectedKey,
            pendingBlocks[index].txListHash,
            mkproof
        );

        proofRecords[index][INVALID_BLOCK_MARKER] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({
                blockHash: INVALID_BLOCK_MARKER,
                stateRoot: 0x0,
                height: 0
            })
        });
    }

    function verifyBlockInvalid(uint256 index, bytes calldata txList)
        external
        blockIsPending(index)
        mayFinalizeBlocks
    {
        require(!isTxListDecodable(txList));
        require(keccak256(txList) == pendingBlocks[index].txListHash);

        proofRecords[index][INVALID_BLOCK_MARKER] = ProofRecord({
            prover: msg.sender,
            header: ShortHeader({
                blockHash: INVALID_BLOCK_MARKER,
                stateRoot: 0x0,
                height: 0
            })
        });
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

    function verifyZKProof(
        bytes32 parentBlockHash,
        bytes32 blockHash,
        bytes32 txListHash,
        bytes calldata zkproof
    ) public view {
        // TODO
    }

    function verifyBlockHeader(
        BlockHeader calldata header,
        PendingBlock memory blk
    ) public pure {
        require(header.nonce == blk.nonce);
        require(header.timestamp == blk.timestamp);
        require(header.gasLimit == blk.gasLimit);
        require(header.mixHash == blk.mixHash);
        require(header.beneficiary == blk.beneficiary);
        require(header.extraData.length == 0);
    }

    function hashBlockHeader(BlockHeader calldata header)
        public
        pure
        returns (bytes32)
    {
        // TODO
    }

    function tryToFinalizedMoreBlocks() internal {
        ShortHeader memory parent = finalizedBlockHeaders[
            finalizedBlockHeaders.length - 1
        ];

        uint256 i = lastFinalizedBlockIndex + 1;

        while (i < nextPendingBlockIndex) {
            ShortHeader storage header = proofRecords[i][parent.blockHash]
                .header;

            if (header.blockHash != 0x0) {
                finalizedBlockHeaders.push(header);
                parent = header;
                lastFinalizedBlockIndex += 1;
                i += 1;
            } else if (
                proofRecords[i][INVALID_BLOCK_MARKER].header.blockHash ==
                INVALID_BLOCK_MARKER
            ) {
                lastFinalizedBlockIndex += 1;
                i += 1;
            } else {
                break;
            }
        }
    }
}
